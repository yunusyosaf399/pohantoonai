# Pohantoon AI — Multi-Tenant School Management SaaS

A single Flutter codebase and a **single Supabase project serving multiple independent schools**, with school-scoped data and a SaaS Organization Control Panel.

## Current implementation — Module 01

**Development only.** The Flutter app opens a responsive Organization Control Panel with mock plans, a school-application list, and a demo onboarding form. It does **not** yet connect to a live database, authenticate operators, collect payments or create schools.

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

The Flutter SDK is required locally. An experimental GitHub Actions workflow is included for analysis and widget tests; check its run status instead of assuming it passed.

## Supabase database as portable code

All SQL lives in [`supabase/`](supabase/README.md):

- [Module 01 schema](supabase/schema/01_platform_onboarding.sql) — 12 private SaaS/onboarding tables, tenant-aware organization foreign keys, closed client access
- [Synthetic development seed](supabase/seed/01_demo_platform.sql) — 3 demo plans and 1 entirely fictional school request
- [Read-only SQL smoke checks](supabase/tests/01_platform_smoke.sql)

We will deploy to exactly **one** development Supabase project called `pohantoonai` once the project owner selects a connected Supabase organization. No other school-specific projects are planned. Official migration history must be reconciled when Supabase CLI is configured, allowing the same source-controlled schema to be deployed to a different account later.

## Architecture and progress

- [Complete candidate table catalog](docs/architecture/table_catalog.md) — 383 proposed tables (not all created)
- [Module 01 design and workflow](docs/database/module_01_organization.md)
- [Master roadmap](docs/tracking/master_roadmap.md)
- [Current sprint](docs/tracking/current_sprint.md)
- [Independent work sessions](docs/tracking/independent_tasks.md)
- [Database/RLS architecture](docs/architecture/database_schema.md)

## Delivery sequence

1. SaaS organization plans, interest and school onboarding.
2. Subscription/trial approval, organization operator review and protected school provisioning.
3. School profile, campuses, academic years and school-owner invitations.
4. Admissions/students/families, enrollments, teachers and academic modules.
5. Attendance, fees/finance, HR/payroll, documents and optional modules.

**Security boundary:** Flutter uses mock repositories until authenticated application APIs and tenant isolation have been tested. A private schema without public grants and RLS enabled is the baseline; production-grade functions and scoped access are added before any live client access. No service-role credentials are stored in Flutter or Git.
