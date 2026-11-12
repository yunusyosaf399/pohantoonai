# Product requirements and decision register — Pohantoon AI

> **Last reviewed:** 2026-11-12 · **Scope:** requirements documentation only; not an implementation or deployment sign-off.

## Start here

1. **[Pohantoon AI product requirements and decisions](POHANTOON_PRODUCT_REQUIREMENTS_AND_DECISIONS.md)** — the working product-goals reference. Contains 40 module sections (A–AN), the original 100 numbered Q&A, later product/security approvals, and NEW-001–NEW-082 with their current interpretation.
2. **[EduSync original requirements and approvals — unchanged archive](EDUSYNC_ORIGINAL_REQUIREMENTS_AND_DECISIONS_2026-11-12.md)** — exact supplied historical markdown; preserves evidence, wording, dates and original uncertainty.
3. **[Single-project database architecture](../architecture/database_schema.md)** — Pohantoon architectural draft: shared database, school-owned `school_id`, cross-tenant constraints, membership/RLS and API boundaries.
4. **[Table catalog](../architecture/table_catalog.md)** and **[migration roadmap](../tracking/master_roadmap.md)** — planning candidates, implementation sequence and acceptance criteria. Candidate catalog is not automatically approved.

## How to read statuses

| Status | Meaning |
|---|---|
| HISTORICAL / CONFIRMED | Previously approved in EduSync product discussions; retains original meaning but does not prove deployment in Pohantoon. |
| SELECTED FOR POHANTOON | Product owner chose the shared Supabase project/database direction on 12 Nov 2026. Detailed DB schema, tenant isolation and migration tests need separate sign-off. |
| PROPOSED / OPEN | Question or policy remains to be decided; don't silently implement one suggested option. |
| IMPLEMENTED / TESTED | Use only when a current Pohantoon module document provides real implementation and verification evidence. |

## Non-negotiable tenant rule

**One Supabase project/database holds all schools, not one project or PostgreSQL schema per school.** School-owned operational tables are school-scoped using an immutable `school_id` and matching composite tenant references. Supabase Auth identities may be related to several schools, but every school-data read/write must use verified current membership, permission and scope. Pre-provisioning applicant records, the school-root entity and platform-controlled global objects are separately documented exceptions.

**Example:** A Grade 5 student in School A and a Grade 5 student in School B can live in the same student table; their `school_id` differs. A teacher's School A role never makes School B data visible. School A can still have several campuses, governed by scoped grants.

## Current caveat

The in-repository development dashboard/demo access is **not** a paid subscription, accepted school invoice, or active production tenant. See [Module 02.2](../database/module_02_2_dashboard_auth_profiles.md). Do not treat source-code commits, EduSync design reviews or planned tests as Pohantoon runtime acceptance.

## Making future decisions

For each new question, capture: decision ID; precise selected option; actor and scope; allowed/denied behavior; cross-tenant consequences; related tables, RLS, RPCs and tests; approver and date; status (PROPOSED → APPROVED → IMPLEMENTED → TESTED → RELEASED). Only explicitly approved answers change the baseline.
