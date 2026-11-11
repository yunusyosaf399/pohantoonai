-- Module 02/School Dashboard FOUNDATION. Zero rows are provisioned here.
-- Client roles may SELECT their own authenticated active school membership,
-- but may NOT create schools, memberships, metrics, or activities.
-- Only a future audited, private server workflow provisions these rows.
BEGIN;
CREATE TABLE public.schools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9][a-z0-9-]{2,78}$'),
  name text NOT NULL CHECK (char_length(trim(name)) BETWEEN 2 AND 220),
  legal_name text,
  country_code text CHECK (country_code ~ '^[A-Z]{2}$'),
  timezone text NOT NULL DEFAULT 'UTC',
  currency_code text NOT NULL DEFAULT 'USD',
  logo_storage_path text,
  lifecycle_status text NOT NULL DEFAULT 'provisioning'
    CHECK (lifecycle_status IN ('provisioning','active','suspended','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.school_memberships (
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (
    role IN ('school_owner','school_admin','teacher','staff')),
  membership_status text NOT NULL DEFAULT 'invited'
    CHECK (membership_status IN ('invited','active','suspended','revoked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (school_id,user_id)
);
CREATE INDEX school_memberships_by_user
  ON public.school_memberships(user_id,school_id)
  WHERE membership_status='active';

CREATE TABLE public.school_academic_years (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  label text NOT NULL CHECK (char_length(label) BETWEEN 4 AND 30),
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  is_current boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT school_year_order CHECK (starts_on <= ends_on),
  UNIQUE (school_id,id),
  UNIQUE (school_id,label)
);
CREATE UNIQUE INDEX school_year_one_current_per_school
  ON public.school_academic_years(school_id) WHERE is_current;

CREATE TABLE public.school_dashboard_snapshots (
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  academic_year_id uuid NOT NULL,
  snapshot_date date NOT NULL,
  student_count integer NOT NULL DEFAULT 0 CHECK (student_count >= 0),
  staff_count integer NOT NULL DEFAULT 0 CHECK (staff_count >= 0),
  class_count integer NOT NULL DEFAULT 0 CHECK (class_count >= 0),
  campus_count integer NOT NULL DEFAULT 0 CHECK (campus_count >= 0),
  attendance_present integer NOT NULL DEFAULT 0 CHECK (attendance_present >= 0),
  attendance_absent integer NOT NULL DEFAULT 0 CHECK (attendance_absent >= 0),
  attendance_excused integer NOT NULL DEFAULT 0 CHECK (attendance_excused >= 0),
  fees_collected_minor bigint NOT NULL DEFAULT 0 CHECK (fees_collected_minor >= 0),
  fees_outstanding_minor bigint NOT NULL DEFAULT 0 CHECK (fees_outstanding_minor >= 0),
  generated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(school_id,academic_year_id,snapshot_date),
  FOREIGN KEY (school_id,academic_year_id)
     REFERENCES public.school_academic_years(school_id,id)
);
CREATE INDEX school_dashboard_latest_snapshot
  ON public.school_dashboard_snapshots(school_id,snapshot_date DESC);

CREATE TABLE public.school_dashboard_trends (
  school_id uuid NOT NULL,
  academic_year_id uuid NOT NULL,
  month_start date NOT NULL,
  student_count integer NOT NULL DEFAULT 0 CHECK (student_count>=0),
  new_admissions integer NOT NULL DEFAULT 0 CHECK (new_admissions>=0),
  staff_count integer NOT NULL DEFAULT 0 CHECK (staff_count>=0),
  attendance_rate numeric(5,2) CHECK (attendance_rate BETWEEN 0 AND 100),
  fees_collected_minor bigint NOT NULL DEFAULT 0 CHECK (fees_collected_minor>=0),
  PRIMARY KEY (school_id,academic_year_id,month_start),
  FOREIGN KEY(school_id,academic_year_id)
    REFERENCES public.school_academic_years(school_id,id)
    ON DELETE CASCADE
);

CREATE TABLE public.school_dashboard_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK(event_type IN (
    'admission','application_approved','application_rejected',
    'student_added','payment_received','staff_added','notice_published')),
  subject_display_name text CHECK (char_length(subject_display_name)<=220),
  event_summary text NOT NULL CHECK(char_length(event_summary)<=500),
  workflow_status text CHECK (workflow_status IN (
    'in_review','approved','rejected','pending','completed')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  -- Server-approved destination, not an arbitrary client-provided URL.
  resource_type text,
  resource_id uuid
);
CREATE INDEX school_dashboard_activity_recent
  ON public.school_dashboard_activity(school_id,occurred_at DESC);

-- RLS applied before client-facing API grants.
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_dashboard_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_dashboard_trends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_dashboard_activity ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.schools, public.school_memberships,
  public.school_academic_years, public.school_dashboard_snapshots,
  public.school_dashboard_trends, public.school_dashboard_activity
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.schools, public.school_memberships,
  public.school_academic_years, public.school_dashboard_snapshots,
  public.school_dashboard_trends, public.school_dashboard_activity
  TO authenticated;

-- Membership table read is self-only. Roles/statuses cannot be self-edited.
CREATE POLICY school_membership_read_self
  ON public.school_memberships FOR SELECT TO authenticated
  USING (user_id=(SELECT auth.uid()));

-- A user's school must be active and they must have a live membership.
CREATE POLICY school_read_my_active_membership
  ON public.schools FOR SELECT TO authenticated
  USING (
    lifecycle_status='active' AND EXISTS (
      SELECT 1 FROM public.school_memberships m
       WHERE m.school_id=schools.id AND m.user_id=(SELECT auth.uid())
         AND m.membership_status='active'
    )
  );

CREATE POLICY school_year_read_active
  ON public.school_academic_years FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.schools s
    JOIN public.school_memberships m ON m.school_id=s.id
    WHERE s.id=school_academic_years.school_id
      AND s.lifecycle_status='active'
      AND m.user_id=(SELECT auth.uid())
      AND m.membership_status='active'
  ));

-- Dashboard reports contain sensitive aggregate finance, attendance and
-- identifiable admission activity. Restrict to active owner/admin ONLY.
CREATE POLICY school_snapshot_read_owner_admin
  ON public.school_dashboard_snapshots FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.schools s
    JOIN public.school_memberships m ON m.school_id=s.id
    WHERE s.id=school_dashboard_snapshots.school_id
      AND s.lifecycle_status='active'
      AND m.user_id=(SELECT auth.uid())
      AND m.membership_status='active'
      AND m.role IN ('school_owner','school_admin')
  ));
CREATE POLICY school_trends_read_owner_admin
  ON public.school_dashboard_trends FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.schools s
    JOIN public.school_memberships m ON m.school_id=s.id
    WHERE s.id=school_dashboard_trends.school_id
      AND s.lifecycle_status='active'
      AND m.user_id=(SELECT auth.uid())
      AND m.membership_status='active'
      AND m.role IN ('school_owner','school_admin')
  ));
CREATE POLICY school_activity_read_owner_admin
  ON public.school_dashboard_activity FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.schools s
    JOIN public.school_memberships m ON m.school_id=s.id
    WHERE s.id=school_dashboard_activity.school_id
      AND s.lifecycle_status='active'
      AND m.user_id=(SELECT auth.uid())
      AND m.membership_status='active'
      AND m.role IN ('school_owner','school_admin')
  ));

NOTIFY pgrst,'reload schema';
COMMIT;
