# Module 03 — Real Admissions and school dashboard (first controlled release)

**Repo:** pohantoonai. **Status 2026-11-13:** database migrations applied to the single Supabase project; Flutter changes on branch `feature/secure-school-admissions-20261113`, awaiting code review/build/device acceptance. Flutter SDK not present in the connected execution environment.

## Why this module exists

The Step 6 dashboard has static, explicitly labelled DEMO data and `onboarding_dev_workspaces` permissions. Those **do not** confer a real tenant, subscriptions, school roles, or access to students. The real database currently contains **zero** rows in `public.schools` and `public.school_memberships`; no school should be auto-created from an onboarding draft or skipped payment.

When the account signs in, the app first checks Supabase MFA. Once MFA is satisfied, it loads only ACTIVE `school_owner`/`school_admin` memberships. A qualifying account opens `LiveSchoolDashboardScreen`; a user with no provisioned school remains on the onboarding/development-preview path. A network error fails closed to Retry, not to a guessed school.

## Database schema and data lifecycle

One global Supabase database. Every applicant is tied to `public.school_admissions.school_id -> public.schools.id`. User IDs are Supabase Auth IDs, not school identifiers.

| Table/view | Role |
|---|---|
| `public.schools` | Real provisioned school tenant. Must have `lifecycle_status='active'`. |
| `public.school_memberships` | Trusted grants for account+school. Only `membership_status='active'` with `school_owner` or `school_admin` may administer admissions. |
| `public.school_academic_years` | Optional composite FK `(school_id, academic_year_id)` on an admission prevents a school choosing another school's year. |
| `public.school_admissions` | Applicant's first/last names, optional date of birth, requested grade, guardian name/phone/optional email, notes, decision status, created/updated identity and timestamps. |
| `public.school_admission_counts` | Exact, live pending/admitted/rejected/total counts. `security_invoker=true` ensures **underlying RLS** applies to aggregates. |
| `public.school_dashboard_activity` | Existing school activity stream. Private server trigger logs received and decided admission events with the matching school ID. |

Admissions start `pending`; authorized admin can mark `admitted` or `rejected`. Final decisions cannot be silently changed. No hard-delete is exposed to clients. "Admitted students" in this first phase means **admitted applications**, not a separate class/attendance/enrollment record. Future student-registry, guardianships, grade assignments, attendance, fees and exports are separate modules.

An applicant's school ID, primary ID, creating user and creation time are immutable after insert. Every updated admission receives `updated_by=auth.uid()` and server timestamp; the database enforces these constraints even against a malicious client modifying API parameters.

### Authorization is database-enforced

- `anon`: no SELECT, INSERT, UPDATE or DELETE of admissions.
- `authenticated`: SELECT/INSERT/UPDATE only when their **current** `auth.uid()` has an active `school_owner` or `school_admin` membership for that exact `school_id` AND the school is active.
- `teacher`, `staff`, suspended/revoked memberships, and demo-only applicants: no admissions access.
- MFA restrictive RLS policy `AS RESTRICTIVE` requires Supabase AAL2 for accounts with an enrolled authenticator. This is separate from the Flutter MFA gate.
- SQL triggers reject nonpending insertion, cross-school reassignment, unauthorized change of `created_by`, invalid future birth dates, and final-decision edits.
- The event-audit SECURITY DEFINER trigger resides in `security_private`, not in the public API namespace.
- Live dashboard count view is `security_invoker=true`; it does **not** aggregate across other schools.
- Every Flutter data call supplies `.eq('school_id', selectedSchoolId)` as defense in depth; this filter **never replaces RLS**.
- No `service_role` key, hidden credential or authorization shortcut in Flutter.

## Flutter flows

