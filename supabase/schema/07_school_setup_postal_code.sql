-- Optional postal code for the School Location card in Step 3 and Step 4.
-- Non-destructive: existing applicant drafts keep all their data.
BEGIN;
ALTER TABLE public.school_setup_drafts
  ADD COLUMN postal_code text;
ALTER TABLE public.school_setup_drafts
  ADD CONSTRAINT school_setup_postal_code_length_check
  CHECK (postal_code IS NULL OR length(postal_code) <= 32);
NOTIFY pgrst, 'reload schema';
COMMIT;
