## Module 02.2 execution evidence — 2026-11-11

- Step 2 plan cards compacted, leaving selected plan/state and backend product catalog intact.
- Deployed [development workspace SQL 12](../../supabase/schema/12_dev_workspace_persistent_access.sql) as Supabase migration 20261111140501. Owner-only RLS and active demo plan+completed school draft checks; account-specific development_preview is NOT a financial or school-tenant entitlement. Existing dashboard preference rows preserved.
- [Database security tests](../../supabase/tests/12_dev_workspace_security.sql) passed in ROLLBACK: unauthorized user, fake payment approval and school creation denied.
- Flutter now restores same workspace after verified Google or email/password login; brand new demo completes Step 3 and opens dashboard without payments.
- Added in-dashboard school/owner settings, with locked regulated fields and account email, plus password setup through Supabase Auth (never in SQL).
- Added native Supabase Auth email/password signup, OTP verification, resend, login and recovery UI, with committed Auth email templates. **Hosted email templates and SMTP must still be configured by an authorized operator**; no custom Edge Function necessary.
- [Implementation/verification contract](../database/module_02_2_dashboard_auth_profiles.md).
- Flutter build/test/UX remains unverified due GitHub Actions billing restrictions and unavailable local Flutter SDK.


# Master Migration Roadmap — Pohantoon AI

> **Status:** [In Progress] · **Last updated:** 2026-11-10 · **Target:** `yunusyosaf399/pohantoonai` (`main`)  
> **Source:** `yunusyosaf399/edusync_saas_school_app` (`main`)  
> **Scope:** migrate the school-management product to **one Supabase project hosting many schools**, with tenant isolation by database constraints, RLS, RBAC and audited server commands.
>
> This roadmap tracks **the new target**, not completion claims in EduSync. Source migration files and historical CI runs are reference material, **not** evidence that anything has been deployed in Pohantoon AI.

## 1. Baseline and completion rules

**Verified repository baseline (2026-11-10):**

- Target: Flutter scaffold (`lib/main.dart`, `pubspec.yaml`), no `docs/` and no Supabase migrations before this documentation step.
- Source: Flutter scaffold plus substantial requirements, architecture, security documents, nine executable Foundation SQL migrations, a non-executable Domain Package 01 draft chain, supporting Python services, and test tooling.
- Source requirements catalog: [EduSync feature catalog](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/requirements/FEATURE_CATALOG_AND_STATUS.md); original [database completion matrix](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/database/DATABASE_COMPLETION_MATRIX.md).
- **Incompatible assumption:** EduSync's one-school-per-Supabase-project trust boundary. No source SQL, schema, RLS policy or service is approved for copy/paste until its cross-school implications are reviewed.

**Status legend:** `[Not Started]` / `[In Progress]` / `[Blocked]` / `[Completed]`. Check `[x]` only after the task's acceptance evidence exists; `[ ]` means open. **[I-NOW]** = truly independent task on an exclusive file today; **[I-GATED]** = independently executable *after* named contract/dependency is approved; **[SERIAL]** = integration-sensitive or shared-file work, one owner at a time. A documentation task is complete when its file is committed and reviewed for internal consistency; implementation additionally needs tests.

**Completion rule for a code task:** design approved → migration/code committed → local tests pass → tenant A/B negative-security tests pass where relevant → CI passes on that commit → evidence linked → tracker updated. A successful source-repository test does not satisfy a target-repository gate.

| Progress metric | Completed | Planned | Progress |
|---|---:|---:|---|
| Required modular `docs/` files | 4 | 14 | 29% |
| All atomic checklist items | 8 | 137 | 6% |
| Target Supabase migrations | 2 | Further module batches TBD | Module 01 schema + function-grant hardening applied on test project |
| Flutter feature modules | 1 mock-only module | Full integration gated | Organization console source committed; tests not verified |
| Cross-school isolation test suites | 0 | Required before any production access | 0 validated |
| Milestones with implementation acceptance | 0 | 19 (M00–M18) | 0% |

**Progress bars (completed versus planned, updated after each accepted task):**

```text
Required documentation  [████░░░░░░░░░░]  4/14  (29%)
All checklist items     [█░░░░░░░░░░░░░░░░░░░]  8/137 (6%)
Accepted implementation [░░░░░░░░░░░░░░░░░░░░]  0/19 milestones
```

> **Tracker authority:** This file is the canonical master status. [`docs/tracking/current_sprint.md`](current_sprint.md) owns the sprint queue; [`docs/tracking/independent_tasks.md`](independent_tasks.md) owns session-specific work orders. Both have been created. Update all three after each accepted task; never mark a future test as passed.

## 2. Milestone summary and dependencies

