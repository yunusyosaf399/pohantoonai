-- Module 01.1 — Public-safe, owner-only account identity and appearance preferences.
-- Auth credentials, Google identities and email OTPs stay in Supabase-managed auth.* tables.
-- This file contains NO operator role, school-membership or billing grants.
-- Deploy to single development project pohantoonai; use as portable source for later orgs.

BEGIN;

CREATE TABLE IF NOT EXISTS public.user_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text CHECK (
    display_name IS NULL OR
    (length(btrim(display_name)) BETWEEN 1 AND 120)
  ),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  theme_mode text NOT NULL DEFAULT 'system'
    CHECK (theme_mode IN ('system', 'light', 'dark')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- Explicit table grants. Do not give anonymous users access to identity records.
REVOKE ALL ON public.user_profiles FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.user_preferences FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_preferences TO authenticated;

CREATE POLICY "profile_read_own"
ON public.user_profiles FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "profile_create_own"
ON public.user_profiles FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "profile_update_own"
ON public.user_profiles FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "preferences_read_own"
ON public.user_preferences FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "preferences_create_own"
ON public.user_preferences FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "preferences_update_own"
ON public.user_preferences FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

-- Deliberately no trigger on auth.users; an auth-system insert must not be
-- able to fail because of this app's user profile preferences table.
-- Edge function "account-bootstrap" creates rows using the CALLER'S JWT.
NOTIFY pgrst, 'reload schema';

COMMIT;
