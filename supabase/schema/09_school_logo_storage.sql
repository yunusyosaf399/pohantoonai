-- Module 01.6A: applicant school logo and private Storage bucket.
-- This does not create an approved school or tenant.
BEGIN;

ALTER TABLE public.school_setup_drafts
  ADD COLUMN logo_storage_path text;
ALTER TABLE public.school_setup_drafts
  ADD CONSTRAINT school_setup_logo_path_owned_check
  CHECK (
    logo_storage_path IS NULL
    OR logo_storage_path ~
      ('^' || user_id::text || '/logos/[a-zA-Z0-9_-]+\.(png|jpg|jpeg|webp)$')
  );

INSERT INTO storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) VALUES (
  'school-logos', 'school-logos', false, 2097152,
  ARRAY['image/png','image/jpeg','image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Storage objects are only accessible to their signed-in original owner.
-- A leading account UUID folder is required for every object in this bucket.
CREATE POLICY school_logo_select_own
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'school-logos'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND (storage.foldername(name))[2] = 'logos'
  );

CREATE POLICY school_logo_insert_own
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'school-logos'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND (storage.foldername(name))[2] = 'logos'
    AND storage.extension(name) IN ('png','jpg','jpeg','webp')
    AND owner_id = (SELECT auth.uid())::text
  );

CREATE POLICY school_logo_update_own
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'school-logos'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND (storage.foldername(name))[2] = 'logos'
    AND owner_id = (SELECT auth.uid())::text
  )
  WITH CHECK (
    bucket_id = 'school-logos'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND (storage.foldername(name))[2] = 'logos'
    AND storage.extension(name) IN ('png','jpg','jpeg','webp')
    AND owner_id = (SELECT auth.uid())::text
  );

CREATE POLICY school_logo_delete_own
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'school-logos'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    AND (storage.foldername(name))[2] = 'logos'
    AND owner_id = (SELECT auth.uid())::text
  );

NOTIFY pgrst, 'reload schema';
COMMIT;
