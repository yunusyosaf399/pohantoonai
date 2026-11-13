-- Module 02.5: account-owned welcome + new-session alert delivery ledger.
-- Portable schema source; deploy through a reviewed migration once email provider is configured.
-- No school_id: Supabase auth.users is global to the single multi-school project.
BEGIN;

CREATE TABLE IF NOT EXISTS public.account_auth_email_config (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  activated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.account_auth_email_config(singleton) VALUES (true)
ON CONFLICT (singleton) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.account_auth_email_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('welcome', 'login_alert')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'failed')),
  send_attempts integer NOT NULL DEFAULT 1
    CHECK (send_attempts BETWEEN 1 AND 3),
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  provider_message_id text,
  CONSTRAINT account_auth_email_one_per_session UNIQUE (session_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS account_auth_email_one_welcome_per_user
  ON public.account_auth_email_notifications(user_id) WHERE kind='welcome';

ALTER TABLE public.account_auth_email_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_auth_email_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_auth_email_config FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.account_auth_email_notifications FROM PUBLIC, anon, authenticated;
-- Only Edge Functions with server-side service_role can write delivery statuses.
GRANT SELECT ON public.account_auth_email_config TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.account_auth_email_notifications TO service_role;

-- The function MUST NOT be exposed to normal clients: it reads auth.sessions
-- (IP and User-Agent) and auth.users (email), and reserves a send atomically.
CREATE OR REPLACE FUNCTION public.reserve_account_auth_email(
  p_user_id uuid, p_session_id uuid
)
RETURNS TABLE(
  notification_id uuid,
  notification_kind text,
  recipient_email text,
  session_at timestamptz,
  session_ip text,
  session_user_agent text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_session auth.sessions%ROWTYPE;
  v_user auth.users%ROWTYPE;
  v_activation timestamptz;
  v_kind text;
  v_id uuid;
  v_existing public.account_auth_email_notifications%ROWTYPE;
BEGIN
  -- One hour allows delayed OAuth/deep-link/MFA completion, but avoids
  -- sending a fresh email each time an old persistent session opens.
  SELECT * INTO v_session FROM auth.sessions
    WHERE id=p_session_id AND user_id=p_user_id
      AND created_at >= now() - interval '1 hour'
      AND created_at <= now() + interval '1 minute';
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO v_user FROM auth.users
    WHERE id=p_user_id
      AND email IS NOT NULL
      AND (email_confirmed_at IS NOT NULL OR confirmed_at IS NOT NULL);
  IF NOT FOUND THEN RETURN; END IF;

  -- Enrolled MFA must be completed at AAL2, including for direct
  -- invocations that bypass the official Flutter UI.
  IF (v_session.aal IS NULL OR v_session.aal::text <> 'aal2')
    AND EXISTS (
      SELECT 1 FROM auth.mfa_factors
      WHERE user_id=p_user_id AND status::text='verified'
    ) THEN
    RETURN;
  END IF;

  SELECT activated_at INTO v_activation FROM public.account_auth_email_config
    WHERE singleton = true;
  IF v_activation IS NULL THEN RETURN; END IF;

  v_kind := 'login_alert';
  -- Existing accounts do not receive retroactive welcome messages.
  -- For email sign-up, only the first authenticated/verified session counts.
  IF v_user.created_at >= v_activation AND NOT EXISTS (
    SELECT 1 FROM public.account_auth_email_notifications
    WHERE user_id=p_user_id AND kind='welcome'
  ) THEN
    v_kind := 'welcome';
  END IF;

  INSERT INTO public.account_auth_email_notifications
    (user_id,session_id,kind)
  VALUES (p_user_id,p_session_id,v_kind)
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    -- An already-sent or in-flight event is a no-op. Failed sends can retry
    -- up to three times using the same provider idempotency key.
    SELECT * INTO v_existing FROM public.account_auth_email_notifications
      WHERE session_id=p_session_id FOR UPDATE;
    IF NOT FOUND THEN RETURN; END IF;
    IF v_existing.status='sent'
       OR v_existing.send_attempts >= 3
       OR (v_existing.status='pending'
           AND v_existing.created_at > now()-interval '3 minutes') THEN
      RETURN;
    END IF;
    UPDATE public.account_auth_email_notifications
    SET status='pending', send_attempts=send_attempts+1, created_at=now()
    WHERE id=v_existing.id RETURNING id INTO v_id;
    v_kind := v_existing.kind;
  END IF;

  RETURN QUERY SELECT
    v_id, v_kind, v_user.email::text, v_session.created_at,
    v_session.ip::text, v_session.user_agent::text;
END;
$function$;

REVOKE ALL ON FUNCTION public.reserve_account_auth_email(uuid,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_account_auth_email(uuid,uuid)
  TO service_role;

COMMENT ON TABLE public.account_auth_email_notifications IS
  'Service-only, per-session auth email deduplication and delivery ledger; never contains passwords, OTPs, or access tokens.';
COMMENT ON FUNCTION public.reserve_account_auth_email(uuid,uuid) IS
  'Service-only reservation using verified auth.users and auth.sessions IDs; caller must validate the bearer JWT and derive both arguments from it.';

COMMIT;
