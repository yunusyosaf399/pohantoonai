# Module 02.5 — Account welcome emails and new sign-in alerts

Status as of 2026-11-13: **DB schema deployed and Edge Function `account-auth-email` ACTIVE with `verify_jwt=true`; Flutter code remains on a review branch.** Delivery still needs verified `pohantoonai.com`, `RESEND_API_KEY`, and a real inbox test. Two server migrations applied: `account_auth_email_notification_ledger` and `account_auth_email_require_mfa_assurance`. The read-only SQL permissions smoke test passed.

## Approved behavior embodied in code

- Sender: `PohantoonAI Security <no-reply@pohantoonai.com>`.
- First **verified** account session after registration (new accounts created *after* DB migration activation): one welcome email. This supports Google OAuth and verified email/OTP accounts.
- Subsequent **new Auth sessions**: a sign-in activity alert with UTC time from `auth.sessions.created_at`, parsed device from `auth.sessions.user_agent`, and best-effort approximate location derived from `auth.sessions.ip`.
- The app invokes notification delivery after MFA verification (or after Supabase confirms MFA is not required). Recovery-only sessions are excluded. New sign-in notification delivery **never** blocks login, workspace restoration, or session persistence.
- Supabase login sessions are the authoritative source of device/time/IP, not the Flutter client request. If no `IPINFO_TOKEN` is configured or the IP cannot be geolocated, the email clearly states **Location unavailable** (do not invent a city).
- Service-only email ledger is one entry per session, at most one welcome per user; existing accounts do not receive retroactive welcome messages. Retries are bounded; Resend uses an idempotency key.
- No `school_id` is stored because authentication belongs to the one global account identity shared across all schools.

### Database schema

`public.account_auth_email_config`: single activation timestamp, so accounts registered before deployment are never greeted as new users.

`public.account_auth_email_notifications`: delivery log with `user_id` (FK to `auth.users`), `session_id` (dedup), `kind`, `status`, `send_attempts`, `sent_at` and provider message ID. RLS is on; no ordinary client policies or grants.

`public.reserve_account_auth_email(user_id, session_id)`: private-to-service-role SECURITY DEFINER RPC, checks that the session belongs to the user, is recent, and the account email is verified. Neither this RPC nor the tables are accessible to `anon` or `authenticated`.

The Edge Function verifies the caller's bearer token with Supabase Auth first, then extracts the cryptographically protected `sub`/`session_id` claims. The SQL function also checks `auth.sessions.aal='aal2'` if the user has a verified MFA factor, preventing a direct caller from bypassing the Flutter-side MFA notification gate. Only these verified values are passed to the privileged RPC. There is **no email sender endpoint accepting an arbitrary recipient**.

### Password-changed alerts — managed by Supabase Auth (not this Edge Function)

**Recommended and required for the product:** enable the native **Password changed** security notification under the hosted [Supabase Auth Email Templates](https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/templates) page, Security Notifications section. It is disabled unless explicitly enabled at project level. The project's Resend-backed SMTP then sends the confirmation message after Auth actually changes the password, whether the change originated from the OTP recovery flow, owner settings, or another Auth client. A *request* for a reset OTP does not count as a completed password change.

Do **not** implement a parallel password-change email in Flutter or the account-auth-email function: that would create duplicates and miss changes made outside the app. Supabase native password-changed template can be branded using the approved sender `no-reply@pohantoonai.com`. The Supabase template does not natively contain a client's precise IP/location; reserve best-effort device/time/location for fresh-session alerts.

Verification: after enabling and saving the template, use a new OTP, successfully save a *new password*, and check Resend Emails for **a second separate email** with subject like 'Your PohantoonAI password was changed'. Verify no alert is issued from requesting/entering an invalid OTP alone.

### Setup — required before enabling delivery

