# Module 02 — School Dashboard Foundation, School Logo, and Profile Editing

> **Implemented:** 2026-11-11 (GitHub main).  
> **Development database:** existing one-project Supabase environment (pohantoonai, ref umlzqlbakfwzgadafhyy).  
> **Source and database DDL:** deployed successfully.  
> **Runtime Flutter build/device test:** still required; remote GitHub Actions runners have a billing/spending-limit blocker.  
> **Do not confuse the Step 6 DEMO workspace with a provisioned school.** Payment skip is NOT a payment, approval, subscription entitlement, or school membership.

## Scope and user-facing flow

The reference designs include mobile, tablet, expanded Windows/Linux/Web and narrow desktop light/dark layouts. The source implements one responsive Flutter page with the existing Pohantoon AI branding and the saved school applicant's name (not hardcoded Horizon International School).

1. Step 3 School Setup now offers **Choose / Replace / Remove school logo**. JPG/PNG/WebP images are validated by file signature, limited to 2 MiB and uploaded with the authenticated applicant's UUID in a private Storage bucket. Only a storage object **path** is saved on the applicant draft; never a permanently public URL or image bytes. The applicant must save the school draft after an upload.
2. Step 4 School Identity review displays the private logo through a short-lived signed URL.
3. Step 5 **Skip for Now** still creates only the unpaid test skip status.
4. Step 6 now presents a real Flutter **demonstration dashboard UI**, using explicitly illustrated demo data while all real school tenant tables remain empty.
5. Dashboard **profile icon** offers Edit school details, Change logo, Edit school contact, Edit location, Edit academics, and Back to payment. Editing reuses Step 3, with its RLS-controlled school draft and validation. After editing, the applicant must re-confirm Step 4 and re-skip Step 5 before returning. The authenticated email stays locked.
6. Demo dashboard shortcuts show "not available in demo preview" rather than writing to unimplemented student/staff/finance APIs. The left navigation, global search, and mobile navigation remain visible for realistic layout testing.

## Dashboard components

| Component | Current implementation |
|---|---|
| Branding, School Workspace, profile | Dynamic school draft name, optional private school logo, signed-in contact initials; demo workspace disclaimer |
| Global search | Opens a searchable demo overlay; no student/PII database query yet |
| Date and Academic Year | Current local date, demo academic-year selector stored as applicant UI preference |
| KPIs | Four demo cards: total students, staff, classes, campuses; illustrative numbers clearly marked DEMO DATA |
| Analytics trend carousel | Six independently designed series: enrollment, attendance, admissions, fee collection, staffing and classroom capacity; auto-rotates every **10 seconds** |
| Hover and fullscreen behavior | MouseRegion pauses rotation on hover and resumes after exit; previous/next arrows; full-screen chart viewer stops the timer until closed |
| Attendance overview | Demo attendance percentage donut, present/absent/excused legend, educational interpretation |
| Quick actions | Add student, New admission, Mark attendance, Record payment, Add staff, Send notice, etc. "Customize" stores own-account shortcut preferences; actual commands remain disabled |
| Recent admissions | Rotates batches every **10 seconds**, pauses on hover; "View all" opens full demo list |
| Recent approvals | Separate demo activity feed, also rotates/pause on hover; "View all" opens full approvals list |
| Fees | Demo collected/outstanding AFN data and progress bar; "View finance" is intentionally unavailable until live finance module |
| Responsive design | Collapsible narrow desktop icon rail, expanded desktop sidebar, tablet content grid and bottom navigation for phones |
| Themes | Existing Light / Dark / System setting, used throughout without a second theme manager |

The illustrative data is located **only** in [dashboard_demo_data.dart](../../lib/features/dashboard/domain/dashboard_demo_data.dart). No real individual student/admission/payment records are inserted by this module.

## Schema migrations and security

### 09 — Private school-logo Storage

[SQL source](../../supabase/schema/09_school_logo_storage.sql) — **deployed as migration 20261111125611**.

