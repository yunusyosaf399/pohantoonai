# Supabase — Pohantoon AI

This folder is the **portable database source of truth**. It is intended to be reused later with a different Supabase organization or project. The immediate target is **one** dedicated development project named `pohantoonai` (deployed in `YouPro School`, project ref `umlzqlbakfwzgadafhyy`); no school-per-project architecture.

## Folder organization

| Path | Role |
|---|---|
| `schema/01_platform_onboarding.sql` | Deployed Module 01 private SaaS organization, plans, school onboarding, subscription request and review records |
| `schema/02_secure_existing_rls_trigger.sql` | Deployed hardening of an existing public event-trigger function's execute privileges |
| `seed/01_demo_platform.sql` | Idempotent **fake/demo-only** seed with plans and a sample application |
| `tests/01_platform_smoke.sql` | Read-only smoke checks after deployment |
| `migrations/` | Official timestamped migrations created with `supabase migration new ...` once Supabase CLI is available |

**Never store keys, passwords, connection strings, privileged tokens or real student data in Git.** `platform` is intentionally not a client-exposed schema. All its tables have RLS enabled and no `anon`/`authenticated` table grants; Flutter currently uses a mock repository.

## Deployment workflow

1. **Done:** Use the user-created project `pohantoonai` (`umlzqlbakfwzgadafhyy`) in the `YouPro School` organization.
2. **Done:** Apply `schema/01_platform_onboarding.sql` in a tracked Supabase migration (`platform_onboarding_foundation`).
3. **Done:** Apply `seed/01_demo_platform.sql` on this disposable test database; it creates synthetic `example.invalid` records, not real payments.
4. **Done:** Verify 12/12 RLS, zero public client data access, 3 plans, and sample request; apply `schema/02_secure_existing_rls_trigger.sql` as a second tracked migration (`secure_existing_rls_trigger_permissions`).
5. **Next:** Add operator authentication and protected APIs before wiring Flutter to live records.
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

- SQL and seed files committed to GitHub; Module 01 and privilege-hardening migrations applied successfully to the test Supabase project.
- Verified 12 platform tables with RLS and no client read/write grants. Sample school application and 3 plans exist.
- Supabase security linter reports 12 INFO policy-free private tables (intentional). No remaining exposed privileged helper warnings after privilege revocation.
- Flutter code/tests have not passed a confirmed CI run; live API integration is still pending.


## Module 01.1 — First-screen Auth and appearance (2026-11-10)

- [Source SQL](schema/03_account_identity_preferences.sql) deployed as version `20261110174324`, `account_profiles_theme_preferences_rls`.
- `public.user_profiles` and `public.user_preferences` are RLS-protected, self-service authenticated records, **not** platform or school roles. `auth.users` remains managed by Supabase.
- [Edge function](functions/account-bootstrap/index.ts) `account-bootstrap` deployed ACTIVE v1, `verify_jwt=true`. Caller token revalidated with Auth; no service-role use or privileged memberships granted.
- [Smoke test](tests/03_account_auth_smoke.sql) checks ownership-policy inventory, anonymized grants and theme-mode constraint.
- [Provider configuration](../docs/database/module_01_account_auth.md) requires Google OAuth client ID/secret, email delivery settings and callback allowlist via Dashboard; cannot be performed by currently available Supabase connector calls.
- `supabase_flutter: 2.18.3` and `shared_preferences: 2.5.5` pinned in pubspec; **lockfile regeneration and Flutter CI are outstanding**. Do not claim successful auth end-to-end without provider configuration.
- When moving to another Supabase organization, replay the reviewed schema scripts in recorded dependency order and create matching official timestamped CLI migrations; reconcile existing live migration history. **Do not blindly replay the same SQL under new migration names in the existing test project.**
