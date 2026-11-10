-- Pohantoon AI: harden an existing public DDL event-trigger function on the test project.
-- This function was already present before module 01. Its event trigger continues to
-- run for schema DDL, but the Data API must not expose it to client roles.
-- Keep this idempotent and portable: on another Supabase instance the function
-- may not exist, so skip the REVOKE without creating the function.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'rls_auto_enable'
      AND pg_get_function_identity_arguments(p.oid) = ''
  ) THEN
    REVOKE EXECUTE ON FUNCTION public.rls_auto_enable()
      FROM PUBLIC, anon, authenticated;
  END IF;
END;
$$;
