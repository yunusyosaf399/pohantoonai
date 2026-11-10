# Database Schema and RLS Design — Single-Project Multi-Tenancy

> **Status:** [Proposed / Not Implemented] · **Version:** 0.1 · **Date:** 2026-11-10  
> **Target:** one Supabase project and PostgreSQL database for all schools  
> **Implementation owner:** database/security integrator; **review gate:** M02 in [master roadmap](../tracking/master_roadmap.md).
>
> This file is an **architectural contract draft**, not an executable migration. Table names, constraints, policies and code samples require design approval, local execution, security tests and CI before they become authoritative.

## Table-catalog approval and design sequence (2026-11-10)

The **[383-table candidate catalog](table_catalog.md)** is the single owner-review inventory of proposed table names across 30 domains. It is **not yet approved**. This schema document remains an earlier architecture sketch, so illustrative names here may differ from final catalog names until the owner approves the catalog and the integrator reconciles both documents.

Parallel development is permitted in two separated tracks: Flutter can design mock-backed models and screens now; the database track proposes core table columns/types after approval. The first actual SQL batch must stay inaccessible to public clients, with immutable `school_id` on tenant rows from creation. The full relationships, RLS, RBAC, functions and error taxonomy are later gates **before** exposing any real school data or letting Flutter write to shared Supabase. See [current sprint](../tracking/current_sprint.md).

## 1. Architectural decision and scope

**Previous EduSync model:** one Supabase project (including Auth and school data) per school. School identity was implicit in the deployment. The existing Foundation migrations therefore cannot be transplanted unchanged.

**Pohantoon AI model:** one managed Supabase project, one Auth user directory and one database; each operational row belongs to one school through a required, immutable `school_id`. A person may legitimately belong to more than one school and have several roles in each. A **campus is a scope within a school, not a separate tenant**.

There are two distinct privileged identities:

1. **Organization Owner / Platform Operator:** operates the SaaS platform, subscriptions, infrastructure and approved global aggregated analytics. This is *not* an automatically RLS-authorized reader of every school's student, payroll or medical data. School-record support access needs a separate, short-lived, scoped, audited server workflow.
2. **School Owner:** authenticated user with an active membership and school-owner role within an explicit `school_id`; purchases and manages that school's subscription, staff and settings under policy. Subscription ownership does not itself authorize arbitrary database changes.

Other school roles (Admin, Principal, Teacher, Parent/Family, Student, HR, Accountant, Exam Controller, etc.) are **school-scoped, multi-role and revocable**. Roles supply permission grants; the actual row also must satisfy *school + required scope + subject relationship + workflow state*.

### Trust boundaries

| Layer | Design | Must not do |
|---|---|---|
| Flutter Android / Windows / Web | Publishable client key + user Auth session, explicit active school context | Carry service/secret key, infer authority from selected role or client `school_id` |
| Supabase Auth | Proves user identity (`auth.uid()`); one user may join multiple schools | Treat user-editable metadata as permissions |
| PostgreSQL | Foreign keys + immutable tenant keys + explicit grants + RLS + narrow commands | Depend on Flutter filters for isolation |
| Server / Edge worker | Verify caller, current membership, exact permission/scope and subscription entitlement | Expose admin credentials or generic SQL proxy |
| Operator / billing service | Private control-plane tables, signed billing webhooks, audited admin actions | Bypass tenant privacy just because operator is global |
| Storage, Realtime, search, exports, AI | Recheck authorization against canonical school and row relationships | Become alternate cross-tenant read paths |

**Non-negotiable invariant:** for each tenant table `T`, `T.school_id IS NOT NULL`; for each tenant-to-tenant reference to `P`, both the primary ID *and* `school_id` must match. Any tenancy exception is globally owned, private, explicitly documented and separately authorized.

## 2. Schema boundaries and exposure

Proposed logical schemas (exact names and Postgres versions to be confirmed in M02/M03):

| Schema | Contents | Client exposure |
|---|---|---|
| `auth` | Managed Supabase Auth identities | Supabase-managed; no custom tables inside |
| `app` | Canonical school/domain records with RLS and composite FKs | **Not** a Data API-exposed schema by default |
| `private` | Membership authorization, sensitive fields, operators, subscriptions, approval/audit, helper functions | Never directly exposed |
| `api` | Explicit, field-limited **security-invoker** read projections and reviewed command endpoints | Only approved views/RPCs; explicit grants |
| `storage` | Supabase-managed object metadata if chosen | Bucket/object policies and server access required |

