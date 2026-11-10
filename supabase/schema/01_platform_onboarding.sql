-- Pohantoon AI — module 01: SaaS Organization Control Panel
-- Portable source of truth; apply to ONE development Supabase project after organization selection.
-- Until live API policies are added these tables MUST remain unexposed.
-- This design intentionally contains no real payment processing or automatic school provisioning.

BEGIN;

CREATE SCHEMA IF NOT EXISTS platform;
REVOKE ALL ON SCHEMA platform FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS platform.organizations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z][a-z0-9_-]{2,49}$'),
    legal_name text NOT NULL CHECK (length(btrim(legal_name)) > 0),
    display_name text NOT NULL CHECK (length(btrim(display_name)) > 0),
    support_email text,
    headquarters_country_code varchar(2),
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','suspended','archived')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS platform.organization_memberships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES platform.organizations(id) ON DELETE RESTRICT,
    auth_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    operator_role text NOT NULL CHECK (operator_role IN ('owner','admin','billing','support','analyst')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('invited','active','suspended','revoked')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id,auth_user_id)
);

CREATE TABLE IF NOT EXISTS platform.subscription_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES platform.organizations(id) ON DELETE RESTRICT,
    code text NOT NULL CHECK (code ~ '^[a-z0-9_]{2,60}$'),
    name text NOT NULL CHECK (length(btrim(name)) > 0),
    summary text,
    is_public boolean NOT NULL DEFAULT false,
    is_test_only boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','retired')),
    trial_days integer NOT NULL DEFAULT 0 CHECK (trial_days BETWEEN 0 AND 365),
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id,code),
    UNIQUE(organization_id,id)
);