| ID | Milestone | Dependency / release gate | Status | Parallel strategy |
|---|---|---|---|---|
| M00 | Repository audit and feature traceability | None | [In Progress] | Source inventory read-only, I-NOW |
| M01 | Modular architecture documentation | M00 preliminary scan | [In Progress] | Separate doc files, I-NOW/I-GATED |
| M02 | Decisions and architecture contract freeze | M00–M01 design review | [Not Started] | SERIAL |
| M03 | Tenant/identity/academic foundation schema | M02 (full gate) | [In Progress — platform SQL drafted only] | SERIAL shared migrations |
| M04 | RLS, RBAC, authorization and isolation tests | M03 | [Not Started] | SERIAL until policy freeze |
| M05 | Subscription, entitlements and platform operations | M03–M04 | [Not Started] | I-GATED backend boundary |
| M06 | School configuration and academic structure | M04 | [Not Started] | I-GATED distinct domain |
| M07 | Students, families, admissions, enrollments | M04, M06 | [Not Started] | I-GATED distinct domain |
| M08 | Employees, teachers and teaching assignments | M04, M06 | [Not Started] | I-GATED distinct domain |
| M09 | Calendar, curriculum and timetable | M06, M08 | [Not Started] | I-GATED distinct domain |
| M10 | Attendance, corrections and source adapters | M07–M09 | [Not Started] | I-GATED distinct domain |
| M11 | Learning work, online tests, exams and results | M07–M09 | [Not Started] | I-GATED distinct domain |
| M12 | Fees, invoices, payments and accounting | M05, M07 | [Not Started] | I-GATED distinct domain |
| M13 | HR, employee attendance, leave and payroll | M08, M12 integration contract | [Not Started] | I-GATED distinct domain |
| M14 | Optional campus services and private documents | M04, domain anchors | [Not Started] | I-GATED per service |
| M15 | Notifications, reports, search, audit and AI | Domain permissions and events | [Not Started] | I-GATED per capability |
| M16 | Flutter shared shell, role routing and modules | Mock UI can precede M04; live APIs cannot | [In Progress — mock only] | I-GATED disjoint `lib/features/` |
| M17 | Legacy data migration and tenant cutover | M04, domain schema + validated import | [Not Started] | SERIAL per cutover |
| M18 | Security audit, operations and release | All required gates | [Not Started] | SERIAL release authority |

**Two-track rule (2026-11-10):** Database catalog/schema design and Flutter mock-only UI work may run in parallel on disjoint files. **Owner authorized iterative test-project deployment by module rather than waiting for all catalog names to be formally approved.** Module 01 has now been applied and tested on the single development Supabase project. Build small batches with primary keys and immutable `school_id` in a non-exposed development schema; do not expose live tenant records while RLS, ACL or relational integrity gates are incomplete. Flutter switches from mocks to Supabase only after safe verified APIs and school A/B denial tests. See [catalog](../architecture/table_catalog.md), [sprint](current_sprint.md) and [session registry](independent_tasks.md).

## 3. Atomic implementation checklist

### M00 — Repository audit and traceability
- [x] **M00.01** [SERIAL] Locate and inspect both GitHub repositories and default branches.
- [x] **M00.02** [SERIAL] Establish the target Flutter-scaffold baseline.
- [x] **M00.03** [SERIAL] Identify source requirements catalog, Foundation SQL, draft SQL and security documents.
- [ ] **M00.04** [I-NOW] Produce `docs/tracking/edusync_feature_inventory.md` with feature → source path → target module → current evidence → gap; edit this file only.
- [ ] **M00.05** [I-NOW] Inventory all source migrations, table ownership, authentication flows, private functions, storage and test coverage; append to the inventory file only.
- [ ] **M00.06** [SERIAL] Classify source capabilities as reuse / redesign / defer / reject under single-project tenancy.
- [ ] **M00.07** [SERIAL] Record all unresolved domain decisions, privacy requirements and migration blockers.
- [x] **M00.08** [SERIAL] Publish [383-table candidate catalog](../architecture/table_catalog.md) (30 domains; names proposed, not approved).
- [ ] **M00.09** [SERIAL] Obtain explicit owner approval of names/merges/deferrals and first-batch shortlist.

### M01 — Documentation system (14 required files)
- [x] **M01.01** [SERIAL] Create `docs/tracking/master_roadmap.md` (this roadmap).
- [x] **M01.02** [SERIAL] Create `docs/architecture/database_schema.md` (initial design; not approved DDL).
- [ ] **M01.03** [I-NOW] Create `docs/architecture/single_tenant_vs_multitenant.md`.
- [ ] **M01.04** [I-GATED: M02] Create `docs/architecture/auth_and_rls.md`.
- [ ] **M01.05** [I-NOW] Create `docs/flutter/folder_structure.md`.
- [ ] **M01.06** [I-NOW] Create `docs/flutter/state_management.md` (compare alternatives; no package lock until M02).
- [ ] **M01.07** [I-GATED: M04] Create `docs/flutter/role_routing.md`.
- [ ] **M01.08** [I-GATED: M04] Create `docs/security/rls_policies.md` with approved policy matrix.
- [ ] **M01.09** [I-GATED: M03] Create `docs/security/tenant_isolation.md` with runnable verification contract.
- [ ] **M01.10** [I-NOW] Create `docs/roles/org_owner.md`.
- [ ] **M01.11** [I-NOW] Create `docs/roles/school_roles.md` with proposed permissions and explicit approval status.
- [ ] **M01.12** [I-NOW] Create `docs/errors/error_handling_standards.md`.
- [x] **M01.13** [SERIAL] Create [`docs/tracking/current_sprint.md`](current_sprint.md) for parallel tracks and approval gates.
- [x] **M01.14** [SERIAL] Create [`docs/tracking/independent_tasks.md`](independent_tasks.md), with exclusive ownership and handoffs.
- [ ] **M01.15** [SERIAL] Check relative links, consistent nomenclature, outdated assumptions, and milestone counts.

