# Current Sprint — Module 01 Organization Control Panel

> **Sprint:** S01 (2026-11-10) · **Status:** [In Progress]  
> **Approved delivery method:** Commit portable SQL in `supabase/`, deploy changes to **one** dedicated Supabase development project as we proceed, and develop Flutter concurrently. The database must be isolated/private until authenticated RLS/ACL contracts are verified.
> **Project creation blocker:** user must choose connected Supabase organization: `YouPro School` or `SchoolAgent`. Neither currently has a project named `pohantoonai`.

## Scope and source

- [Catalog](../architecture/table_catalog.md): 383 **planning candidates**; not a bulk migration plan.
- [Module 01 implementation contract](../database/module_01_organization.md).
- [Portable SQL](../../supabase/schema/01_platform_onboarding.sql), [synthetic seed](../../supabase/seed/01_demo_platform.sql) and [SQL smoke test](../../supabase/tests/01_platform_smoke.sql).
- [Flutter console](../../lib/features/organization/presentation/organization_control_panel.dart), [models](../../lib/features/organization/domain/organization_models.dart), [mock](../../lib/features/organization/data/mock_organization_repository.dart), [widget tests](../../test/widget_test.dart).

## Sprint milestones

| ID | Deliverable | Status | Evidence / blocker |
|---|---|---|---|
| S01-01 | Full table catalog by domain | [Completed — planning] | 383 names / 30 groups |
| S01-02 | Sprint + session tracking | [Completed] | This file and `independent_tasks.md` |
| S01-03 | Module 01 private base-schema SQL | [Completed — source only] | 12 `platform` tables under `supabase/schema/` |
| S01-04 | Synthetic demo seed and SQL verification | [Completed — source only] | No real users, billing or payments |
| S01-05 | Flutter organization panel mock shell | [Completed — source only] | Overview, plans, school requests, form, mobile/desktop navigation |
| S01-06 | Flutter widget tests and CI job | [In Progress] | Source tests committed; [GitHub run #1](https://github.com/yunusyosaf399/pohantoonai/actions/runs/42839541478) failed with no job steps/log; code not yet validated |
| S01-07 | Select Supabase organization | [Blocked — Owner Input] | Choose `YouPro School` or `SchoolAgent` |
| S01-08 | Create **one** development project `pohantoonai` | [Blocked — S01-07] | Project region recommended `ap-south-1` for test use, subject to preference and cost handling |
| S01-09 | Deploy Module 01 DDL and fake seed | [Blocked — S01-08] | Verify 12 tables and 3 test plans |
| S01-10 | Run SQL checks and security advisors | [Blocked — S01-09] | Validate no anonymous access and cross-organization references |
| S01-11 | Operator authentication and reviewed onboarding API | [Not Started] | Never publish raw `platform` tables |
| S01-12 | Wire Flutter to **verified** live organization API | [Blocked — S01-11] | No service/secret key in client |
| S01-13 | Module 02: verified school provisioning and school profile | [Not Started] | Begins after subscription/trial authorization and protected provisioning contract |

## Next user-visible vertical flow

```text
SaaS Control Panel
  ├─ Overview and submitted school applications (Flutter MOCK implemented)
  ├─ Test subscription plans (Flutter MOCK + private SQL prepared)
  ├─ School application form (Flutter MOCK implemented)
  ├─ Verified plan selection/payment or trial (not implemented)
  ├─ Operator review and approve (structure prepared; service not implemented)
  └─ Provision a real school tenant (Module 02; not implemented)
```

## Parallel work allocation

- **DB stream:** Module 01 SQL is in the repo; once Supabase organization is selected, deploy to one test project, seed demo rows, run checks, add protected server endpoints.
- **Flutter stream:** Can improve forms, responsive layouts, state tests and organization UI using the in-memory repository while backend work proceeds. Never expose unguarded private tables merely to make the UI work.
- **Integrator:** Sole owner for shared `lib/main.dart`, workflow/build graph, official migrations, deployment state and test evidence. Merge other feature modules only when paths are disjoint.

## Testing and acceptance

- **Schema deployment:** [Not Started]; no live Supabase project selected.
- **Seed execution:** [Not Started]; demo SQL prepared.
- **RLS/ACL live verification:** [Not Started]; protective DDL written only.
- **Flutter unit/widget test:** [Unverified]; local Flutter SDK unavailable in execution environment. GitHub Actions run #1 failed before steps; failure cause unconfirmed.
- **Production:** not authorized; never seed sample records into production.

## Decisions requested

- [ ] **ORG-01** Select the development Supabase organization: `YouPro School` or `SchoolAgent`.
- [ ] **ORG-02** Accept automatic project region `ap-south-1` for testing, or select a different supported region.
- [ ] **ARCH-01** Confirm catalog table naming changes and Module 01 onboarding information.
- [ ] **ARCH-02** Confirm future provider for real billing; current flows are simulation only.

**Last tracking update:** 2026-11-10 after committing Module 01 Flutter, private schema, seed and test sources; deployment/test acceptance remains open.
