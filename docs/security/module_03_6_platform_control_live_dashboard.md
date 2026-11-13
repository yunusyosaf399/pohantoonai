# Module 03.6 — Real PohantoonAI Platform Control Dashboard

**Repository:** `yunusyosaf399/pohantoonai`  
**Branch:** `feature/real-platform-control-dashboard-20261113`, stacked on trusted school provisioning (PR #5, which stacks on real Admissions PR #4).  
**Deployment:** Database RPC migrations deployed to the existing single Supabase project `umlzqlbakfwzgadafhyy`; Flutter implementation awaits analyzer, widget/desktop/Android tests and code review.

## Product boundary: platform admin is NOT school admin

The platform Control Panel is a separate authorized user experience reached only by an **active platform organization owner/admin**, after sign-in and Supabase **AAL2**. It does not use school `school_owner`/`school_admin` privileges and does not disclose other organizations' schools, guardians, or students.

All five sections are fed by **actual persisted database records**; no `MockOrganizationRepository`, fake metrics, seeded schools, dummy account cards or estimated revenue.

| Section | Real data / actions |
|---|---|
| Overview | Exact scoped provisioned and active schools, submitted school requests, school accounts, admitted-applicant count, MFA-enrolled accounts, last-30-day requests, six-month submitted/provisioned trends, and links to reviews |
| Requests | Server-paged requests, including older submissions; inspect school, legal name, plan and contact email; **approve** verified development pilots or verified paid subscriptions, **reject** completed verified applications, or request further verification on legacy cases |
| Schools | Paginated authorized schools, organization, lifecycle status, activation basis, owner email, members, admitted and pending admissions |
| Accounts | Paginated school-member directory with active/suspended/revoked membership, Auth email confirmation, enrolled MFA, account ban status, and last sign-in timestamp; optional account-risk filter |
| Security | Authorized account posture KPIs and last 30 audited onboarding decisions, including approval evidence/requests for more info |

### Accurate terminology

- **Admitted learners** comes from status=`admitted` in school admissions; the full enrollment/attendance module is not implemented yet.
- **MFA-enrolled** means the account has at least one verified Supabase Auth factor. It **does not** mean every current session used AAL2. Platform reviewer sessions, separately, MUST have AAL2 for any portal RPC.
- **Signed-in accounts (30d)** counts scoped Auth accounts whose `last_sign_in_at` is within 30 days, *not* total sign-in events.
- **Security email failures (30d)** reflects only records stored in `public.account_auth_email_notifications` as `status='failed'`. It is **not** an exhaustive email-delivery or intrusion-detection system.
- **School accounts** counts distinct Auth accounts with membership in an eligible provisioned school of the operator's organization, not every anonymous signup in the Supabase project.
- Review queue is paged at 50 entries. Schools and account directories are also 50 records/page. Search and risk filtering affect **the current displayed page**, not all database rows. There are no false global-search claims.
- No payment/revenue, attendance, class or fee metrics appear because those production models are not yet linked.

## Authorization, confidentiality and audit

The production app calls only `public.platform_control_*` RPCs and the existing independently reviewed provisioning RPCs.

1. Each RPC requires a **real** `auth.uid()`, Supabase `auth.jwt()->>'aal' = 'aal2'`, active `platform.organization_memberships` with role `owner`/`admin`, and an `active` organization.
2. Every row is scoped through `platform.school_onboarding_requests.organization_id`, corresponding provisioned-school linkage, and matching active operator membership. A platform operator from Organization A cannot read Organization B's schools, members, request queue, metrics or history.
3. The privileged SQL functions have `SET search_path=''`, qualified schema identifiers, explicit Auth checks, and no execute privileges granted to `anon` or `PUBLIC`. The private helper `security_private.assert_platform_control_access` is not exposed to clients.
4. The public Flutter app does **not** receive `service_role` credentials. Account-monitoring payloads never include raw user/session IP, passwords, authentication tokens, factors' TOTP secrets, recovery codes, guardian PII or individual student records.
5. Approval/rejection/requests-for-information remain audited in `platform.school_onboarding_reviews`. Monitoring the directory does **not** authorize editing roles, changing school lifecycle state, disabling accounts, or revoking sessions: these sensitive operations require future separately designed workflows and audit trails.
6. The legacy `OrganizationControlPanel` with `MockOrganizationRepository` remains only behind an explicit `showOrganizationPreview` flag **and debug mode** for old UI/testing. It is not the production platform route.

The database deliberately returns 0 schools and 0 school accounts when no school has been provisioned. It does **not** infer real access from demo onboarding workspaces or bypassed checkout.

## Historic request protection

The previously existing submitted request has **no** verified owner Auth ID and **no** `platform.school_activation_snapshots` record. It is now visible in the authorized review queue as **Verification required**, but the UI does **not** show Approve or Reject. An authorized AAL2 platform reviewer can choose **Request verified resubmission**, recording a 20–2000 character reason and the `request_information` decision, transitioning the request to `more_information`.

This action is **an internal database review record only**. It does not send an email. An operator must follow official support procedures to reach the applicant. The applicant must sign in to a verified Auth account, complete and confirm the current school setup, and submit a **new verified application** if the old request has no bound Auth identity. Never transfer a legacy request to a guessed email address or owner UUID.

The existing `approve_school_activation` database function still rejects any request lacking the verified snapshot, even if a malicious client attempts to invoke it directly.

## Source and migration map

- `supabase/schema/23_platform_control_live_monitoring.sql`: operator access assertion, overview, school directory, school accounts, six-month trends and audit review history
- `supabase/schema/24_platform_review_legacy_request_gates.sql`: paged legacy-aware request queue and operator-reviewed information-request action
- `supabase/schema/25_platform_submitted_request_queue_only.sql`: review only submitted/decisioned requests; unpublished draft records are excluded
- `lib/features/platform/data/platform_monitoring_repository.dart`: typed, injectable Supabase RPC adapter
- `lib/features/platform/presentation/platform_control_dashboard_screen.dart`: responsive five-section platform dashboard with actual school/account rows and correct empty/error/loading states
- `lib/features/provisioning/data/school_activation_repository.dart`: paged real queue and information request API
- `lib/features/provisioning/presentation/school_provisioning_operator_screen.dart`: embedded approval UI, secure legacy request action, server pagination
- `lib/main.dart`: authorized operator after MFA routed to real platform dashboard; old preview debug-only

## Database tests completed

Three **rollback-only** Supabase SQL tests (no live records created):
- `supabase/tests/23_platform_control_monitoring_security.sql` — deny anonymous, non-operator, AAL1 operator, revoked operator; enforce pagination bounds; verify returned metrics are non-null.
- `supabase/tests/24_platform_review_legacy_request_security.sql` — show unverified legacy request only to same-org AAL2 operator; block approval; require audited information request; prevent AAL1 review.
- `supabase/tests/25_platform_control_cross_organization_isolation.sql` — provision temporary school in Organization B and assert Organization A operator cannot see its application, school, member account, or KPI counts; authorizing B makes the record visible. All fixtures rolled back.

## Operator activation prerequisite

**No operator role or school was auto-created.** A project owner must explicitly provision a separately verified platform reviewer with enrolled MFA; see `docs/security/module_03_4_school_provisioning_and_platform_operator_approval.md` for the one-time, owner-controlled bootstrap SQL. Never grant an applicant the ability to approve their own school.

## Local Flutter validation before merge

The Flutter SDK is unavailable inside the connected assistant environment. Run on the developer's Flutter workstation after safely backing up/reconciling local uncommitted changes:

```powershell
git fetch origin
git switch feature/real-platform-control-dashboard-20261113
git pull --ff-only origin feature/real-platform-control-dashboard-20261113
flutter pub get
flutter analyze
flutter test test/platform/
flutter test test/provisioning/
flutter test test/admissions/
flutter test
flutter run -d windows
```

**Known local issue:** a previous developer log showed that `school_dashboard_setup_preview.dart` had uncommitted changes and unresolved `SizedBox` references. Investigate the developer working tree with `git diff -- lib/features/onboarding/presentation/school_dashboard_setup_preview.dart` before assuming those errors originate in this branch. Preserve your edits before restoring anything.

Once CI and device tests succeed, merge in dependency order: PR #4 (Admissions), PR #5 (Provisioning), then the Platform Control Dashboard PR. Do not start live school-child data entry until governance and tenancy checks pass.

## Recommended next independent tasks

1. Verified owner-to-operator messaging for information requests and school approval outcome via Resend, with audited delivery, idempotency and no OTP exposure.
2. Explicitly approved, audited **account/security actions** (temporary school suspension, membership revocation, session invalidation) with dual control and reason codes.
3. Server-side search and sorting across all authorized schools/accounts, not only current pagination window.
4. Real Auth security-event monitoring, account anomaly flags, and incident/audit export; retain least-privilege and data-minimization policy.