### M02 — Architecture decisions and contract freeze
- [ ] **M02.01** [SERIAL] Approve platform-owner versus school-owner trust boundaries.
- [ ] **M02.02** [SERIAL] Approve school identity, shared-family account, and multi-school account model.
- [ ] **M02.03** [SERIAL] Freeze roles, permission codes and exact scope-binding semantics.
- [ ] **M02.04** [SERIAL] Freeze immutable `school_id` and composite-FK conventions.
- [ ] **M02.05** [SERIAL] Select API-exposed schema(s), RPC versus view strategy and server-worker trust boundary.
- [ ] **M02.06** [SERIAL] Decide subscription/billing provider interface, suspension behavior and entitlements.
- [ ] **M02.07** [SERIAL] Decide Flutter state management/router after checking current package compatibility.
- [ ] **M02.08** [SERIAL] Publish approved ADRs, unresolved issues and a versioned contract snapshot.
- [ ] **M02.09** [SERIAL] Freeze approved table-catalog version and first physical table batch before SQL.

### M03 — Single-project database foundation
- [ ] **M03.01** [Blocked: Supabase org selection] Create one named development project; pin toolchain, then prepare official migration history. Module 01 portable SQL is drafted in `supabase/schema/`.
- [ ] **M03.02** [SERIAL] Define private/internal/API schemas and explicit Postgres grants.
- [ ] **M03.03** [SERIAL] Implement `schools` and school lifecycle / code uniqueness.
- [ ] **M03.04** [SERIAL] Implement account profiles and verified Auth bindings, including FAMILY kind.
- [ ] **M03.05** [SERIAL] Implement school memberships, role definitions and permission catalog.
- [ ] **M03.06** [SERIAL] Implement role grants, membership-role assignments, typed scope bindings and revocation.
- [ ] **M03.07** [SERIAL] Implement campuses, academic years, school settings and numbering contracts.
- [ ] **M03.08** [SERIAL] Add immutable `school_id` guards, composite foreign keys and tenant-leading indexes.
- [ ] **M03.09** [SERIAL] Implement typed command receipts, audit ledger, outbox and approval foundations.
- [ ] **M03.10** [SERIAL] Provide transactional bootstrap for the first school and its owner; no client self-grant.
- [ ] **M03.11** [SERIAL] Validate clean database install, repeated idempotent setup and upgrade path.

### M04 — RLS/RBAC and hard isolation
- [ ] **M04.01** [SERIAL] Enable and test default-deny RLS on every exposed tenant table.
- [ ] **M04.02** [SERIAL] Implement live-membership permission evaluator without recursive RLS.
- [ ] **M04.03** [SERIAL] Verify scope intersection (school, campus, class, section, subject, assignment, own).
- [ ] **M04.04** [SERIAL] Deny tenant reassignment and cross-school reference forgery at database level.
- [ ] **M04.05** [SERIAL] Separate operator-only administration from school-user sessions and exports.
- [ ] **M04.06** [SERIAL] Lock down private functions, views, storage, Realtime and service credentials.
- [ ] **M04.07** [SERIAL] Build A/B school tests: anonymous, suspended, wrong tenant, dual-school user, role revocation.
- [ ] **M04.08** [SERIAL] Test parent/child and teacher-assignment boundaries; verify hidden fields stay hidden.
- [ ] **M04.09** [SERIAL] Run SQL advisors/lint, negative permission tests and threat-model review.

### M05 — SaaS subscriptions and platform operator
- [ ] **M05.01** [I-GATED: M04] Define plan/features and school-subscription tables in a private boundary.
- [ ] **M05.02** [I-GATED: M04] Implement owner-mediated purchase/onboarding with verified payment state.
- [ ] **M05.03** [I-GATED: M04] Define entitlement snapshots, quota enforcement and renewal/expiry transitions.
- [ ] **M05.04** [I-GATED: M04] Implement platform analytics with privacy limits and no ambient school-row access.
- [ ] **M05.05** [I-GATED: M04] Implement time-bounded audited support access and emergency revocation.
- [ ] **M05.06** [SERIAL] Test cross-school billing denial, event replay and subscription downgrade preservation.

### M06 — School setup and academic structure
- [ ] **M06.01** [I-GATED: M04] School profile, branding, timezone, locale, currencies and campus lifecycle.
- [ ] **M06.02** [I-GATED: M04] Academic-year, level, class, section, room and capacity lifecycle.
- [ ] **M06.03** [I-GATED: M04] School-specific numbering/roll policies and historical configuration.
- [ ] **M06.04** [I-GATED: M04] Scoped reads, approved mutations, audit/replay and A/B tenant tests.

### M07 — Students, families and admissions
- [ ] **M07.01** [I-GATED: M06] Student identity/profile and sensitive-field partitioning.
- [ ] **M07.02** [I-GATED: M06] Parent/family account-to-student verified relationship and revocation.
- [ ] **M07.03** [I-GATED: M06] Admissions stages, applications, decisions, deduplication and handoff.
- [ ] **M07.04** [I-GATED: M06] Enrollment/transfer/promotion/withdrawal, history and roll integrity.
- [ ] **M07.05** [I-GATED: M06] Scoped parent/student checked reads, approvals and race/replay tests.

