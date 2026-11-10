# Independent Tasks — Parallel ChatGPT Session Registry

> **Status:** [Open] · **Date:** 2026-11-10  
> **Source of truth:** [master roadmap](master_roadmap.md) · [current sprint](current_sprint.md) · [candidate table catalog](../architecture/table_catalog.md).

## Parallel execution rules

**Current allowed strategy: two tracks.** Track DB designs tables and later tests **without changing the exposed client database yet**. Track Flutter builds approved UI scaffolding and feature modules against local mock repositories, **not against unsecured live tables**. Separate sessions are safe only with **exclusive file ownership** and a fixed contract.

- **No shared-file concurrent writes:** `pubspec.yaml`, `lib/main.dart`, `supabase/config.toml`, `supabase/migrations/*.sql`, permission catalogs and all three tracking files are owned by a single integrator.
- **A task is only truly independent if** it writes solely to its allowed path, reads the current `main` commit, does not change shared API names and does not use the same mutable DB as another session.
- **One branch or worktree per session:** `docs/<task-id>` or `feature/<task-id>`, then PR. GitHub may otherwise silently serialize commits on `main`, but independent commits to exclusive files are still easier to review.
- **Do not create target SQL until the owner approves candidate names.** No direct Flutter-to-unsecured Supabase reads, no service-role key in a client, and no imported sensitive data in mocks.
- **No contract-breaking changes while a session runs:** Table-name or API changes must be published first; impacted sessions pause and rebase.
- An integrator alone updates shared roadmap/sprint/registry states after review. New task code does not automatically earn a checkmark.

## Available immediately — exclusive document paths

| ID | Task | Owns exactly | Dependencies | Status |
|---|---|---|---|---|
| PAR-01 | Flutter feature-first folder structure and mock repository interface | `docs/flutter/folder_structure.md` | None | [Not Started] |
| PAR-02 | State management comparison, active-school cache invalidation and test approach | `docs/flutter/state_management.md` | None | [Not Started] |
| PAR-03 | School Owner versus Organization Owner permissions *inventory only* | `docs/roles/org_owner.md` | None | [Not Started] |
| PAR-04 | Principal, Admin, Teacher, Student, Parent, Accountant and HR responsibilities | `docs/roles/school_roles.md` | None | [Not Started] |
| PAR-05 | Error-handling conventions **documentation** without handlers or DB functions | `docs/errors/error_handling_standards.md` | None | [Not Started] |
| PAR-06 | Single-project vs legacy deployment comparison and migration implications | `docs/architecture/single_tenant_vs_multitenant.md` | None | [Not Started] |

**These six tasks can run in separate ChatGPT sessions now.** No two tasks own the same file. They can read `table_catalog.md` but not approve or edit it.

## Gated independent tasks — unlock after specified decisions

| ID | Task | Owns exactly | Gate | Status |
|---|---|---|---|---|
| PAR-07 | Flutter mock contracts & test fixtures specification | `docs/flutter/mock_contracts.md` | PAR-01/02 reviewed | [Blocked] |
| PAR-08 | School setup Flutter screen components | `lib/features/school_setup/**`, `test/features/school_setup/**` | Integrator initializes shared Flutter shell; mock contract frozen | [Blocked] |
| PAR-09 | Student/guardian Flutter views | `lib/features/students/**`, `test/features/students/**` | Same frozen contract and source mock fixtures | [Blocked] |
| PAR-10 | Employee/teacher Flutter views | `lib/features/staff/**`, `test/features/staff/**` | Same frozen contract and separate feature paths | [Blocked] |
| PAR-11 | Fees/invoice Flutter views | `lib/features/finance/**`, `test/features/finance/**` | Same frozen contract; no live data | [Blocked] |
| PAR-12 | First base-table column/type proposal | `docs/database/first_batch_schema.md` | Owner approved table catalog and base batch | [Blocked] |
| PAR-13 | Academic table module **design only** | `docs/database/modules/academics.md` | Core names/tenant key convention frozen | [Blocked] |
| PAR-14 | HR table module **design only** | `docs/database/modules/staff.md` | Core names/tenant key convention frozen | [Blocked] |
| PAR-15 | Finance table module **design only** | `docs/database/modules/finance.md` | Core names/tenant key convention frozen | [Blocked] |
| PAR-16 | Academic Flutter mock screens | `lib/features/academics/**`, `test/features/academics/**` | Shared mock contract stable | [Blocked] |

Different *design* documents can be drafted in parallel once common identity/tenant names are fixed. **Actual ordered SQL migrations remain serial**, as do changes to shared Flutter routing/DI and integration with backend auth.

## Integrator-owned tasks (not standalone)

| Task | Exclusive owner / path | Why serial |
|---|---|---|
| Catalog owner-approval revision | `docs/architecture/table_catalog.md` | Must preserve one authoritative list |
| Flutter app root initialization | `lib/main.dart`, `lib/app/**`, `pubspec.yaml` | Shared packages/routing/build graph |
| Tenant foundation DDL | `supabase/migrations/**` | Ordered deployment, tenant key and schema ownership |
| RLS, privileges, storage policy and function design | `docs/security/**` and ordered migration files | One trust boundary; no policy races |
| Live API integration | `lib/core/**`, shared DI/router, `api` schema | Multiple modules depend on this interface |
| Releases, ETL, production deployment | shared environment, migrations and exports | Global single-project impact |
| Tracker status updates | `docs/tracking/**` | One completion source of truth |

## Session handoff template

```text
Task ID:
Base target commit:
Approved catalog version and expected API contract:
Allowed file/directory paths:
Disallowed shared paths:
What was created:
Validation commands + results:
Open questions and security implications:
Commit / pull request:
Status: [Not Started | In Progress | Blocked | Completed]
```

## Merge and acceptance sequence

1. Claim a row and record branch/base commit before work.
2. Modify only assigned files; do not modify source EduSync or production Supabase.
3. Verify document links, format and local tests; commit the work.
4. Integrator inspects changed paths, checks stale contract names and merges.
5. Integrator updates this registry, sprint queue and master roadmap **after** acceptance.

**Approved parallelism is about disjoint change sets, not about sharing an unsecured database.** Safe mock UI work is independent of later schema migrations; live Supabase wiring is explicitly gated.
