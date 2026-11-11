-- Module 02.2B: owner account profile details. Auth email/password stay
-- in Supabase Auth; profile fields remain applicant-owned by existing RLS.
BEGIN;
ALTER TABLE public.user_profiles
  ADD COLUMN phone text CHECK (
    phone IS NULL OR length(phone)<=32),
  ADD COLUMN position text CHECK (
    position IS NULL OR length(position)<=120);

-- Existing user_profiles RLS SELECT/INSERT/UPDATE policies stay active,
-- matching auth.uid() to user_id. No new public grants are introduced.
NOTIFY pgrst,'reload schema';
COMMIT;