### M08 — HR identities and teaching assignments
- [ ] **M08.01** [I-GATED: M06] Staff/employee records, department, designation and service history.
- [ ] **M08.02** [I-GATED: M06] Employment status, contract visibility, qualifications and experience.
- [ ] **M08.03** [I-GATED: M06] Class teacher, subject teacher and campus assignment histories.
- [ ] **M08.04** [I-GATED: M06] Test effective dates, scope revocation, overlap and sensitive-profile access.

### M09 — Curriculum, calendar and timetable
- [ ] **M09.01** [I-GATED: M06/M08] Curriculum and class-year subject offerings/electives.
- [ ] **M09.02** [I-GATED: M06/M08] Student optional-subject selection and teacher qualification checks.
- [ ] **M09.03** [I-GATED: M06/M08] Calendar, events, term/period definitions and holidays.
- [ ] **M09.04** [I-GATED: M06/M08] Manual/versioned timetable with section/teacher/room conflict checks.
- [ ] **M09.05** [I-GATED: M09.04] Auto-scheduling as proposal + manual override, not direct unreviewed publish.

### M10 — Attendance
- [ ] **M10.01** [I-GATED: M07/M09] Canonical attendance sessions, roster eligibility and marks.
- [ ] **M10.02** [I-GATED: M07/M09] Manual and QR inputs into the same idempotent command.
- [ ] **M10.03** [I-GATED: M10.01] Corrections, approval history, locking and conflict/replay tests.
- [ ] **M10.04** [I-GATED: M10.01] Teacher/parent scoped views and per-tenant reporting.
- [ ] **M10.05** [I-GATED: approved privacy policy] Future biometric, camera and RFID adapters; never separate attendance truth.

### M11 — Learning, tests and examinations
- [ ] **M11.01** [I-GATED: M07/M09] Homework, attachments, submissions, marking and feedback.
- [ ] **M11.02** [I-GATED: M07/M09] Question bank, online test attempts, timing and confidentiality.
- [ ] **M11.03** [I-GATED: M07/M09] Exams/assessment rules, grades, GPA and component constraints.
- [ ] **M11.04** [I-GATED: M11.03] Result review, publication, locking and audited correction.
- [ ] **M11.05** [I-GATED: M11.04] Promotion decisions and immutable historical result exports.

### M12 — Finance and accounting
- [ ] **M12.01** [I-GATED: M05/M07] Fee types, structures, revisions, concessions and scholarships.
- [ ] **M12.02** [I-GATED: M12.01] Assessed obligations, invoices and immutable line histories.
- [ ] **M12.03** [I-GATED: M12.02] Pending evidence verification and official payment/receipt issuance.
- [ ] **M12.04** [I-GATED: M12.03] Allocation, partial/advance payment, overpayment, refund and reversal.
- [ ] **M12.05** [I-GATED: M12.04] Test arithmetic conservation, idempotency, approval and bank evidence isolation.
- [ ] **M12.06** [I-GATED: provider decision] Future payment-gateway adapters and webhook verification.

### M13 — HR operations, leave and payroll
- [ ] **M13.01** [I-GATED: M08] Employment contracts, leave policies and approval flows.
- [ ] **M13.02** [I-GATED: M08] Employee attendance, overtime and approved corrections.
- [ ] **M13.03** [I-GATED: M08] Salary component revisions, deductions and restricted compensation reads.
- [ ] **M13.04** [I-GATED: M12/M13.03] Monthly payroll runs, finalization, receipts and reversal controls.
- [ ] **M13.05** [I-GATED: M13.04] Verify segregation of duties, self-salary visibility and tenant A/B leaks.

### M14 — Optional and shared services
- [ ] **M14.01** [I-GATED: M04] Library catalog, borrowing, overdue and optional activation.
- [ ] **M14.02** [I-GATED: M04] Transport routes, vehicles, drivers and student assignments.
- [ ] **M14.03** [I-GATED: M04] Hostel buildings, rooms, beds, occupancy and effective-history checks.
- [ ] **M14.04** [I-GATED: M04] Medical incidents and separately authorized sensitive data.
- [ ] **M14.05** [I-GATED: M04] Private file metadata, storage entitlement and signed-access worker.
- [ ] **M14.06** [I-GATED: M14.05] On-demand certificates, ID cards and document generation.
- [ ] **M14.07** [I-GATED: provider decision] GPS / messaging / hardware integration contracts; defer device capture.

### M15 — Cross-cutting intelligence and communications
- [ ] **M15.01** [I-GATED: M03] Notifications, outbox processing and retry/idempotency semantics.
- [ ] **M15.02** [I-GATED: M04] Row- and column-scoped search, report builders, CSV/Excel/PDF export.
- [ ] **M15.03** [I-GATED: M04] School dashboards and aggregated platform metrics with no hidden PII leak.
- [ ] **M15.04** [I-GATED: M04] AI teacher/student/parent assistants with retrieved-data authorization.
- [ ] **M15.05** [I-GATED: M15.04] Prompt-injection, cross-tenant retrieval and sensitive output tests.
- [ ] **M15.06** [I-GATED: M04] Offline encrypted cache, sync, conflict and revocation contract.
- [ ] **M15.07** [I-GATED: approved domain APIs] Global error taxonomy, tracing and alerting.

