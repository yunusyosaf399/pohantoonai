# Current Sprint — Catalog Approval and Parallel Development Contracts

> **Sprint:** S01 · **Date:** 2026-11-10 · **Status:** [In Progress] · **No production deployment authorized**.
> **Canonical progress:** [master roadmap](master_roadmap.md) · **Catalog pending owner approval:** [table catalog](../architecture/table_catalog.md) · **Session tasks:** [independent tasks](independent_tasks.md).

## Sprint objective

Secure agreement on the 383-table **candidate** inventory (96 P0, 203 P1, 84 P2), without approving all for immediate implementation. In parallel, finalize the first Flutter mock-data contracts and a first *isolated* database base-table design batch. The tracks are independent until the reviewed API integration gate.

**Important safety boundary:** schema-first is welcome, but **raw tenant tables remain unexposed to clients** until Auth, appropriate RLS and tenant isolation checks exist. Flutter uses fixtures/mocks, never a shared unprotected Supabase project. The first physical DDL can contain primary keys and immutable tenant keys; cross-domain FKs, functions, error codes and domain policies can be specified in subsequent gated tasks, **before any shared/live data writes**.

## Sprint board

| Task | Track | Scope / deliverable | Dependency | Status | Allowed changes |
|---|---|---|---|---|---|
| S01-01 | PM | Publish complete candidate table inventory | Source catalog | [Completed] | `docs/architecture/table_catalog.md` |
| S01-02 | PM | Publish this sprint and independent-session registry | Roadmap | [Completed] | `docs/tracking/current_sprint.md`, `independent_tasks.md` |
| S01-03 | Owner | Approve / rename / merge / defer catalog tables | S01-01 | [Awaiting Approval] | Owner decision; no auto SQL |
| S01-04 | DB | Record approved P0 first batch: schools + school_profiles + campuses + academic_years + identities/memberships | S01-03 | [Blocked] | New `docs/database/first_batch_schema.md` |
| S01-05 | DB | Define base fields and types (no policies/functions yet) | S01-04 | [Blocked] | Same DB design document, single session |
| S01-06 | DB | Draft isolated local DDL migration; verify catalog, PK and tenant keys | S01-05 | [Blocked] | Integrator-owned `supabase/migrations/` |
| S01-07 | Flutter | Define feature-first folder layout and mock interface contract | None | [Not Started] | `docs/flutter/folder_structure.md` |
| S01-08 | Flutter | Select state management and outline active-school switching | None | [Not Started] | `docs/flutter/state_management.md` |
| S01-09 | Flutter | Prepare mock-only shell/navigation design and fixture data plans | S01-07–08 | [Not Started] | `docs/flutter/mock_contracts.md` |
| S01-10 | Security gate | Specify testable A/B school read/write isolation and safe Data API exposure | DB batch draft | [Not Started] | `docs/security/tenant_isolation.md` |
| S01-11 | Integration | Swap Flutter mocks to verified authenticated APIs | S01-06 + S01-10 passing tests | [Blocked] | Shared app integration; serial |

## Recommended first vertical demo

1. School selection and onboarding preview (Flutter mocked).
2. School profile, campuses and academic years (mocked list/create/edit UI).
3. School owner/staff role switch and teacher/parent/student navigation previews (**UI only**, not real authorization).
4. Student profile, family link, enrollment and school-year preview.
5. Teacher attendance and parent attendance view.
6. After safe backend APIs and tenant A/B tests pass, substitute real Supabase repositories screen by screen.

This is intentionally **not** a claim of working database authorization.

## Approval decisions needed

- [ ] **DEC-01** Accept catalog structure or request table changes.
- [ ] **DEC-02** Confirm P0 first-batch subset, not all 96 P0 tables at once.
- [ ] **DEC-03** Confirm whether parent shared-family login remains a product feature.
- [ ] **DEC-04** Confirm initial Flutter targets (source supports Android, Windows, Web; target scaffold inspected).
- [ ] **DEC-05** Confirm mock-only Flutter development while DB is unexposed.
- [ ] **DEC-06** Approve switching from mock to real backend only after explicit RLS and tenant tests.

## Definition of done

A sprint task is complete only when its committed artifact is inspected and linked. DB migrations require a disposable local apply + schema assertions; Flutter work requires code analysis/widget tests once code begins. Real cross-school integration additionally requires documented negative-isolation tests and reviewed RLS and grants.

## Sprint progress

| Category | Completed | Total | Status |
|---|---:|---:|---|
| Sprint work items | 2 | 11 | 18% |
| Catalog approval decisions | 0 | 6 | Pending |
| Target SQL migrations | 0 | TBD | Not started |
| Flutter production feature modules | 0 | TBD | Not started |

## Change log

- **2026-11-10:** Created table catalog and sprint/session task registry. No SQL or Flutter source changes performed. Owner approval is pending.
