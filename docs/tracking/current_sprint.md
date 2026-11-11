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


## Android mobile APK request — 2026-11-11

| Task | Status | Evidence |
|---|---|---|
| Add GitHub Actions Android debug build | **[Completed — source committed]** | [Workflow](../../.github/workflows/android-apk.yml) installs Java 17 + Flutter, runs dependency resolution and APK build; upload artifact + optional prerelease |
| Trigger GitHub-run build | **[Attempted — failed before steps]** | [Run 42956828072](https://github.com/yunusyosaf399/pohantoonai/actions/runs/42956828072) concluded failed in seconds; 0 steps and 0 APK artifacts |
| Diagnose startup failure | **[External GitHub account/runner blocker]** | Previous Flutter Actions jobs also have no steps; exact GitHub run annotation not exposed by connector; account billing/Actions settings must be checked |
| Provide mobile install instructions | **[Completed]** | [Android APK build guide](../flutter/android_apk_build.md) |
| User installs test APK | **[Blocked — no APK]** | Requires a successful GitHub-hosted runner job |
| Google sign-in mobile E2E | **[Blocked — APK]** | Then verify allowlisted `pohantoonai://auth-callback` and session callback |

**Do not mark APK built or Flutter compilation verified until an artifact exists and checks succeed.** Debug-signed APK is development-only. Repo remains private and release assets require GitHub access.

**Retry verification (2026-11-11):** GitHub Actions APK workflow run `42956828072` was retried once (`run_attempt=2`) using GitHub Actions API. It again concluded `failure` without any executed steps or artifacts. Do not automatically retry indefinitely; account runner admission / billing / policy must be inspected by repository owner.

## Module 01.2 — Choose Subscription Plan (2026-11-11)

| Work item | Status | Evidence |
|---|---|---|
| Plan catalog + own draft selection schema | **[Deployed]** | [SQL](../../supabase/schema/04_onboarding_plan_selection.sql), live migration `20261111050513` |
| Security policies and grants | **[Verified]** | 2 RLS-enabled tables; 1 active-plan policy + 3 account-owned policies; zero anonymous privileges |
| Negative security / validation testing | **[Passed in test transaction]** | [SQL](../../supabase/tests/04_onboarding_plan_security.sql): own selection allowed, impersonation + invalid plans denied, private SaaS rows denied; 0 rows after rollback |
| Published catalog sync | **[Verified]** | Private demo descriptions updated; published descriptions matched for all 3 plans |
| Desktop, tablet, mobile Flutter Step 2 | **[Code committed]** | [UI](../../lib/features/onboarding/presentation/plan_selection_screen.dart) + app sign-in flow wiring |
| Light/Dark/System and navigation | **[Source complete; unverified on device]** | Existing theme; saved selection advances to owner-scoped Step 3 form |
| Flutter widget + integration tests | **[Written, not executed]** | [Screen tests](../../test/onboarding/plan_selection_test.dart) + [app tests](../../test/onboarding/plan_app_navigation_test.dart); GitHub runner blocked by billing |
| School creation or payment | **[Not implemented]** | Requires Step 3 application, review, secure billing and provisioning |
| Auth hardening | **[Outstanding warning]** | Supabase advisor: leaked password protection disabled; remediation in DB module document |

**Next:** Fix account Actions/billing to run Flutter analyzer/widget tests; test real Android/Web login and plan save; then implement Step 4 formal application submission and review; Step 3 is now deployed.

## Module 01.3 — School Information (2026-11-11)

| Work item | Status | Evidence |
|---|---|---|
| Draft schema and selected-plan relationship | **[Deployed]** | [SQL](../../supabase/schema/05_school_setup_drafts.sql), live migration `20261111064830` |
| Applicant-only RLS / strict status constraints | **[Verified]** | 3 policies, authenticated `SELECT/INSERT/UPDATE`, no anon grants; no client direct functions |
| Partial Save Draft and Continue validation | **[DB test passed]** | [SQL test](../../supabase/tests/05_school_setup_security.sql): incomplete save allowed, required/plan-capacity checks enforced |
| Forged-user prevention and plan-change reset | **[DB test passed]** | Test transaction rolled back; draft ownership and review-marker reset verified |
| Step 3 responsive Flutter screen | **[Source committed]** | [Form UI](../../lib/features/onboarding/presentation/school_setup_screen.dart): four cards, desktop rail, mobile single-column, Light/Dark, validated fields |
| Step 3 own-draft load/save | **[Source committed]** | [Model](../../lib/features/onboarding/domain/school_setup_draft.dart) + [Supabase repository](../../lib/features/onboarding/data/school_setup_repository.dart) |
| Step 4 read-only handoff | **[Preview only]** | [Review UI](../../lib/features/onboarding/presentation/school_review_preview.dart), no school or subscription activated |
| Flutter widget navigation and form tests | **[Written, not run]** | [Step 3 tests](../../test/onboarding/school_setup_test.dart) + [flow test](../../test/onboarding/plan_app_navigation_test.dart). GitHub Actions blocked by owner billing/spending restriction |
| True Step 4 submission and approval | **[Not started]** | Requires own-row submission, signed terms, protected operator approvals and audit |
| Security advisor remaining warning | **[Outside Step 3]** | Leaked password protection disabled; see [Supabase guide](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) |

**Next sequence:** unblock Flutter test runner on laptop, validate layout and OAuth return, complete Step 4 Application Review + submission APIs; then defer payment until approval.

## Cross-platform auth callback repair — 2026-11-11

| Item | Status | Evidence |
|---|---|---|
| Web OAuth redirect path/port and cleanup | **[Code committed]** | [Auth gateway](../../lib/features/auth/data/account_auth_gateway.dart); [unit tests](../../test/auth/oauth_redirect_test.dart) |
| Android deep-link handler | **[Code committed]** | Flutter router disabled so Supabase app_links handles `pohantoonai://auth-callback` |
| iOS/macOS deep-link handling | **[Code committed]** | Registered URI scheme and disabled competing Flutter router in Info.plist |
| Windows desktop custom URI protocol | **[Code committed]** | [Windows runner](../../windows/runner/main.cpp) registers current-user scheme and forwards to running app via `SendAppLinkToInstance` |
| Auth error handling and native browser launch | **[Code committed]** | Auth stream errors captured and shown; Google OAuth launches system browser |
| Supabase Auth allowlist | **[Blocked — owner dashboard config]** | Must allow `pohantoonai://auth-callback` plus exact Web URL(s); no Auth configuration writer currently connected |
| Flutter compiled and real device tested | **[Blocked — runner billing / local verification]** | GitHub Actions account billing/spending restriction prevents job startup; no confirmed Windows or mobile callback login |
| Documentation | **[Completed]** | [Cross-platform callback guide](../../supabase/auth/OAUTH_CALLBACK_PLATFORMS.md) + static platform tests |

**Follow-up:** Confirm redirect allowlist in hosted Supabase Auth UI, run `flutter pub get`, `flutter analyze`, `flutter test`, then verify real sign-in in Chrome on fixed port, Android, Windows (unpackaged runner) and iOS/macOS. Never share one-time login codes or tokens.

### Windows OAuth C3861 compatibility repair — 2026-11-11

- User reported: `SendAppLinkToInstance` missing in compiled Windows runner; feature was introduced in app_links 7.2.0 and was not supported by installed headers.
- [Windows runner](../../windows/runner/main.cpp) now defines and invokes a local `ForwardAuthLinkToExistingWindow` helper using `SendAppLink(HWND)` and Windows `FindWindowW`. [Native callback test](../../test/auth/native_callback_contract_test.dart) updated accordingly.
- **Status:** code committed; Windows build/test and real OAuth return still awaiting user's laptop verification. No Supabase schema changes required.

## Module 01.4 — Application Review and Go to Payment (2026-11-11)

| Task | Status | Evidence |
|---|---|---|
| Replace Step 4 preview with supplied responsive designs | **[Source committed]** | [Flutter review UI](../../lib/features/onboarding/presentation/school_review_preview.dart), mobile/tablet/desktop, light/dark/system |
| Four working Edit actions into Step 3 | **[Source committed]** | Section target keys and scroll-to-section in [Step 3](../../lib/features/onboarding/presentation/school_setup_screen.dart) |
| Accuracy acknowledgement and changed-draft protection | **[Deployed and DB-tested]** | [SQL](../../supabase/schema/06_onboarding_review_confirmation.sql), migration `20261111115622`, applicant-only RLS |
| Button label Go to Payment and Step 5 navigation | **[Source committed]** | [Main routing](../../lib/main.dart) and [safe payment preview](../../lib/features/onboarding/presentation/school_payment_preview.dart) |
| Database negative security tests | **[Passed]** | [Rollback-only test](../../supabase/tests/06_review_confirmation_security.sql); no test records retained |
| Flutter widget and app navigation tests | **[Written, not run]** | [Review tests](../../test/onboarding/school_review_test.dart) and [full flow tests](../../test/onboarding/plan_app_navigation_test.dart) |
| Payment processing and application approval | **[Not implemented]** | Requires provider, private server-side payment intent, verified webhook and operator sequencing |
| Real Windows/Android/iOS/Web UI testing | **[Pending]** | GitHub Actions runner blocked by account billing; no compilation claim |

**Note:** User requested Go to Payment rather than Submit Application. This is implemented as a safe stage handoff only, not authorization to charge before school/operator approval. Clarify production approval/checkout order before implementing Step 5.

### Step 4 reference completeness — optional postal code

- [SQL](../../supabase/schema/07_school_setup_postal_code.sql) deployed to existing test Supabase project as migration `20261111120829`: nullable `postal_code` on school draft, at most 32 characters; existing draft values untouched.
- [Step 3](../../lib/features/onboarding/presentation/school_setup_screen.dart), [draft model](../../lib/features/onboarding/domain/school_setup_draft.dart) and [Step 4 review](../../lib/features/onboarding/presentation/school_review_preview.dart) now contain the optional postal code.


## Module 01.5 — Subscription Payment screen and Skip for Now (2026-11-11)

| Task | State | Evidence |
|---|---|---|
| Mobile/tablet/desktop Light/Dark Flutter payment UI | **[Code committed]** | [Step 5 UI](../../lib/features/onboarding/presentation/school_payment_preview.dart) |
| Method, cycle, billing fields / save preferences | **[Code committed]** | [Domain](../../lib/features/onboarding/domain/onboarding_payment_preferences.dart) and [RLS repository](../../lib/features/onboarding/data/onboarding_payment_preferences_repository.dart) |
| Own-row billing preferences DB and test skip | **[DB deployed]** | [Portable SQL](../../supabase/schema/08_onboarding_payment_preferences.sql), migration 20261111122224 |
| Negative RLS and input-state tests | **[DB tests passed]** | [Rollback-only test](../../supabase/tests/08_payment_preferences_security.sql) |
| Skip for Now navigation to Step 6 | **[Code committed]** | [Main routing](../../lib/main.dart) and [non-provisioned Step 6 preview](../../lib/features/onboarding/presentation/school_dashboard_setup_preview.dart) |
| Flutter UI/widget/integration tests | **[Written, not run]** | [Step 5 widgets](../../test/onboarding/school_payment_screen_test.dart) and [6-step navigation](../../test/onboarding/plan_app_navigation_test.dart) |
| Real payments, prices, taxes, coupons, processor | **[Not implemented]** | Pay Now disabled; no PAN/CVV collection or misleading sample SAR charges |
| Dashboard permissions / school provisioning | **[Not implemented]** | Test skip does NOT approve, bill, provision or enable school operations |

**Next gate:** Test the Flutter code on Windows/mobile/Web, then define real school-approval and payment order, secure provider checkout/webhooks/idempotency and authorized school provisioning before allowing any paid activation.


## Module 02 dashboard and branding foundation — 2026-11-11

| Task | Status | Evidence |
|---|---|---|
| Reference-matched responsive desktop/tablet/mobile dashboard | **[Flutter code committed; build pending]** | [Dashboard UI](../../lib/features/onboarding/presentation/school_dashboard_setup_preview.dart) |
| Six analytics series, 10-sec rotation, hover pause, full-screen chart | **[Flutter code committed; device test pending]** | [Rotating panels](../../lib/features/dashboard/presentation/rotating_dashboard_panels.dart) |
| Admissions and approvals rotation + View all | **[Flutter code committed; device test pending]** | [Fixtures](../../lib/features/dashboard/domain/dashboard_demo_data.dart), [feed panels](../../lib/features/dashboard/presentation/rotating_dashboard_panels.dart) |
| Global demo search, quick actions, KPIs, fees, navigation | **[Flutter code committed; no real fact data yet]** | [Dashboard UI](../../lib/features/onboarding/presentation/school_dashboard_setup_preview.dart) |
| Profile icon edits school draft and logo | **[Flutter code committed]** | [App navigation](../../lib/main.dart), [logo picker](../../lib/features/onboarding/presentation/school_logo_picker.dart) |
| Logo bucket, 2-MiB MIME and owner-only Storage policies | **[Deployed and SQL-verified]** | [SQL 09](../../supabase/schema/09_school_logo_storage.sql), migration 20261111125611 |
| Applicant test preview dashboard preferences with RLS | **[Deployed and SQL-tested]** | [SQL 10](../../supabase/schema/10_demo_dashboard_preferences.sql), migration 20261111125713 |
| Multi-tenant real school/dashboard read foundation with owner RLS | **[Deployed and SQL-tested]** | [SQL 11](../../supabase/schema/11_school_dashboard_foundation.sql), migration 20261111125810; 0 schools, memberships, dashboard snapshots |
| Flutter tests/compile and pubspec.lock update | **[Pending local Flutter SDK]** | [Test source](../../test/dashboard/school_dashboard_test.dart), pinned file_selector 1.1.0, GitHub Actions billing blocker |
| Real school approval, provision, live students/admissions/finance | **[NOT implemented]** | Server-side authorization and domain modules are explicit next gate |

**Important:** real school dashboard metrics, memberships and activity are not created for anyone who skipped payment. Visible demo values are isolated Flutter fixtures only. Existing Supabase Security Advisor warning for leaked-password protection remains separate.


### Module 02 hardening follow-ups (2026-11-11)

- Deployed logo path test [09_school_logo_security.sql](../../supabase/tests/09_school_logo_security.sql) passed with ROLLBACK. No real school-logo object uploaded in automated tests.
- Added macOS user-selected read-only file entitlements and functional Ctrl+K demo search shortcut.
- [Dashboard Flutter widget tests](../../test/dashboard/school_dashboard_test.dart) now include rotation every 10 seconds, hover pause/resume, full-screen trends, full activity lists, school profile editing.
- **Build gate remains open:** new pinned file_selector 1.1.0 needs developer's flutter pub get to regenerate pubspec.lock, Flutter analyze/test and Windows/mobile/Web runtime validation.