### M16 — Flutter application and role-based interfaces
- [ ] **M16.00** [In Progress] Build and validate mock-only Flutter organization screens; source code and widget tests exist, passing test evidence pending.
- [ ] **M16.01** [SERIAL] Initialize feature-first `lib/` architecture, DI, router and state mechanism.
- [ ] **M16.02** [SERIAL] Implement Supabase Auth, selected-school context and context-change invalidation.
- [ ] **M16.03** [SERIAL] Implement permission-aware guards; UI guards never substitute for RLS.
- [ ] **M16.04** [I-GATED: M16.01/M04] Organization-owner operations shell in exclusive `lib/features/platform/`.
- [ ] **M16.05** [I-GATED: M16.01/M06] School-owner/admin setup in exclusive `lib/features/school_setup/`.
- [ ] **M16.06** [I-GATED: M16.01/M07] Student/parent portals in exclusive `lib/features/student_portal/`.
- [ ] **M16.07** [I-GATED: M16.01/M08] HR/teacher portals in exclusive `lib/features/staff_portal/`.
- [ ] **M16.08** [I-GATED: M16.01/M12] Accountant/finance portal in exclusive `lib/features/finance/`.
- [ ] **M16.09** [I-GATED: M16.01] Adaptive Android, Windows and Web layout/accessibility checks.
- [ ] **M16.10** [SERIAL] Integrate navigation and cross-role flows; widget/integration tests.

### M17 — Legacy migration and cutover
- [ ] **M17.01** [SERIAL] Inventory source per-school Supabase projects, schemas, files and Auth identifiers.
- [ ] **M17.02** [SERIAL] Build deterministic `legacy_project + legacy_id → school_id + new_id` mapping.
- [ ] **M17.03** [SERIAL] Reconcile duplicate users/emails and select safe invite/reauthentication.
- [ ] **M17.04** [SERIAL] Implement tenant-stamped extract/transform/load with composite-FK verification.
- [ ] **M17.05** [SERIAL] Reconcile row counts, money ledgers, file references and audit/event history.
- [ ] **M17.06** [SERIAL] Test staging cutover, maintenance window, rollback and recovery per school.
- [ ] **M17.07** [SERIAL] Obtain school-by-school sign-off; never drop legacy source before retention gate.

### M18 — Production hardening and release
- [ ] **M18.01** [SERIAL] Dependency/security scan, SQL advisors, secrets audit and threat model.
- [ ] **M18.02** [SERIAL] Run complete tenant A/B, approval, data-export, offline and operator-access matrix.
- [ ] **M18.03** [SERIAL] Validate tenant quotas, performance, indexes and capacity under mixed-school load.
- [ ] **M18.04** [SERIAL] Validate full-project PITR plus selective school export/restore rehearsal.
- [ ] **M18.05** [SERIAL] Configure monitoring, runbooks, incident response, billing reconciliation and support logs.
- [ ] **M18.06** [SERIAL] Confirm accessibility, localization, release channels and platform compatibility.
- [ ] **M18.07** [SERIAL] Final acceptance, rollback rehearsal, release approval and post-release observation.

## 4. Parallel ChatGPT session policy

**Safe now, provided each session edits only its named output file:** M00.04 (`edusync_feature_inventory.md`), M01.03, M01.05, M01.06, M01.10, M01.11 and M01.12. Sessions may read any source, but must not edit `master_roadmap.md`, `database_schema.md`, shared SQL, `pubspec.yaml` or another session's paths.

**Gated:** all `[I-GATED]` entries require their stated completed dependency and a pinned schema/API/permission contract. After gate approval, separate worktrees/branches and exclusive `lib/features/<feature>/`, service or draft-migration subdirectories may be developed independently. An assigned integrator alone edits ordered `supabase/migrations/*.sql`, central routing/DI, shared enums, permissions, tests manifest and trackers.

**Never independently parallelize:** school bootstrap, core tenancy/RLS, Auth-identity mapping, migration numbering, shared permission catalog, billing integrity, final merge, data cutover or production release. Two independent sessions must not run migrations against the same mutable database.

**Session handoff contract:** record task ID; base commit SHA; prerequisite contract/version; exact allowed paths; prohibited paths; test commands; expected acceptance artifacts; commit/PR link; newly discovered risks. Mark `[Blocked]` when a dependency or boundary changes. Merge only after contract compatibility checks. The lead/integrator, not a worker session, updates these canonical trackers.

## Module 01.1 first-screen sign-in execution evidence — 2026-11-10

