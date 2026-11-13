# Module 03.4 — Trusted school activation and operator approval

**Repository:** PohantoonAI (one shared Supabase project, one database for multiple schools).  
**Status:** Backend deployed 13 November 2026; Flutter changes are on feature branch `feature/trusted-school-provisioning-20261113` pending Flutter build/device testing and merge.

## Why this workflow is necessary

The existing Step 6 dashboard is a **DEMO**. `onboarding_dev_workspaces` and payment `skipped_for_testing` never create a real school or admin membership. The previous Module 03 real Admissions UI correctly refuses to access records without an active `schools.id` and `school_memberships`.

Activation now requires three explicit independent events:

1. **The owner submits a reviewed application.** The server reads the applicant's **own** `school_setup_drafts`, `onboarding_plan_selections`, and a `onboarding_review_confirmations` whose captured draft timestamp and plan ID still match current values. The applicant's email must be verified and their enrolled MFA must be satisfied.
2. **A separate, trusted platform owner/admin reviews.** The reviewer must be an `active` `platform.organization_memberships` row (role `owner` or `admin`) for the same **active** `platform.organizations` record. Supabase JWT must have `aal='aal2'` even if the operator did not previously enroll 2FA. Reviewer and applicant cannot be the same Auth user.
3. **An explicit approval creates the tenant atomically.** PostgreSQL creates `public.schools`, its `school_owner` membership, a private provisioning link, and an immutable `platform.school_onboarding_reviews` audit entry, then marks the onboarding request `provisioned`. Failure at any step rolls back the whole transaction.

A rejected request is audited but creates **no** school, membership or subscription entitlement.

## Reused tables

- `public.school_setup_drafts`: applicant-owned school information (mutable before request)
- `public.onboarding_plan_selections` and `public.onboarding_review_confirmations`: selected plan and evidence the exact draft was reviewed
- `platform.school_onboarding_requests`: the authoritative review queue, populated by server RPC `request_school_activation()`
- `platform.school_onboarding_reviews`: approved/rejected decision audit
- `platform.organization_memberships`: manually granted platform operator roles; RLS and no public-schema access
- `public.schools` + `public.school_memberships`: real tenant and school owner role used by Module 03 Admissions

## New tables

| Table | Purpose |
|---|---|
| `platform.school_activation_snapshots` | Freeze owner identity, exact selected plan, country/timezone/currency, logo path, reviewed draft version. Prevents subsequent client edits affecting a pending approval. |
| `platform.school_provisioning_links` | Exactly one approved school UUID per onboarding request; stores reviewer Auth user, verified basis, evidence and timestamp. |

Both new tables are in the **non-exposed** `platform` schema with RLS enabled and no `anon`/`authenticated` direct table grants or policies. The missing-RLS-policy advisor *INFO* for these server-only tables is intentional.

## Public RPC endpoints

The six security-definer RPCs are in `public` so the Flutter Auth client can call them. Every privileged call performs signed Supabase Auth identity checks and server-owned membership validation; `anon` cannot execute any of them.

| RPC | Authorized usage |
|---|---|
| `request_school_activation()` | Verified applicant submits only **their own** currently reviewed, confirmed draft. Never grants a school. Retries return the original request UUID. |
| `my_school_activation_status()` | Applicant reads only their own submission status and provisioned school ID. |
| `my_school_provisioning_role()` | Reads own platform operator status: `none`, `mfa_required`, `authorized`. Cannot assign permissions. |
| `list_school_activation_reviews()` | AAL2 platform owner/admin reads review queue **only for their active organizations**. |
| `approve_school_activation(id,basis,evidence,identity_verified)` | AAL2 authorized **independent** reviewer approves. Requires explicit checked identity verification and 20–2000 characters of evidence. |
| `reject_school_activation(id,reason)` | AAL2 authorized independent reviewer rejects with 15–2000 characters of reasoning. |

Supabase's security advisor warns that the six functions are `SECURITY DEFINER` and executable by `authenticated`. This is **intentional and restricted**, because the private `platform` schema is not available to Flutter; each function checks account ownership or active operator role, AAL2, and organization before accessing the private tables. Do **not** remove these checks or broaden `platform` grants. They should be re-reviewed before a production rollout; using a separate server-only Edge API is a future hardening option, not currently necessary for a manually governed pilot.

### Development pilot vs verified paid subscription

**Development pilot:** the selected `onboarding_plan_offers.is_demo=true` plan may be manually approved **only** with `p_basis='approved_pilot'` by a trusted reviewer. A skipped payment or a demo plan alone never activates any school. The recorded basis explicitly states that the school is a development pilot, **not paid**.

**Paid school:** `p_basis='verified_subscription'` requires a non-demo active offer **and** a `platform.school_subscription_requests` row with `status='verified'`, `verified_at IS NOT NULL`, and a matching active `platform.plan_prices.plan_id`. Current project offers are demo-only, so this path is deliberately not available until a real billing/verification workflow exists.

**Do not test this with real children's personal data** until privacy notices, legal obligations, retention/deletion procedures, verified ownership and backups have been approved. Use synthetic learners and guardian contacts for development pilots.

## Flutter navigation