CREATE TABLE IF NOT EXISTS platform.plan_prices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    currency_code varchar(3) NOT NULL CHECK (currency_code ~ '^[A-Z]{3}$'),
    billing_period text NOT NULL CHECK (billing_period IN ('monthly','annually','one_time')),
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id,id),
    FOREIGN KEY (organization_id,plan_id)
        REFERENCES platform.subscription_plans(organization_id,id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS platform.subscription_plan_features (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    feature_code text NOT NULL CHECK (feature_code ~ '^[a-z][a-z0-9_.]{1,79}$'),
    enabled boolean NOT NULL DEFAULT true,
    limit_value bigint CHECK (limit_value IS NULL OR limit_value >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id,plan_id,feature_code),
    FOREIGN KEY (organization_id,plan_id)
        REFERENCES platform.subscription_plans(organization_id,id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS platform.school_onboarding_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES platform.organizations(id) ON DELETE RESTRICT,
    requester_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    selected_plan_id uuid,
    school_display_name text NOT NULL CHECK (length(btrim(school_display_name)) > 0),
    school_legal_name text,
    registration_number text,
    licensing_authority text,
    school_type text NOT NULL DEFAULT 'private'
        CHECK (school_type IN ('public','private','nonprofit','international','other')),
    ownership_type text CHECK (ownership_type IN ('individual','partnership','company','government','nonprofit','other')),
    primary_email text NOT NULL CHECK (position('@' IN primary_email) > 1),
    primary_phone text,
    website_url text,
    year_established integer CHECK (year_established BETWEEN 1800 AND 2200),
    requested_school_code text,
    preferred_timezone text NOT NULL DEFAULT 'UTC',
    preferred_currency varchar(3) NOT NULL DEFAULT 'USD',
    status text NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft','submitted','in_review','more_information','approved','rejected','provisioned','cancelled')),
    notes_from_school text,
    submitted_at timestamptz,
    reviewed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id,id),
    FOREIGN KEY (organization_id,selected_plan_id)
        REFERENCES platform.subscription_plans(organization_id,id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS platform.school_onboarding_contacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    onboarding_request_id uuid NOT NULL,
    contact_kind text NOT NULL
        CHECK (contact_kind IN ('owner','principal','administrator','billing','technical','other')),
    full_name text NOT NULL CHECK (length(btrim(full_name)) > 0),
    job_title text,
    email text,
    phone text,
    is_primary boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id,onboarding_request_id)
        REFERENCES platform.school_onboarding_requests(organization_id,id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS platform.school_onboarding_locations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    onboarding_request_id uuid NOT NULL,
    location_kind text NOT NULL DEFAULT 'main'
        CHECK (location_kind IN ('main','branch','mailing','billing')),
    label text,
    country_code varchar(2) NOT NULL,
    region text,
    city text NOT NULL,
    street_address text,
    address_line_2 text,
    postal_code text,
    estimated_campus_count integer NOT NULL DEFAULT 1 CHECK (estimated_campus_count >= 1),
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id,onboarding_request_id)
        REFERENCES platform.school_onboarding_requests(organization_id,id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS platform.school_onboarding_education_profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    onboarding_request_id uuid NOT NULL,
    education_board text,
    curriculum_summary text,
    minimum_grade_label text,
    maximum_grade_label text,
    teaching_languages text[],
    approximate_students integer CHECK (approximate_students >= 0),
    approximate_teachers integer CHECK (approximate_teachers >= 0),
    approximate_non_teaching_staff integer CHECK (approximate_non_teaching_staff >= 0),
    daily_shifts integer CHECK (daily_shifts BETWEEN 1 AND 5),
    academic_year_start_month integer CHECK (academic_year_start_month BETWEEN 1 AND 12),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id,onboarding_request_id),
    FOREIGN KEY (organization_id,onboarding_request_id)
        REFERENCES platform.school_onboarding_requests(organization_id,id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS platform.school_onboarding_operational_profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    onboarding_request_id uuid NOT NULL,
    uses_existing_software boolean,
    existing_software_name text,
    wants_data_migration boolean NOT NULL DEFAULT false,
    offers_transport boolean,
    offers_hostel boolean,
    has_library boolean,
    has_medical_facilities boolean,
    wants_payroll boolean,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id,onboarding_request_id),
    FOREIGN KEY (organization_id,onboarding_request_id)
        REFERENCES platform.school_onboarding_requests(organization_id,id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS platform.school_subscription_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    onboarding_request_id uuid NOT NULL,
    plan_price_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'requested'
        CHECK (status IN ('requested','pending_payment','payment_under_review','verified','cancelled','expired')),
    external_checkout_reference text,
    provider_name text,
    submitted_at timestamptz NOT NULL DEFAULT now(),
    verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id,id),
    FOREIGN KEY (organization_id,onboarding_request_id)
        REFERENCES platform.school_onboarding_requests(organization_id,id) ON DELETE RESTRICT,
    FOREIGN KEY (organization_id,plan_price_id)
        REFERENCES platform.plan_prices(organization_id,id) ON DELETE RESTRICT
);
-- IMPORTANT: no status transitions/payment verification from the client.
-- A verified subscription will require a provider webhook and audited server workflow.

CREATE TABLE IF NOT EXISTS platform.school_onboarding_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    onboarding_request_id uuid NOT NULL,
    reviewer_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
    decision text NOT NULL CHECK (decision IN ('note','request_information','approve','reject')),
    rationale text,
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (organization_id,onboarding_request_id)
        REFERENCES platform.school_onboarding_requests(organization_id,id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS school_onboarding_org_state_idx
    ON platform.school_onboarding_requests(organization_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS school_onboarding_contact_req_idx
    ON platform.school_onboarding_contacts(organization_id,onboarding_request_id);
CREATE INDEX IF NOT EXISTS school_subscription_requests_org_state_idx
    ON platform.school_subscription_requests(organization_id,status,submitted_at DESC);
CREATE INDEX IF NOT EXISTS school_plans_public_idx
    ON platform.subscription_plans(organization_id,status,is_public,sort_order);
CREATE INDEX IF NOT EXISTS organization_memberships_user_idx
    ON platform.organization_memberships(auth_user_id,organization_id,status);

-- Defense-in-depth: ZERO client-readable/writable data until reviewed API policies exist.
ALTER TABLE platform.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.organization_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.plan_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.subscription_plan_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.school_onboarding_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.school_onboarding_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.school_onboarding_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.school_onboarding_education_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.school_onboarding_operational_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.school_subscription_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform.school_onboarding_reviews ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA platform FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SCHEMA platform FROM PUBLIC, anon, authenticated;

COMMIT;