- **Database applied and verified:** [owner-only `user_profiles` / `user_preferences` RLS](../../supabase/schema/03_account_identity_preferences.sql) in the existing single development project `umlzqlbakfwzgadafhyy`. Three policies per table, anonymous access denied; no school or org membership granted.
- **Edge deployed:** [`account-bootstrap`](../../supabase/functions/account-bootstrap/index.ts) v1 active with `verify_jwt=true`, current user validation and RLS caller-scope. No service credentials are shipped to Flutter.
- **Flutter source committed, validation open:** [adaptive first-screen auth UI](../../lib/features/auth/presentation/account_welcome_screen.dart), [Google/email gateway](../../lib/features/auth/data/account_auth_gateway.dart), [theme selector](../../lib/core/settings/appearance_settings_button.dart), and [widget tests](../../test/auth/account_welcome_test.dart); source and provider setup do not equal a successful login test.
- **Blocked external configuration:** Google OAuth client credentials, email SMTP/delivery, Supabase Auth callback allowlist, Windows URI handler. See [module guide](../database/module_01_account_auth.md).
- **Build validation blocked:** Current GitHub Actions job reports failure without job steps or downloadable runner logs; Flutter SDK unavailable in this execution environment. Pin versions in `pubspec.yaml` and commit a resolved lockfile when the toolchain runs. Do not check implementation tasks as complete until verification passes.
- **Existing `platform` tables:** 12 private tables intentionally keep zero policies; no general authenticated access to organizational records.

## Module 02 dashboard and school branding evidence — 2026-11-11

- Implemented [responsive Step 6 Flutter dashboard](../../lib/features/onboarding/presentation/school_dashboard_setup_preview.dart), [10-second pause-on-hover/fullscreen analytics and rotating admissions/approvals](../../lib/features/dashboard/presentation/rotating_dashboard_panels.dart); explicitly DEMO DATA only.
- Deployed [private Storage bucket](../../supabase/schema/09_school_logo_storage.sql) with 2 MiB size/MIME limits and owner-only policies, draft path and signed logo preview; school logo upload available in Step 3; profile menus return to editable Step 3 sections.
- Deployed [demo dashboard preferences](../../supabase/schema/10_demo_dashboard_preferences.sql) with own-account RLS and skip prerequisite, and [real school read-only tenant foundation](../../supabase/schema/11_school_dashboard_foundation.sql) with active school_owner/school_admin membership checks for finance/admissions analytics. Zero real schools/memberships/snapshots provisioned.
- Migration versions: 20261111125611, 20261111125713, 20261111125810. [SQL security tests](../../supabase/tests/11_dashboard_foundation_security.sql) and [demo preferences negative tests](../../supabase/tests/10_demo_dashboard_preferences_security.sql) passed and rolled back.
- Flutter code and tests committed, but **Flutter compile/visual test pending**; new file_selector dependency requires flutter pub get and regenerating pubspec.lock on the user's Flutter SDK. Real server-only provisioning, domain CRUD and approval workflows remain separate milestones.
- [Full implementation and security contract](../database/module_02_school_dashboard.md).


## Module 01.5 execution evidence — 2026-11-11

- [Step 5 Subscription Payment UI](../../lib/features/onboarding/presentation/school_payment_preview.dart) implements responsive reference layout, method/cycle/billing preferences, disabled real Pay Now, and active Skip for Now. [Step 6](../../lib/features/onboarding/presentation/school_dashboard_setup_preview.dart) is an explicit non-activated dashboard test preview.
- Deployed [payment preference SQL](../../supabase/schema/08_onboarding_payment_preferences.sql) as migration 20261111122224 to the one existing project, with owner RLS, draft/plan review revision enforcement and a strictly unpaid skipped_for_testing state.
- [DB security assertions](../../supabase/tests/08_payment_preferences_security.sql) passed within ROLLBACK; no fake transaction or preference row persisted. Flutter widget tests committed but not yet executed/compiled (GitHub Actions billing blocker).
- No card numbers/CVV, no claims of actual price/discount, no checkout requests, no payment receipt or subscription entitlement, and no real tenant/school access.
- Payment provider and operator approval sequencing must be explicitly designed prior to enabling a live charge or tenant provisioning.

## Module 01.4 execution evidence — 2026-11-11

- [Responsive Step 4 Application Review](../../lib/features/onboarding/presentation/school_review_preview.dart) implemented with dynamic school information and selected plan, four Edit actions, required accuracy checkbox, **Go to Payment** button, and Step 5 safe preview.
- [Review confirmation SQL](../../supabase/schema/06_onboarding_review_confirmation.sql) deployed to the one existing development project as migration `20261111115622`. Strict owner-row RLS and database-stamped review timestamp; rejects stale draft or plan changes.
- [Transactional security checks](../../supabase/tests/06_review_confirmation_security.sql) passed and rolled back; existing school draft data unchanged.
- Flutter compile and widget tests pending because GitHub Actions runner does not start due account billing/spending restriction. **No real payment or school creation enabled.**
- Production business decision pending: earlier design placed operator approval before payment, while the latest UX explicitly navigates directly to a payment stage; secure checkout, approvals and payment failure/refund paths must be finalized before any live charge.

## Cross-platform Auth callback remediation — 2026-11-11