- `lib/main.dart`: after MFA validation, resolve ACTIVE authorized schools; real dashboard takes precedence over demo workspace. Sign-out/account switching/recovery clear old school state.
- `LiveSchoolDashboardScreen`: real KPIs (not demo estimates), recent admissions, select authorized school, refresh, navigation to Admissions and Students.
- `SchoolAdmissionsScreen`: school selector; status and search filters; add pending admission form; approve/reject action with confirmation; the Students tab shows admitted applications.
- `SupabaseSchoolAdmissionsRepository`: session-scoped Auth API calls and explicit school_id filters; listing capped at the **200 most recent** applications per school. Summary counts are exact from the RLS-invoker view; search/list pagination will follow as volume grows.
- Step 6 **DEMO** quick actions and sidebar can open this real screen, but without active membership it shows **School access required** and cannot enter records.

## Activation prerequisite — school provisioning

Before any real admission can be saved:
1. A trusted organization/platform operator reviews and approves the school's actual onboarding/application and subscription eligibility as required by product policy.
2. Through an admin-controlled backend provisioner (not a public Flutter RPC, user-editable metadata or the demo skip flag), create the approved `public.schools` row with a stable UUID, verified name and `lifecycle_status='active'`.
3. Grant the authorized Auth user an explicit `public.school_memberships` row for that `school_id`, role `school_owner` or `school_admin`, status `active`.
4. Sign in with that account, satisfy any enrolled MFA, reopen/refresh. The real dashboard will appear.
5. Later provisioning of additional school admins should require a separate admin-approved invitation workflow and auditable role grants.

**Do not manually attach arbitrary users to a school without checking ownership/approval.** The current project intentionally does not auto-grant any membership: this prevents account impersonation and cross-tenant exposure.

## Deployment history

The following Supabase migrations have been applied to `umlzqlbakfwzgadafhyy`:

- `school_scoped_admissions_first_module`: admissions table, constraints, restrictive MFA and owner/admin RLS, activity trigger.
- `school_admission_rls_invoker_live_counts`: exact per-school metrics view with caller security.
- `school_admission_audit_trigger_private_and_fk_indexes`: privileged activity trigger moved to `security_private`, and FK indexes added.

Source migrations: `supabase/schema/18_school_admissions.sql`, `19_school_admission_live_counts.sql`, `20_school_admission_privileged_trigger_hardening.sql`. These are sequential historical migrations, not independent repeatable scripts. Do not manually reapply them.

## Security tests and verification

`supabase/tests/18_school_admissions_rls.sql` was executed successfully **inside BEGIN/ROLLBACK** against the live schema using temporary schools and existing Auth identities. No test student persisted. It verified:
- Admin A can insert/view/approve school A and read its aggregate counts.
- Admin A cannot write school B, and cannot change an admission's school ID.
- Admin B cannot read school A records OR its aggregate counts.
- Final decisions cannot be overwritten.
- Revoking membership removes school access.
- Authenticated users have no DELETE grant and anon users have no SELECT grant.
- The restrictive MFA policy exists.

Live read-only check confirms: **0 schools, 0 memberships, 0 admissions**; RLS on; `security_invoker=true` on count view. Existing school MFA policies were checked and are also restrictive.

### Flutter tests to run on developer machine

```bash
git fetch origin
git switch feature/secure-school-admissions-20261113
flutter pub get
flutter analyze
flutter test test/admissions/school_admissions_screen_test.dart
flutter test test/dashboard/live_school_dashboard_test.dart
flutter test
```

Physical tests after provisioning: authorized school A admin creates a pending learner, sees real counts, approves and sees admitted count; school B admin cannot see it; teacher and suspended admin denied; users without MFA challenge cannot read records. Test Android, desktop and tablet widths; test sign-out and account switching to confirm no stale school data.

**Not yet verified:** Flutter compilation on a device/CI, actual admissions delivery to an approved school account, high-volume pagination, end-to-end provisioning UI.

## Recommended next independent tasks

1. Trusted approval-to-provisioning workflow (back-office school creation/membership grants), with audit log and subscription checks.
2. Full student roster (stable student ID, enrollment per academic year/grade/campus, guardian relations, transfers and dedup policy); never conflate admission with attendance.
3. Server-side paging and fine-grained admission audit history, selective field masking for personnel, retention/deletion requests.
4. Attendance and school dashboard KPIs from real tables; no fake staff, finance or academic data.