1. Verify `pohantoonai.com` at [Resend Domains](https://resend.com/domains) with the DNS records Resend supplies. Configure SPF, DKIM and DMARC; do not send until the domain is verified. Prefer a real monitored support contact elsewhere for security incidents.
2. Create a sending-only Resend API key. Store the **secret in Supabase Edge Function secrets** as `RESEND_API_KEY`, not in Flutter, GitHub or chat.
3. **Optional**: if approximate city/region/country is required, configure an IPinfo account and add `IPINFO_TOKEN` as a Supabase secret. This sends the sign-in session IP to IPinfo for lookup, so document that processing in privacy information. Otherwise the location field intentionally says `Location unavailable`. Geo-IP can be wrong when using VPNs/mobile networks.
4. The ledger migration and MFA-assurance patch have **already been applied** to Supabase project `umlzqlbakfwzgadafhyy`. The complete reproducible schema is retained in `supabase/schema/16_account_auth_email_notifications.sql`. Do **not** reapply without checking migration history.
5. `supabase/functions/account-auth-email/index.ts` is **already deployed** as `account-auth-email` with **verify_jwt=true**. `SUPABASE_URL`, `SUPABASE_ANON_KEY` (or publishable key), and `SUPABASE_SERVICE_ROLE_KEY` are Supabase runtime secrets; do not expose the service key to the app.
6. Review and merge the Flutter change, then publish the app to invoke the function after the MFA gate.
7. Separately configure [Supabase Auth custom SMTP](https://supabase.com/dashboard/project/umlzqlbakfwzgadafhyy/auth/smtp) using Resend SMTP and sender `no-reply@pohantoonai.com`. This controls Supabase's own OTP, confirmation and password-recovery messages; the Edge Function only handles welcome and sign-in alerts.
8. If the sender is not properly configured, the function returns `503 email_provider_not_configured`; the app still signs in successfully.

### Security advisors

The post-deployment security advisor lists these two server-only tables as `RLS Enabled No Policy` (INFO). This is **intentional**: they are service-only, and access-grant checks passed. It also reports that Supabase Auth **Leaked Password Protection** is disabled (WARN); the project owner should enable this separately from the email notifications.

### Important limitation — failed sign-in alerts

This module does **not** claim to send email on every **failed** sign-in attempt. Flutter cannot reliably observe attempts made from other devices, nor identify an account behind wrong/unrecognized credentials. Adding a client-callable 'someone tried my email' endpoint would be vulnerable to spamming and user enumeration.

For reliable failed-attempt alerts, implement a separate server-side detector using Supabase Auth audit logs and/or the plan-eligible Password Verification Attempt hook. Require server-side actor attribution, a threshold (e.g., 5 failures in 15 minutes), rate limiting, deduplication, and no unauthorized email-address lookups. Supabase Auth audit-log IP may be absent for ordinary logins; session IP is available only for created sessions. Do not claim exact location when unavailable.

### Manual acceptance tests

1. Complete Resend domain verification and configure secrets + Auth SMTP. Confirm sender with an external inbox.
2. Register a **new** email/password account, confirm its OTP. Expect **one welcome email**, never before verification.
3. Register a new Google account. Expect **one welcome email** after OAuth and any required MFA. No duplicate upon app restart.
4. Sign out and sign in again. Expect **one sign-in alert** containing Auth session time, device and approximate location or `Location unavailable`.
5. Refresh JWT, close/reopen Android, and retry the MFA check. Expect **no duplicate** email for the existing session.
6. Test enrolled MFA with an unverified factor challenge. Expect **no notification until MFA is satisfied**.
7. Run password reset OTP. Expect **no welcome/sign-in alert** for the temporary recovery-only session.
8. Verify a different user cannot read or insert any row in the ledger, and cannot call the RPC.
9. Temporarily unset Resend key in staging; sign-in must still succeed, and the Edge Function must fail closed without exposing credentials.
10. Check provider logs and email inbox; a Resend API success only means the email was accepted, not necessarily delivered to the inbox.

References:
- https://supabase.com/docs/guides/auth/audit-logs
- https://supabase.com/docs/guides/auth/auth-hooks
- https://supabase.com/docs/guides/functions/examples/send-emails
- https://resend.com/docs/dashboard/emails/idempotency-keys