- [Callback setup/acceptance guide](../../supabase/auth/OAUTH_CALLBACK_PLATFORMS.md): desktop Windows unpackaged current-user URI registration + app-links single-instance forwarding, Android/iOS competing Flutter-router disabled, macOS callback URI registered, Flutter Web redirect preserves origin/port/base path while dropping OAuth query/fragment parameters.
- `lib/features/auth/data/account_auth_gateway.dart` launches Google OAuth via the external system browser on native; `lib/main.dart` handles callback code-exchange errors without leaking tokens.
- Regression tests: [Web redirect helper](../../test/auth/oauth_redirect_test.dart) and [native registration contracts](../../test/auth/native_callback_contract_test.dart).
- **Pending release gate:** owner must allowlist `pohantoonai://auth-callback` and exact Web URL(s) in hosted Supabase Auth URL Configuration. Flutter compilation, CI tests and Windows/Android/iOS/Web sign-in remain unverified due account billing/runner blocker. No database schema changes needed.

## Module 01.3 execution evidence — 2026-11-11

- [Step 3 module design](../database/module_01_school_setup.md) documents database and responsive Flutter UI; live schema `20261111064830` applied to the single `pohantoonai` development project.
- `public.school_setup_drafts` is **applicant-owned** and dependent on their saved Step 2 plan. RLS, constraints and server-side plan capacity checks were executed in rollback-only tests. No fake school created.
- Flutter Step 3 form and Step 4 **read-only review preview** committed and wired to `lib/main.dart`; live app compilation and device testing remain blocked by GitHub Actions billing/runner issue.
- No money, school provisioning or organization admin access occurs on draft save or review readiness.

## Module 01.2 execution evidence — 2026-11-11

- [Step 2 module design and tests](../database/module_01_plan_selection.md): two new live public tables, four RLS policies and protected catalog sync against the existing private three-plan source. Migration `20261111050513` applied to the single `pohantoonai` Supabase project.
- **DB gate passed:** executed own-row/anon/private-table denial test, rolled back, and verified zero test selections. Live source and published descriptions match.
- **Flutter code created:** responsive desktop/tablet/mobile light/dark plan cards, selected summary, authenticated app routing to Step 2, save-before-Step 3 and explicit no-payment placeholder.
- **Flutter runtime gate remains open:** Github-hosted Actions runners are blocked by account billing/spending limit before starting; widget tests are only committed, not proven passing.
- **Security advisor item:** leaked password protection disabled at Auth level; the 12 `platform` INFO no-policy notices reflect intentional private schemas. Review provider password security without altering the current plan flow.
- **No school or subscription has been provisioned.** Advance to Step 3 school information only after the corresponding draft schema and client ownership rules are designed.

## 5. Immediate execution queue

**Latest execution evidence (2026-11-10):** Module 01 applied successfully to the one user-created Supabase development project `pohantoonai` (ref `umlzqlbakfwzgadafhyy`, YouPro School). The [12 private onboarding tables](../../supabase/schema/01_platform_onboarding.sql) and [fake seed](../../supabase/seed/01_demo_platform.sql) are deployed; 12/12 have RLS enabled, and 0 have anon/authenticated table read/write access. A previously existing `public.rls_auto_enable()` function had exposed SECURITY DEFINER execution grants; these were revoked via [second SQL patch](../../supabase/schema/02_secure_existing_rls_trigger.sql) and verified. The 12 policy-free private tables produce expected informational linter notices, but no exposed definer warnings remain. [Flutter mock console](../../lib/features/organization/presentation/organization_control_panel.dart) committed; its CI runs have not yet passed. **Live Flutter API/auth and real school provisioning are NOT implemented.**

1. **Owner:** approve/revise the [candidate table catalog](../architecture/table_catalog.md), particularly P0 and first batch; no DDL until approval.
2. **DB:** finish feature traceability, then propose first table columns/types and tenant anchors in `docs/database/first_batch_schema.md`.
3. **Flutter:** independently draft folder/state conventions and build mock-only contracts; use distinct feature directories.
4. **Integrator:** freeze identity, names, migration sequence and API contracts; one owner for shared files.
5. **Safety gate:** test tenant A/B and authorization before allowing Flutter live database queries.

## 6. Risk and decision register

| Risk / open question | Required decision or evidence | Blocking |
|---|---|---|
| Legacy SQL relies on school-wide DB isolation | Rewrite tenant keys, FKs, functions, RLS and all hard-coded singleton assumptions | M03–M18 |
| Cross-school user and shared-family credentials | Identity model, ownership and verified child access | M02, M07, M17 |
| Platform operator as implicit RLS superuser | Server-only operator capability, approvals and audited support access | M04–M05 |
| Mutable/JWT-derived permissions | Database-live, revocable permission and scope resolver | M04 |
| Source `sql.draft` implies readiness | New target migration tests and acceptance evidence | M03 onward |
| Auth account collision across old Supabase projects | Deterministic mapping and safe re-enrollment | M17 |
| Shared project backup/capacity blast radius | Whole-project recovery + tenant-specific export and limits | M18 |
| Storage provider and sensitive document handling | Private metadata, tokenized access, per-purpose entitlement | M14 |
| Supabase SDK/CLI breaking changes | Pin versions; verify current CLI v3 / Flutter SDK v3 migration notes | M02–M03 |
| 2026 API grant default changed | Explicit GRANTs + RLS for all intended Data API objects | M03–M04 |

## 7. Completed-task evidence and maintenance protocol