- **Owner in Step 6 demo:** `SchoolActivationRequestCard` offers **Request approval**, displays `submitted`/`rejected`/`provisioned`, and has **Open real school dashboard** after approval.
- **Platform operator with verified AAL2:** `PohantoonAiApp` routes to `SchoolProvisioningOperatorScreen`, separate from the old mock `OrganizationControlPanel`. View pending/rejected/provisioned cases, review details, approve or reject with evidence.
- **Owner after approved provisioning:** after the usual sign-in + MFA gate, Module 03 loads active `school_owner` memberships and displays `LiveSchoolDashboardScreen` with real school data, then Admissions.
- **Ordinary account or unapproved demo:** stays in onboarding/demo, no real student access.

### Important: no operator account was auto-created

The live project currently has **zero** active platform operators. This is intentional: a school applicant must not designate themselves as the approver. An existing verified, separately controlled reviewer account must be manually granted an operator role by the project administrator. Only perform this after personally verifying the human identity and the authenticator MFA factor.

From Supabase **SQL Editor**, logged in as the database project owner, adapt this one-time bootstrap template with the separately verified platform reviewer's email. Never run it with a school applicant's email.

```sql
BEGIN;
DO $$
DECLARE
  reviewer_id uuid;
  org_id uuid;
BEGIN
  SELECT id INTO reviewer_id
  FROM auth.users
  WHERE lower(email) = lower('REPLACE_WITH_VERIFIED_REVIEWER_EMAIL')
    AND (email_confirmed_at IS NOT NULL OR confirmed_at IS NOT NULL);
  IF reviewer_id IS NULL THEN
    RAISE EXCEPTION 'Reviewer Auth account/email confirmation not found';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM auth.mfa_factors
    WHERE user_id=reviewer_id AND status::text='verified'
  ) THEN
    RAISE EXCEPTION 'Reviewer must enroll and verify MFA first';
  END IF;

  SELECT id INTO org_id
  FROM platform.organizations
  WHERE slug='pohantoonai_demo' AND status='active';
  IF org_id IS NULL THEN
    RAISE EXCEPTION 'Target platform organization not found';
  END IF;

  INSERT INTO platform.organization_memberships
    (organization_id,auth_user_id,operator_role,status)
  VALUES (org_id,reviewer_id,'admin','active')
  ON CONFLICT (organization_id,auth_user_id) DO NOTHING;
END;
$$;
COMMIT;
```

If an existing `platform.organization_memberships` row is suspended, revoked, or is another role, the `ON CONFLICT DO NOTHING` template **does not** reactivate or promote it; review such a change separately and record why.

After bootstrap, have that reviewer sign in, pass MFA, then open the **School approvals** console. The application owner must separately confirm their latest school draft review again if it changed after the old confirmation. The original app user can submit the application via the Step 6 card. After approval, they reopen the app or tap refresh to enter the live dashboard.

## Verification completed

In the project `umlzqlbakfwzgadafhyy`, migrations `secure_school_activation_operator_approval_and_pilot_gate` and `school_activation_paid_plan_consistency_and_fk_indexes` have been applied.

The following **rolled-back** SQL tests passed on live development database; no real school/operator/student rows were created:

- `supabase/tests/21_trusted_school_activation_security.sql`: unprivileged self-approval denied; AAL1 platform operator denied; AAL2 operator granted within same organization; demo rejected as verified payment; approved development pilot creates exactly one school and owner membership; idempotent retry does not double-create audit; operator cannot read school student data just by virtue of platform status; self-review remains denied after role grant.
- `supabase/tests/22_school_activation_owner_submission.sql`: confirmed applicant can submit current reviewed draft, see only their own status, deduplicates retries, cannot self-approve, and creates server-owned immutable snapshot.

Current project still has **0** real schools, **0** school memberships, **0** approved school activation links, and **0** operator memberships. This feature is infrastructure and workflow, not implicit approval of a specific school.

### Run Flutter tests on developer's machine before merging

```bash
git fetch origin
git switch feature/trusted-school-provisioning-20261113
flutter pub get
flutter analyze
flutter test test/provisioning/
flutter test
```

The Flutter SDK is not installed in the connected execution environment, so compilation/device tests **have not yet been executed**. Test with two separately signed-in accounts (owner and platform reviewer) and synthetic students. Validate data isolation on Android, tablet, and desktop.

## Source files

- `supabase/schema/21_trusted_school_activation_workflow.sql` — original deployed workflow
- `supabase/schema/22_school_provisioning_payment_consistency.sql` — follow-up consistency and FK-index migration
- `supabase/tests/21_trusted_school_activation_security.sql`, `22_school_activation_owner_submission.sql`
- `lib/features/provisioning/data/school_activation_repository.dart`
- `lib/features/provisioning/presentation/school_activation_request_card.dart`
- `lib/features/provisioning/presentation/school_provisioning_operator_screen.dart`
- `lib/main.dart` and Step 6 preview routing
- `test/provisioning/school_activation_workflow_test.dart` and `authorized_operator_app_route_test.dart`

### Next independent task after approved activation

Test school owner dashboard and Admissions end-to-end; then create real student enrollment per academic year, guardian relationships, class assignments and attendance with school-level RLS. Keep all records school-scoped and distinguish admissions from enrolled students.
