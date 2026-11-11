# Android Test APK — build and install from GitHub

> **Status (2026-11-11): Workflow committed, APK NOT BUILT.**
> GitHub run #1 ended with `failure` **before any job steps started**: no checkout, SDK install, compilation or test execution took place. No artifact was uploaded. The underlying GitHub runner rejection reason was not exposed through the connected API; do not claim a Flutter compilation error or successful APK build.

## Test APK source and run

- Workflow source: [`.github/workflows/android-apk.yml`](../../.github/workflows/android-apk.yml)
- GitHub Actions: https://github.com/yunusyosaf399/pohantoonai/actions/workflows/android-apk.yml
- First failed build: https://github.com/yunusyosaf399/pohantoonai/actions/runs/42956828072
- Release page, **once a successful build publishes one**: https://github.com/yunusyosaf399/pohantoonai/releases

### What the workflow does after GitHub starts jobs

1. Checks out the latest repository `main`.
2. Installs JDK 17 and Flutter stable.
3. Runs `flutter pub get` (the currently committed lockfile predates some direct dependencies, so a dependency refresh is essential).
4. Runs `flutter build apk --debug --no-pub`.
5. Verifies `build/app/outputs/flutter-apk/app-debug.apk` exists, creates SHA-256 checksum.
6. Uploads `pohantoonai-android-test-apk` Actions artifact (ZIP, expires in 14 days).
7. Attempts to publish an Android DEBUG **prerelease** asset `pohantoonai-android-test.apk` using `GITHUB_TOKEN`. This step is best-effort; an APK artifact can still exist if release publication is restricted.

**This APK is intended only for testing**, is signed by a temporary debug key and is NOT for Google Play or production distribution. An app built by a different runner may use a different debug-signing key, so a subsequent update may require uninstalling the previous test app (which removes local app data).

## Why build #1 is blocked

GitHub's build infrastructure returned a completed failed job with **zero steps** and **no logs**. All older Flutter CI jobs in the same private repository also failed in this pre-step manner. Therefore the next diagnosis is **GitHub Actions runner admission**, not Dart/Gradle errors.

From your phone's browser:

1. Open https://github.com/yunusyosaf399/pohantoonai/actions/runs/42956828072. Look for the failure annotation/banner **above the job steps**. It may describe billing, budget, runner availability or policy. Do not assume which one until the annotation is seen.
2. Check https://github.com/yunusyosaf399/pohantoonai/settings/actions and confirm GitHub Actions is enabled for the private repository, including access to the needed actions. If Release upload is disallowed, the artifact approach can still work.
3. Check https://github.com/settings/billing and GitHub **Billing & Licensing / Budgets and alerts / Actions**. A $0 budget, exhausted compute allowance, failed payment or account restriction can prevent runner startup in private repositories. Adjust payment/budget **only if acceptable**; GitHub Actions may incur usage charges. The assistant cannot view billing-specific owner settings.
4. If nothing is blocked, check GitHub Status/Support and retry the workflow once.

## Run on a phone, after the runner issue is resolved

1. On GitHub open https://github.com/yunusyosaf399/pohantoonai/actions/workflows/android-apk.yml.
2. Select **Build Android Test APK → Run workflow → main** (the workflow can also auto-run on source changes).
3. Open the **successful** workflow run.
4. **Simplest installation:** open https://github.com/yunusyosaf399/pohantoonai/releases and select the newest *Android test* prerelease. Tap `pohantoonai-android-test.apk`.
5. **Artifact fallback:** in the successful Actions run, download `pohantoonai-android-test-apk` under Artifacts. Extract its ZIP on Android and open `app-debug.apk`.
6. Android may ask to allow installation from your browser/files app. Confirm only if you trust this private development build.
7. Open Pohantoon AI. Test Step 1 Google/email and Light/Dark/System. Supabase Auth must allow `pohantoonai://auth-callback` in Additional Redirect URLs. The app sends this native URI after Google completes the hosted callback.

## Security and limitations

- Only the Supabase **publishable** API key is shipped in the Flutter client. Never embed service-role key, Google OAuth Client Secret or database credentials in the APK.
- Debug builds expose development tooling and use a temporary signing certificate. They are not release-ready.
- A successful APK compilation does NOT mean OAuth end-to-end passes. Test Supabase deep links, the authenticated UI transition, and account preferences on the installed device.
- The GitHub repository is private; download requires GitHub account permissions.
- This workflow is not a replacement for CI: `flutter analyze` and `flutter test` should still pass before a production release.

## Last result

| Field | Value |
|---|---|
| Workflow | `.github/workflows/android-apk.yml` |
| Run | `42956828072` |
| GitHub conclusion | `failure` |
| Executed job steps | `0` |
| Uploaded APK artifacts | `0` |
| Root cause | Not directly reported by accessible job API; review GitHub run annotation / Actions settings / billing |

