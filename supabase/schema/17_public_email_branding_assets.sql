-- Module 02.6 — Public platform brand assets for email rendering.
-- Only deliberately public logos belong here. Never use for user, school or student uploads.
-- Existing private school-logos bucket is intentionally untouched.
BEGIN;
INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES (
  'pohantoonai-email-assets',
  'pohantoonai-email-assets',
  true,
  1048576,
  ARRAY['image/jpeg','image/png','image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;
-- No client INSERT/UPDATE/DELETE policy is created for this public bucket:
-- uploads are performed by authorized project owners through the dashboard.
COMMIT;
