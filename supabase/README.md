# Supabase — Pohantoon AI

This folder is the **portable database source of truth**. It is intended to be reused later with a different Supabase organization or project. The immediate target is **one** dedicated development project named `pohantoonai` (organization selection pending); no school-per-project architecture.

## Folder organization

| Path | Role |
|---|---|
| `schema/01_platform_onboarding.sql` | First module's SQL structure: SaaS organization, plans, school onboarding, subscription request and review records |
| `seed/01_demo_platform.sql` | Idempotent **fake/demo-only** seed with plans and a sample application |
| `tests/01_platform_smoke.sql` | Read-only smoke checks after deployment |
| `migrations/` | Official timestamped migrations created with `supabase migration new ...` once Supabase CLI is available |

**Never store keys, passwords, connection strings, privileged tokens or real student data in Git.** `platform` is intentionally not a client-exposed schema. All its tables have RLS enabled and no `anon`/`authenticated` table grants; Flutter currently uses a mock repository.

## Deployment workflow

1. Pick the connected Supabase **organization** to host the single `pohantoonai` development project. Creation can incur provider charges and may require cost confirmation.
2. Create that one project; confirm it is healthy. Keep a record of its project ref in a non-secret environment configuration.
3. Review the SQL, then deploy `schema/01_platform_onboarding.sql` in one tracked migration transaction.
4. Apply `seed/01_demo_platform.sql` only to the test database. It uses synthetic `example.invalid` contact details and creates **no real payments**.
5. Run `tests/01_platform_smoke.sql`, inspect table count, RLS, grants and seeded rows; record evidence in `docs/tracking/current_sprint.md`.
6. When Supabase CLI is available, use `supabase migration new platform_onboarding` and put the reviewed SQL into the generated timestamped file under `migrations/`; reconcile the test project's existing migration history before pushing elsewhere. The same SQL must never be applied twice with competing migration names.
7. Add authenticated read/write API endpoints **only after** implementing current membership, reviewed RLS, tenant isolation, transactional onboarding and verified subscription/payment status. No direct client access to these private tables.

## Development order

**Module 01:** SaaS Organization Control Panel (current) → **Module 02:** approved school provisioning, school profile/campuses/years → **Module 03:** identity/roles and student admissions → **Module 04:** enrollment and finance; continue domain by domain.

A school onboarding request is **not yet a school**. The request captures institution details, contact, location, academics, operations and a selected plan. It must later pass verified subscription or explicit authorized trial approval before a protected school-provisioning command creates `app.schools`. No test checkout here counts as real payment.

## Local developer commands (after CLI setup)

- Run `supabase --help` and `supabase migration --help` to confirm CLI syntax.
- Generate official migration files with `supabase migration new <name>`.
- The SQLite or browser mock UI is **not** a substitute for PostgreSQL constraint/RLS tests.
- Never run the demo seed on production; migrations and seeds are separate.

## Current evidence

- First SQL and seed files committed to GitHub.
- **Not deployed**, because two connected Supabase organizations are available and the owner has not selected one.
- SQL and Flutter were **not runtime-tested** in this session (Supabase CLI and Flutter SDK are unavailable in this execution environment). Live apply/verification is pending.