- Adds nullable public.school_setup_drafts.logo_storage_path, with a constraint requiring the exact applicant UUID prefix and a supported image filename under userId/logos/.
- Creates **private** bucket school-logos with max file size **2 MiB** and allowed MIME types image/jpeg, image/png, image/webp.
- Adds four policies on storage.objects: SELECT/INSERT/UPDATE/DELETE, all restricted by authenticated UUID folder and exact logos directory. Writes additionally require owner_id matching auth.uid() and image extension.
- UI uses [file_selector](https://pub.dev/packages/file_selector) 1.1.0, pinned in pubspec.yaml, for Windows/Linux/macOS/Android/iOS/Web native file selection. The Dart model checks file magic bytes and size before upload.
- Signed URL is valid for 600 seconds; it is never persisted in a school draft. Removing a logo currently clears the draft pointer; old objects may need eventual owner-only cleanup.
- **Security note:** extension/MIME detection is not a malware scanner or image re-encoder; production image processing and scanning may be added later before serving school branding publicly.

### 10 — Applicant-owned demo UI preferences

[SQL source](../../supabase/schema/10_demo_dashboard_preferences.sql) — **deployed as migration 20261111125713**.

Table public.onboarding_demo_dashboard_preferences:

| Field | Type | Meaning |
|---|---|---|
| user_id | uuid PK/FK to onboarding_payment_preferences.user_id | Applicant account; never school member ID |
| academic_year_label | text | UI year selected in demo |
| selected_chart | controlled enum-like text | Enrollment, attendance, admissions, fees, staff or capacity |
| quick_actions | constrained text[] | Customize action slots, max eight |
| updated_at | server-owned timestamp | Preference revision |

- RLS own user: SELECT/INSERT/UPDATE; no anonymous grants.
- SECURITY INVOKER trigger verifies the applicant has a **skipped_for_testing** payment state before allowing writes.
- Test skip grants nothing beyond demo dashboard preferences.
- [SQL security test](../../supabase/tests/10_demo_dashboard_preferences_security.sql) passed in one rolled-back transaction, checking spoofed account, invalid chart/action and non-skipped write rejection.

### 11 — Real tenant dashboard read foundation

[SQL source](../../supabase/schema/11_school_dashboard_foundation.sql) — **deployed as migration 20261111125810**.

These six tables are genuinely **empty**. They are a secure future contract, not a provisioned business tenant:

| Table | Key/relationship | Purpose |
|---|---|---|
| public.schools | id UUID PK; unique slug | Future school identity/lifecycle; created only by approved private provisioning |
| public.school_memberships | composite (school_id,user_id), user FK to Auth | Approved tenant membership / role / status |
| public.school_academic_years | (school_id,id) unique, date range | Scoped school years and current year |
| public.school_dashboard_snapshots | PK school_id,academic_year_id,snapshot_date | Aggregated daily KPI / attendance / fee amounts as integer minor units |
| public.school_dashboard_trends | PK school_id,academic_year_id,month_start | Aggregated trend series: enrollment, admissions, staff, attendance percentage, fees |
| public.school_dashboard_activity | id UUID PK, school_id FK | Admission, approval and other recent school events |

Every row is scoped to school_id; academic-year references are composite by school_id; date/metric constraints are present, indexes support common scoped dashboard queries.

**Security:** all six tables enable RLS. Authenticated clients get SELECT only, **no INSERT, UPDATE or DELETE**. Membership can only be read for the signed-in user's own record; school identity/year requires an active membership and active school. Sensitive dashboard snapshots, trends and recent-activity details require an active membership with school_owner or school_admin role and an active school lifecycle. Anonymous users cannot access any of these tables. A user skipping Step 5 gets no school membership and cannot read them.

A later trusted backend service must create school records, memberships and aggregate metrics after the business policy authorizes provisioning. Do not use client-side upserts to add memberships or fake a payment activation. Student/admissions/HR/finance fact tables and their scoped permissions remain separate planned modules.

[Transaction-only tenant security test](../../supabase/tests/11_dashboard_foundation_security.sql) **passed**, verifying 0 unauthorized tenant rows visible, no client writes to schools, all six RLS-enabled, four storage policies and private bucket; no writes persisted.

## Actual repository files

- [Responsive dashboard UI](../../lib/features/onboarding/presentation/school_dashboard_setup_preview.dart)
- [Timer/hover/fullscreen trends and activity](../../lib/features/dashboard/presentation/rotating_dashboard_panels.dart)
- [Fixture-only demo series and feeds](../../lib/features/dashboard/domain/dashboard_demo_data.dart)
- [Account dashboard preferences](../../lib/features/dashboard/data/demo_dashboard_preferences_repository.dart)
- [School setup form with logo](../../lib/features/onboarding/presentation/school_setup_screen.dart)
- [Logo picker widget](../../lib/features/onboarding/presentation/school_logo_picker.dart)
- [Logo upload/short-lived URL service](../../lib/features/onboarding/data/school_logo_repository.dart)
- [Applicant draft model](../../lib/features/onboarding/domain/school_setup_draft.dart)
- [Review logo display](../../lib/features/onboarding/presentation/school_review_preview.dart)
- [Step 6 navigation and profile edit](../../lib/main.dart)
- [Dashboard widget tests](../../test/dashboard/school_dashboard_test.dart)
- [Demo pref RLS test](../../supabase/tests/10_demo_dashboard_preferences_security.sql)
- [Tenant read/Storage security test](../../supabase/tests/11_dashboard_foundation_security.sql)

## Remaining gates (do not mark complete)

1. Run flutter pub get (file_selector 1.1.0 is new), commit resulting pubspec.lock and any generated desktop plugin registrants; run flutter analyze, Flutter widget tests, compile Windows and Android/Web.
2. Validate logo picker on Android, Windows, Web, iOS/macOS, especially valid image bytes, private signed-download and image dimensions; check Storage's owner_id field on an actual upload. Never place a service_role key in Flutter.
3. Verify six analytics advance **after 10s** and hover pauses/reset works; test desktop scroll, tablet grids, mobile bottom nav and full-screen layouts.
4. Build private operator-approval and payment authorization workflows before provisioning a school.
5. Add real domain tables (students, staff, admissions, attendance, fees) with school_id/FKs/RLS and server-side materialization of dashboard aggregates. Replace fixtures through a tenant-authorized repository; do not simply remove the DEMO DATA badge while data is still synthetic.
6. Implement approved school editable-field policy, organization-reviewed sensitive-field locks, record revisions/audit events and owner/admin permission checks for *real* school edits. The current profile menu edits only pre-provisioning school_setup_drafts.
7. Connect live search to scoped indexes, implement all approval and student detail pages as role-authorized modules, and define robust analytics filter/time-period and localization before general release.
8. Review existing separate Supabase Security Advisor notice: leaked-password protection disabled. https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Design and authorization recommendation

Treat "school application draft" and "approved active school" as distinct states/tables. During testing, all demo analytics must stay isolated from actual student records. After approval, migrate/validate the applicant school information into public.schools through an audited server-side provisioning workflow; grant the user a school_owner membership transactionally. Allow non-locked school profile edits through separate real-school endpoints with authorization and audit logs. This avoids any bypass through the Step 5 skip button.


## Final hardening notes — 2026-11-11

- [Logo path negative test](../../supabase/tests/09_school_logo_security.sql) executed in ROLLBACK: own-image path allowed; cross-account path, wrong folder and SVG extension rejected. No production object was uploaded in this automated SQL test; real Storage API integration still needs a signed-in device test.
- [Dashboard widget test](../../test/dashboard/school_dashboard_test.dart) includes 10-second auto-rotation, mouse hover pause/resume, recent approvals/admissions auto-rotation, full-screen viewer and profile menu callback. Tests are **committed, not executed**.
- Desktop Ctrl+K now opens the demo search dialog, matching the shortcut hint shown in the UI.
- macOS Runner DebugProfile and Release entitlements explicitly permit user-selected read-only files, as required by file_selector. Windows/Linux/Android/iOS/Web use the endorsed file selector implementation.
- **Dependency caveat:** pubspec.yaml pins file_selector 1.1.0; pubspec.lock has not yet been regenerated because no Flutter SDK is installed in this execution environment. On the developer laptop run flutter pub get and commit the updated lockfile together with generated platform registrant changes, then flutter analyze, flutter test and flutter run -d windows.