| Task | Evidence | Current result |
|---|---|---|
| M00.01–M00.03 | Repository tree and source-file inspection, `main`, 2026-11-10 | Source/target preliminary audit only; full feature mapping open |
| M00.08 | [Candidate table catalog](../architecture/table_catalog.md) | 383 proposed tables, owner approval pending |
| M01.13–M01.14 | [Sprint](current_sprint.md) and [parallel tasks](independent_tasks.md) | Both created; no SQL/Flutter code deployed |
| M01.01 | [Roadmap commit](https://github.com/yunusyosaf399/pohantoonai/commit/9345737ea9076e8400fd3fa307d973b6359be1c4) | `master_roadmap.md` present |
| M01.02 | [Database design commit](https://github.com/yunusyosaf399/pohantoonai/commit/161e45926d4fe03d1e14db6c782f4d8c725685e7) | `database_schema.md` present, proposal only |



After **every** accepted task: (1) change its checkbox; (2) set milestone status in section 2; (3) recalculate progress in section 1; (4) update current sprint / independent assignment ownership; (5) link commit, CI, test and relevant ADR evidence; (6) note new blockers and next unblocked action. Do not derive completion from percentage alone or from historical EduSync status.

**References:** [source requirements](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/requirements/FEATURE_CATALOG_AND_STATUS.md) · [source identity model](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/security/01_identity_auth_model.md) · [source RLS matrix](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/security/03_foundation_rls_matrix.md) · [proposed new schema](../architecture/database_schema.md).


- Additional [SQL 14 server-validation migration](../../supabase/schema/14_dev_workspace_required_fields.sql) deployed after end-to-end SQL tests identified the draft table already has some required field checks. Workspace RLS and trigger now validate all essential school identity/contact/capacity fields independently; [negative test 14](../../supabase/tests/14_dev_workspace_required_fields_security.sql) passed with ROLLBACK.


### 2026-11-11 — Authentication and return-to-dashboard acceptance

- Stable Supabase Auth user ID now drives session change handling, clearing account A's dashboard on a direct switch to account B and protecting the same school's saved workspace after Google/password sign-in.
- Committed test: [Google→password→same demo dashboard, email signup→OTP→new dashboard, negative account switch](../../test/auth/auth_return_to_dashboard_flow_test.dart). Flutter tests are **not executed** because remote Actions runner is blocked and local SDK is unavailable here.
- Executed [auth identity/workspace RLS SQL 15](../../supabase/tests/15_auth_provider_same_account_rls.sql) successfully: one verified account with Google+password can read its matching owner-only development workspace, a second confirmed account cannot. Rolled back without changing data.
- Hosted Auth templates/SMTP setup and real device tests remain tracked as [issue #1](https://github.com/yunusyosaf399/pohantoonai/issues/1) and [issue #2](https://github.com/yunusyosaf399/pohantoonai/issues/2). Full [acceptance runbook](../testing/auth_return_to_dashboard_acceptance.md).


## Password-recovery UI isolation — 2026-11-12

- Root cause: a verified Supabase password recovery callback creates an Auth session, and the former Flutter `showDialog` over the existing application allowed the school/student dashboard to remain visible beneath the reset prompt.
- Committed exclusive recovery-only `MaterialApp.home` and isolated Navigator; prevents all normal school setup, dashboard and analytics widgets from rendering during a recovery session; stops ongoing restores and clears previous identity state. Sign-out is required on success/cancel and sign-out failures remain on the secure reset screen.
- The callback now includes non-secret `auth_flow=password_recovery` and captures Web recovery intent before Supabase initialization. New exact redirect targets must be allowlisted in hosted Supabase Auth. `pohantoonai.com` must actually serve Flutter Web before adding it as a Web redirect.
- [Code and security contract](../security/password_recovery_isolation.md); [auth widget test](../../test/auth/auth_return_to_dashboard_flow_test.dart); [URI classification test](../../test/auth/password_recovery_redirect_test.dart). Tests written but not run; GitHub runner blocked and no local Flutter SDK in connected environment. Database schema unchanged.


## Module 02.3 — Account security execution evidence (2026-11-12)

- Added [OTP-first recovery](../../lib/features/auth/presentation/password_recovery_dialog.dart): reset emails are code-only after installing the hosted Supabase Reset Password template. OTP verification is performed by native Auth, not a custom Edge Function. On successful password reset the temporary session signs out; the dashboard never appears mid-recovery.
- Added [TOTP enrollment](../../lib/features/auth/presentation/account_mfa_settings_card.dart) and [exclusive sign-in verification screen](../../lib/features/auth/presentation/account_mfa_challenge_screen.dart). App startup checks Supabase Auth session assurance before restoring a school workspace.
- Deployed [optional MFA AAL2 RLS SQL 15](../../supabase/schema/15_optional_mfa_aal2_enforcement.sql), protecting account and school records and private logos without blocking users who have not enrolled 2FA. [Rollback-only SQL test](../../supabase/tests/15_optional_mfa_aal2_security.sql) passed.
- New pinned local QR dependency qr_flutter 4.1.0; Flutter pub get/test needed, and hosted Reset Password email template must be installed by the project operator.
- [Complete security/UX contract](../security/module_02_3_email_otp_and_totp_2fa.md).
