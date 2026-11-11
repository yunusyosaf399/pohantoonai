# Current Sprint — Module 01 Organization Control Panel

> **Sprint:** S01 (2026-11-10) · **Status:** [In Progress]  
> **Approved delivery method:** Commit portable SQL in `supabase/`, deploy changes to **one** dedicated Supabase development project as we proceed, and develop Flutter concurrently. The database must be isolated/private until authenticated RLS/ACL contracts are verified.
> **Development project verified:** `pohantoonai` (`umlzqlbakfwzgadafhyy`), `YouPro School` organization, Tokyo `ap-northeast-2`, PostgreSQL 17, `ACTIVE_HEALTHY`. Module 01 SQL deployed and synthetic seed inserted on 2026-11-10.

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
| S01-07 | Select Supabase organization | [Completed] | User created `pohantoonai` in `YouPro School` |
| S01-08 | Create **one** development project `pohantoonai` | [Completed] | Existing user-created project `umlzqlbakfwzgadafhyy`, Tokyo, active healthy |
| S01-09 | Deploy Module 01 DDL and fake seed | [Completed] | `apply_migration(platform_onboarding_foundation)` succeeded; synthetic seed executed; 12 tables, 3 plans |
| S01-10 | Run SQL checks and security advisors | [Completed — initial checks] | RLS 12/12; anon/auth readable 0, writable 0; hardened `public.rls_auto_enable()`; security linter INFO 12 intentionally policy-free |
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

## Branding task — launcher and header (2026-11-10)

- [x] Register the three existing Pohantoon AI logo JPEGs under Flutter `assets:` in `pubspec.yaml`.
- [x] Replace the generic school icon in the Organization Control Panel header with the existing `app_icon.jpeg`.
- [x] Add `flutter_launcher_icons.yaml` for Windows, Android, iOS, Web and macOS, using the existing logo rather than inventing new branding.
- [x] Add a header logo widget assertion and setup instructions.
- [ ] **Pending on a Flutter-enabled machine:** `flutter pub get`, `dart run flutter_launcher_icons`, commit generated native icon resources plus updated `pubspec.lock`, and verify `flutter run -d windows`. The tracked Windows `.ico` has **not** been regenerated in GitHub yet.

## Parallel work allocation

- **DB stream:** Module 01 schema and synthetic seed are deployed to one user-created test project; continue with operator identity and protected API functions, and preserve every SQL change in `supabase/`.
- **Flutter stream:** Can improve forms, responsive layouts, state tests and organization UI using the in-memory repository while backend work proceeds. Never expose unguarded private tables merely to make the UI work.
- **Integrator:** Sole owner for shared `lib/main.dart`, workflow/build graph, official migrations, deployment state and test evidence. Merge other feature modules only when paths are disjoint.

## Testing and acceptance

- **Schema deployment:** [Completed for Module 01] in `umlzqlbakfwzgadafhyy` using tracked `platform_onboarding_foundation` migration.
- **Seed execution:** [Completed for Module 01] 1 organization, 3 demo plans, 3 zero-dollar plan prices, 9 demo features, 1 school application, 1 subscription request.
- **RLS/ACL live verification:** [Passed for deny-all private baseline] 12/12 RLS enabled, 0 public client table read/write grants. Security linter shows 12 INFO notices for intentionally absent policies; privileged pre-existing `public.rls_auto_enable()` function was hardened with `supabase/schema/02_secure_existing_rls_trigger.sql` (verified client execution revoked). Future API policy tests still required.
- **Flutter unit/widget test:** [Unverified]; local Flutter SDK unavailable in execution environment. GitHub Actions run #1 failed before steps; failure cause unconfirmed.
- **Production:** not authorized; never seed sample records into production.

## Decisions requested

- [x] **ORG-01** Development Supabase organization: `YouPro School` (user-created project confirmed).
- [x] **ORG-02** Project region is `ap-northeast-2` (Tokyo), as created by user.
- [ ] **ARCH-01** Confirm catalog table naming changes and Module 01 onboarding information.
- [ ] **ARCH-02** Confirm future provider for real billing; current flows are simulation only.

**Last tracking update:** 2026-11-10 after live deployment, synthetic seeding, RLS/ACL verification and unrelated exposed event-trigger function privilege hardening. Flutter CI and live application APIs remain open.


## Update — 2026-11-10: First onboarding screen and account authentication

| Task | State | Evidence / remaining gate |
|---|---|---|
| Account-profile/theme physical schema | [Completed — deployed] | `public.user_profiles`, `public.user_preferences`; 3 owner-only RLS policies each |
| Auth account-bootstrap Edge Function | [Completed — deployed] | `account-bootstrap` ACTIVE v1; `verify_jwt=true`, own-row calls |
| Auth schema lint and grants | [Completed — tested] | 2 tables have RLS, no `anon` grants; older 12 `platform` INFO notices intentionally private |
| First screen desktop/mobile Flutter UI | [Code committed — needs runtime tests] | Reference-based adaptive layout, progress, logo and original vector illustration |
| Sign in with Google | [Implemented — provider setup pending] | Supabase OAuth; no client secret; configure Google in Auth dashboard |
| Continue with email | [Implemented — delivery setup pending] | Supabase email magic link; SMTP and callback URL required |
| Theme settings | [Implemented — runtime test pending] | System/Light/Dark locally and through `public.user_preferences` |
| Flutter dependencies / lockfile | [Partially complete] | Pins committed; generate updated `pubspec.lock` with Flutter toolchain |
| Flutter CI | [Blocked] | [Latest workflow run](https://github.com/yunusyosaf399/pohantoonai/actions/runs/42870388602) failed before reporting job steps; compilation cannot be confirmed |
| Authenticated sign-in E2E | [Blocked] | Provider credentials, test user and valid deep links not yet tested |
| Organization operator access | [Not Started] | No automatic admin access after sign-in |

**Next:** Configure provider settings and email delivery, fix Flutter CI execution, generate lockfile, then test the first screen and Auth flow on Android and Windows/Web. Continue plan-selection UI only after account creation is confirmed. Do not start student/finance live table exposure without RLS.


## OAuth callback debugging — 2026-11-11

- **Live Auth evidence:** Supabase Auth log at 03:06:51 UTC: external Google provider redirect; 03:07:00 UTC: `user_signedup` + HTTP 302. Aggregate `auth.users`: one account created recently. This is server-side progress, not a verified Flutter session.
- **Earlier error:** at 03:04:07 UTC, `400: OAuth state parameter missing` observed on a separate attempt; do not replay Google callbacks or share token-bearing URLs.
- **Flutter fix:** [OAuth gateway](../../lib/features/auth/data/account_auth_gateway.dart) uses the active Flutter Web origin/port as `redirectTo` for Google and email; mobile retains `pohantoonai://auth-callback`. Added [redirect tests](../../test/auth/oauth_redirect_test.dart).
- **External configuration gate:** Set a stable Flutter Web port, add `http://localhost:3000/**` to the Supabase **Additional Redirect URLs** in the test project. This is separate from Google's Supabase-hosted callback URI.
- **Outstanding:** No ability to inspect or mutate Supabase's Site URL/allowlist via currently connected management tool; no Flutter SDK available to run new test; latest GitHub Actions workflows also failed, so test acceptance is still open. Windows protocol handler is not yet implemented.
- **Next verification:** complete one Google sign-in at `http://localhost:3000` and confirm the app receives Auth session, invokes `account-bootstrap` and transitions to Step 1 success UI.