A private schema is not sufficient by itself: enforce table/function privileges, role ownership, RLS as defense in depth, safe `search_path`, and tested function `EXECUTE` permissions. If using a security-invoker view, its invoker must have the *minimum* required underlying permissions and the source table RLS must still filter rows. Do not expose broad `SELECT *` views for sensitive data. Restrict stored procedures to explicit, typed commands rather than arbitrary table/column arguments.

**2026 compatibility note:** Supabase changed Data API exposure defaults; as of 2026-10-30 new `public` tables are not automatically accessible through default grants. Explicit object-level `GRANT` is required as well as RLS. Treat the current project settings, SDK and CLI versions as environment-specific facts to inspect, not assumptions. See [Securing your API](https://supabase.com/docs/guides/api/securing-your-api) and [Data API grants change](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically).

## 3. Proposed foundation tables

**Column conventions:** UUID `id` PK unless natural key explicitly shown; `created_at timestamptz`, `created_by` (verified actor), optional `updated_at`/`row_version` for mutable records; state/date intervals and audit for lifecycle; FKs `RESTRICT` by default for history. For tenant records add `school_id uuid NOT NULL` and `UNIQUE(school_id, id)` so children can reference both columns. Append-only ledger/event tables are not silently updated/deleted.

| Table / owner | Key fields and constraints | Scope / purpose |
|---|---|---|
| `app.schools` | `id`, unique normalized `code`, name, timezone, currency, lifecycle | Tenant root; does **not** have its own `school_id` |
| `private.platform_operators` | PK `auth_user_id -> auth.users`, operator capability/state | Global SaaS operation; no client-issued grants |
| `private.user_profiles` | PK `auth_user_id -> auth.users`, `principal_kind` (`INDIVIDUAL` / `FAMILY`) | Global identity metadata only; not a permission |
| `private.school_memberships` | `id`, `school_id`, `auth_user_id`, state, validity, UNIQUE(`school_id`,`auth_user_id`) | Live enrollment of an Auth account in a school |
| `private.school_roles` | `id`, `school_id`, code, protected/system flag | Customizable role catalog within school |
| `private.permission_codes` | unique code, action/resource, allowed scope types | Platform-defined vocabulary; no school-created executable code |
| `private.role_permissions` | (`school_id`,`role_id`,`permission_code`) composite key | Permission of a role inside that school |
| `private.membership_roles` | `id`,`school_id`,`membership_id`,`role_id`, valid-from/to | Multiple roles for one membership; retained revocation history |
| `private.membership_permission_scopes` | `school_id`, exact membership-role + role-permission linkage, typed scope target | Scope bound to **that exact grant**, not a free-standing global scope |
| `app.campuses` | `id`,`school_id`, local code, lifecycle; UNIQUE(`school_id`,`code`) | Campus assignment target |
| `app.academic_years` | `id`,`school_id`, label/date interval/state | Historical school-specific academic context |
| `private.school_settings_revisions` | `id`,`school_id`, setting key, revision, effective dates, actor | Audited immutable settings history |
| `private.command_receipts` | `id`,`school_id`, operation code, actor, idempotency key, result hash | Replay protection, with scoped uniqueness |
| `private.approval_requests` / `private.approval_steps` | `id`,`school_id`, typed operation and target, requester/reviewer, decision | Protected change workflow, no unchecked dynamic table names |
| `private.school_audit_events` | `id`,`school_id`, actor, action, target, correlation ID, timestamp | Append-only tenant event stream |
| `private.platform_audit_events` | `id`, operator, action, target school *if applicable*, timestamp | Separate global operator audit without nullable tenant shortcuts |
| `private.outbox_events` | `id`,`school_id`, type, aggregate, payload schema version, delivery status | Reliable async delivery; event recipients checked again |
| `private.plan_catalog` | `plan_id`, version, capabilities, billable price references | Platform controlled; global data, no school-scoped client write |
| `private.school_subscriptions` | `id`,`school_id`, plan, state, period, provider reference | School subscription + owner read via checked projection |
| `private.school_entitlements` | `school_id`, capability, value, revision, effective interval | Server-authoritative limits, not JWT/client authority |

### Required relational rules

- Each tenant table FK to `app.schools(id)`; every reference to tenant data uses `(school_id, referenced_id)` against a corresponding `UNIQUE(school_id,id)`/PK. **Single-column FKs to tenant rows are prohibited**, even when the referenced UUID seems globally unique.
- `school_id` is set by a verified command, not accepted from arbitrary Flutter JSON; immutable via database trigger or revocation of column updates **in addition to** policy checks. Explicit audited school transfers create new scoped records/links rather than changing historical ownership.
- Role/scopes must have composite FKs proving that a membership-role, role and permission all belong to the same school and grant. Typed `campus_id`/`section_id`/`subject_offering_id` scope FKs must prove local ancestry; an unchecked `(scope_type, scope_id)` pair is not enough.
- Protect against removing the last active School Owner. An owner cannot self-grant an unapproved permission or exceed a documented delegation ceiling.
- Every tenant-unique business number is unique **within** `(school_id, ...)`, not globally: admission number, invoice number, campus code, staff code, class/section code where applicable.
- Status is soft/temporal where legally necessary; corrections produce revision/history. Use `numeric`/exact minor units for money; never binary floating-point financial amounts.
- Source IDs from legacy projects remain external mapping keys, never implicit new global PKs or client authorization tokens.

## 4. School-domain catalog and FK lineage

All proposed rows below carry `school_id` with composite FKs to their school-owned parents.

| Domain | Representative tables (proposed, not yet migrations) | Critical school-local link |
|---|---|---|
| School configuration | `campuses`, `academic_years`, `class_definitions`, `section_offerings`, `rooms`, `number_sequences` | section -> year, campus, class; room -> campus |
| People / HR identity | `staff`, `employee_status_history`, `qualifications`, `departments`, `designations` | staff -> school; assignments -> staff/campus |
| Students / families | `students`, `student_private_details`, `guardian_student_links`, `student_account_links`, `student_status_history` | child and guardian must be verified in same school |
| Admissions / enrollment | `admission_applications`, `admission_stage_events`, `enrollments`, `enrollment_transitions`, `student_rolls` | enrollment -> student + section offering + academic year |
| Curriculum / teaching | `subjects`, `subject_offerings`, `student_subject_choices`, `teacher_assignments` | offering -> year/class; teaching -> staff/section/subject |
| Calendar / timetable | `calendar_events`, `periods`, `timetable_versions`, `timetable_slots` | slots -> school/year/section/room/teacher; conflict exclusion |
| Attendance | `attendance_sessions`, `attendance_marks`, `attendance_corrections`, `attendance_capture_events` | session -> section/year; mark -> enrollment/eligible student |
| Learning | `assignments`, `submissions`, `question_banks`, `test_attempts`, `feedback` | recipients -> current/historical enrollment and assignments |
| Exams / results | `assessment_definitions`, `mark_entries`, `result_publications`, `result_revisions` | marks -> student subject/year, verified evaluator and publish state |
| Finance | `fee_rules`, `student_charges`, `invoices`, `invoice_lines`, `payments`, `payment_allocations`, `refunds` | invoice/payment/student all in same school; immutable audit/ledger |
| Payroll / leave | `employee_contracts`, `leave_requests`, `payroll_runs`, `payroll_lines` | payroll -> employed staff, school and accounting period |
| Optional services | `library_loans`, `transport_routes`, `transport_assignments`, `hostel_allocations`, `medical_incidents` | referenced student/staff and local campus; medical separately sensitive |
| Files / communications | `file_objects`, `file_purpose_links`, `notifications`, `notification_deliveries` | purpose + owner row + recipient each school-consistent |

The catalog is a **mapping target**, not evidence that each feature exists in source code or has passed migration. Freeze exact columns one domain at a time; retain EduSync's historical integrity, approval, shared-family, private-storage, and audit expectations where applicable, but rebuild their school-local keys.

### Examples of typed relationships

- A guardian with an active role in School A does not see every student in A. Parent visibility requires a currently valid, approved `guardian_student_links` or accepted FAMILY relationship **in the same school**, respecting effective dates and revoked access.
- A Student account is bound to its own student row in that school. A Teacher may see or mark only eligible sections/subjects/dates for current or authorized historical assignments. Role name `teacher` alone is insufficient.
- A user belongs to School A and B independently; revoking School A membership must immediately deny A despite their continuing B membership, including cached and AI/export paths.
- A School Owner's access to subscriptions and school configuration does **not** imply reading student medical files or everyone’s payroll details.

## 5. Illustrative structural SQL (do not run directly)

The following demonstrates the **composite FK requirement** and is intentionally incomplete: migrations must add schema creation, privileges, policy functions, trigger ownership and full constraints.

```sql
-- SHAPE ONLY; not a complete/approved migration.
create table app.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references app.schools(id),
  display_name text not null,
  admission_no text not null,
  created_at timestamptz not null default now(),
  unique (school_id, id),
  unique (school_id, admission_no)
);

create table app.enrollments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references app.schools(id),
  student_id uuid not null,
  section_offering_id uuid not null,
  enrolled_on date not null,
  unique (school_id, id),
  foreign key (school_id, student_id)
    references app.students (school_id, id) on delete restrict,
  foreign key (school_id, section_offering_id)
    references app.section_offerings (school_id, id) on delete restrict
);
-- app.section_offerings must be created first with UNIQUE(school_id,id).
-- Other domain ancestry/interval constraints and audit are omitted.
```

**Illustrative indexes:** `students(school_id, admission_no)` unique; `enrollments(school_id, student_id, enrolled_on)`; `school_memberships(auth_user_id, school_id, state)`; child tables `(school_id, foreign_key)`; permission assignment lookup `(school_id, membership_id, role_id)`; history `(school_id, aggregate_id, effective_at DESC)`. Verify plans using representative mixed-tenant load; do not add indexes without workloads.

## 6. Authorization and RLS contract

### 6.1 Effective permission decision

For *every* tenant read/write, evaluate:

1. Valid Auth session (`auth.uid()` is not null); no implicit anonymous tenant access.
2. Current, non-suspended School membership for `row.school_id`, with effective interval.
3. Active role assignment and a grant for the **requested resource/action**.
4. Scope binding tied to **the same role-assignment/grant**. Apply school **AND** campus **AND** class/section/subject/assignment/OWN as required by the operation. Unknown scope kind => deny.
5. Typed domain relationship (guardian-child, employee-self, assigned teacher, enrollment, workflow reviewer) and permitted lifecycle state.
6. Exact selected columns, subscription entitlement where relevant, and applicable review/approval workflow.
7. For mutation: server-resolved actor and school, expected version, authorized changed fields, idempotency, audit and event in one transaction.

**Live database grants are authoritative.** Avoid mutable `user_metadata`, client role lists and long-lived JWT role claims as the decision source; a fresh token may authenticate but still carry stale roles. Revocation applies on subsequent database checks. For sensitive commands, also consider token/session revocation and short token lifetimes.

### 6.2 Policy shape, not deployable SQL

```sql
-- Policy shape only; private.can_read_student is NOT implemented yet.
alter table app.students enable row level security;

create policy student_scoped_select
  on app.students for select to authenticated
  using (
    (select private.can_read_student(school_id, id))
  );

-- Approved mutation APIs should be narrow RPC/transactional commands.
-- Do not enable broad INSERT/UPDATE/DELETE policies by default.
```

`private.can_read_student(school_id, id)` must derive the actor from `auth.uid()` **inside the trusted evaluator**, resolve active membership and current fine-grained grants, then verify teacher/student/guardian scope. It must not accept a caller-supplied actor ID or authorize by `school_id` alone. The helper must be audited for RLS recursion, ownership and leak channels.

If a restricted *direct* update is approved for a low-risk table, it must use **both** `USING` (old row visible/authorized) and `WITH CHECK` (new row remains authorized), require a compatible `SELECT` policy, and independently prohibit `school_id` changes. For sensitive history/finance/results/roles, prefer protected command functions with no direct client write grants.

### 6.3 Policy / API exposure matrix (proposed)

| Data group | Anonymous | Authenticated safe read | Write path |
|---|---|---|---|
| School directory / public branding | Deny except separately approved minimal discovery endpoint | Active school membership, field-limited | Owner/admin protected command |
| Membership/roles/grants | Deny | Self safe projection; authorized admin scoped projection | Server command, delegation ceiling, no self-escalation |
| Student records | Deny | Approved school + teacher, student-self or guardian-child relationship; field restrictions | Domain command + audit/approval |
| Employee and payroll records | Deny | Own or explicitly scoped HR/accountant role; salary extra-restricted | HR/payroll command, finalization/version checks |
| Attendance, grades and exams | Deny | Permitted assignment, own record, verified child or controller role | Typed command, lock/approval/history |
| Financial records and evidence | Deny | Explicit finance permission or own approved invoice view | Ledger/payment command only; never evidence = settled payment |
| Notifications and files | Deny | Exact recipient/domain entitlement and current school membership | Purpose-specific server workflow, signed/short access |
| Plans, billing events, platform audit | Deny | Private operator-only service or restricted school billing projection | Verified backend/webhook, never Flutter direct mutation |
| Aggregated cross-school analytics | Deny | Aggregated/privacy-reviewed platform endpoint only | Backend with logged access and result limits |

**RLS pitfalls to test explicitly:** `TO authenticated` by itself is not tenant authorization; view owner may bypass RLS unless `security_invoker` is used; service roles and table owners can bypass normal policies; `UPDATE` needs `SELECT`; new tables need explicit Data API grants if intentionally exposed. Never add a broad `USING (true)` policy to fix an empty result.

### 6.4 Trusted helper and stored procedure hardening

- Default to `SECURITY INVOKER`. If a narrow `SECURITY DEFINER` evaluator is unavoidable to avoid membership-policy recursion, put it in an unexposed schema, use a dedicated least-privilege owner, `SET search_path = ''`, schema-qualify objects, and derive the caller from `auth.uid()`.
- Revoke default `PUBLIC` function `EXECUTE`; grant only the exact role/function signature required. Avoid generic target-table names, arbitrary JSON patches or untrusted SQL execution.
- Evaluate current DB rows within command transactions; protect high-risk workflows from concurrent revocation, replay and double approval using row locks and expected versions.
- Document service/secret key custody and minimum worker routes. **Never** ship the service/secret key in Flutter, device logs or public CI artifacts.
- Where using Postgres 15+ views, explicitly mark `security_invoker = true`; confirm project DB version before migration. Audit every exported RPC and view for columns that RLS alone cannot hide.
- Enable RLS on **every** table in exposed schemas and prefer defense-in-depth RLS for canonical tables. Test unknown `school_id`, cross-school FK and mass assignment attempts.

## 7. Tenant isolation beyond PostgreSQL SELECT

- **Storage:** private school namespace/object metadata; object keys are not authority; signed URLs minted only after checking row, school, purpose and entitlement. If using Supabase Storage, test `storage.objects` policies for read, upload and upsert; never rely on path prefix alone.
- **Realtime:** school-scoped channels and subscriptions; validate row authorization on each event path; unsubscribe/clear caches when the active school or membership changes.
- **Flutter:** selected `school_id` is *routing context*, not proof; clear provider state, local search, caches and queued requests on switching schools. Separate encrypted offline cache namespaces by authenticated user and school; deny outdated writes on sync.
- **Reports/AI:** apply the **same** checked read service before searching/embedding/prompt context/export. Do not build global embeddings containing student PII without per-school partitioning and permission-aware retrieval.
- **Operations:** rate limiting, per-school quotas, tenant-leading indexes and noisy-neighbor monitoring. Single-project PITR affects all schools; define selective school export/import and test restoration.
- **Privacy:** restrict payroll/medical/identity information at column/projection level, not merely with broad row grants. Audit support access and sensitive exports without copying secret fields into logs.

## 8. EduSync migration path (new implementation required)

1. **Inventory** legacy schema, actual applied versions, project IDs, storage buckets, Auth users and requirements; do not assume draft files were deployed.
2. **Approve new schema** including `school_id`, roles/scopes and controlled server commands; implement only in disposable/local target first.
3. **Map identities:** create stable `legacy_source_project + legacy_primary_key → new_school_id + new_primary_key` maps. Reconcile emails and people with membership separation. Never copy password hashes or assume Auth IDs can be directly consolidated.
4. **Transform each school's data:** stamp verified tenant ID, map every parent/child reference, retain history and immutable financial/event evidence; reject missing or mismatched anchors.
5. **Migrate files:** move private bytes through approved adapters; verify metadata/object linkage, checksums, retention and download authorization.
6. **Verify:** counts and totals by school, money conservation, source/target lineage, unexpected nulls, duplicate business keys, hash samples, review/receipt consistency and parent/student entitlements.
7. **Cut over school-by-school:** dry run, write freeze or approved synchronization window, migration log, new user sign-in/invite, tenant A/B test, acceptance, reversible routing decision and rollback plan.
8. **Archive legacy:** keep source read-only under an approved retention period; never decommission from one successful dashboard screen.

Migration SQL must be newly generated and reviewed under `supabase/migrations/`; do **not** edit/copy the source repository's historically validated Foundation migrations as if they already implement multi-school tenancy.

## 9. Minimum negative-security acceptance matrix

Use fixtures **School A**, **School B**, **user A**, **user B**, **user in both schools**, **suspended user**, **parent with and without child link**, **teacher with and without assignment**, **School Owner** and **Platform Operator**.

| Case | Required result |
|---|---|
| A-only user fetches B student, payroll, invoice, search, export or file | No rows / deny, no metadata leak |
| User changes request `school_id` A → B or forges FK to B record | Deny and/or composite FK rejection |
| Multi-school user selects B while referencing A child | No permission crossover |
| Owner of A tries to assign B role or inspect B school settings | Deny |
| Staff role and guardian role on one user, different scopes | Only exact authorized union of grants, no scope mixing |
| Parent relationship revoked or unverified | Child data inaccessible on next server read |
| Teacher assignment expired, year closed or scope revoked | Mutation denied; historical reads separately checked |
| Suspended membership with still-valid JWT | Current DB entitlement denies access |
| Operator with no active support grant requests raw school data | Deny; allowed aggregate endpoint emits audited limited output |
| Unauthorized view/RPC/Realtime/object URL/AI response | Same deny result as canonical domain read |
| Parallel approval, fee allocation or attendance correction replay | Single auditable outcome, no duplicate financial/history effects |

**Acceptance gate:** green anonymous/same-school/different-school/dual-school/role-revocation tests, verified grants and view ownership, Postgres RLS/ACL audit, representative query plans and repeatable local clean install. No tenant import, domain production data or "RLS complete" status before these pass.

## 10. Decisions still requiring approval

| Decision | Initial recommendation | Status |
|---|---|---|
| Organization owner scope | Platform operator, server-only audited support; no wildcard tenant RLS | [Proposed] |
| Customer organizations / multi-school billing entity | Defer separate grouping table until purchase model requires it; school is primary tenant | [Open] |
| Principal models | Individual accounts plus optional shared FAMILY Auth principal, no implicit staff roles on FAMILY | [Proposed] |
| Permission evaluator location | DB-live, non-recursive typed resolver, no JWT role authority | [Proposed] |
| Tenant key constraints | Mandatory immutable school key + composite FKs everywhere | [Proposed] |
| API surface | Private canonical tables + explicit scoped API views/commands | [Proposed] |
| Direct writes | Protected commands for sensitive and historical domains | [Proposed] |
| Billing and storage provider | Adapters, server-held secrets, school capabilities; select later | [Open] |
| Data migration | Per-school staged ETL with Auth remap and reversible cutover | [Proposed] |

**Source references:** [EduSync feature catalog](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/requirements/FEATURE_CATALOG_AND_STATUS.md) · [Foundation entity map](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/database/02_foundation_entity_map.md) · [EduSync RLS matrix](https://github.com/yunusyosaf399/edusync_saas_school_app/blob/main/docs/security/03_foundation_rls_matrix.md) · [Supabase RLS guide](https://supabase.com/docs/guides/database/postgres/row-level-security) · [Supabase API security](https://supabase.com/docs/guides/api/securing-your-api) · [2026 Supabase changelog](https://supabase.com/changelog?types=breaking-change).
