// PohantoonAI account lifecycle emails. Requires a verified Resend sending domain.
// Never accepts recipient, event kind, session ID or IP from the request body.
// Deploy with verify_jwt=true; this handler also revalidates the JWT with Auth.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const htmlEscape = (input: string): string => input.replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c] ?? c);

function respond(code: number, result: string): Response {
  return new Response(JSON.stringify({ code: result }), {
    status: code,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

type Reservation = {
  notification_id: string;
  notification_kind: "welcome" | "login_alert";
  recipient_email: string;
  session_at: string;
  session_ip: string | null;
  session_user_agent: string | null;
};

function jwtClaims(token: string): Record<string, unknown> | null {
  // Only used AFTER /auth/v1/user verifies the exact bearer token.
  try {
    const payload = token.split(".")[1];
    if (!payload) return null;
    return JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/")
      .padEnd(Math.ceil(payload.length / 4) * 4, "=")));
  } catch { return null; }
}

function userAgentLabel(raw: string | null): string {
  const value = (raw ?? "").slice(0, 512);
  if (/android/i.test(value)) return "Android device";
  if (/iphone|ipad|ios/i.test(value)) return "iPhone or iPad";
  if (/windows/i.test(value)) return "Windows device";
  if (/mac os|macintosh|darwin/i.test(value)) return "Mac device";
  if (/linux/i.test(value)) return "Linux device";
  if (/chrome/i.test(value)) return "Chrome browser";
  if (/firefox/i.test(value)) return "Firefox browser";
  if (/safari/i.test(value)) return "Safari browser";
  if (/dart/i.test(value)) return "PohantoonAI app";
  return "Unrecognized device or browser";
}

async function approximateLocation(ip: string | null): Promise<string> {
  const token = Deno.env.get("IPINFO_TOKEN");
  // An opt-in IPinfo account is required: no IP is sent to a third-party
  // geolocation service unless the project owner enables that integration.
  if (!token || !ip || !/^[0-9a-f.:]+$/i.test(ip) ||
      ip === "::1" || ip.startsWith("127.") || ip.startsWith("10.") ||
      ip.startsWith("192.168.") || ip.startsWith("172.16.")) {
    return "Location unavailable";
  }
  try {
    const response = await fetch(
      `https://ipinfo.io/${encodeURIComponent(ip)}/json?token=${encodeURIComponent(token)}`,
      { signal: AbortSignal.timeout(2500) });
    if (!response.ok) return "Location unavailable";
    const geo = await response.json();
    const fields = [geo.city, geo.region, geo.country]
      .filter((v: unknown): v is string => typeof v === "string" && v.length <= 100);
    return fields.length ? fields.join(", ") + " (approximate)" : "Location unavailable";
  } catch { return "Location unavailable"; }
}

function emailContent(item: Reservation, location: string) {
  const welcome = item.notification_kind === "welcome";
  const subject = welcome ? "Welcome to PohantoonAI — your account is ready"
    : "Security alert: New sign-in to your PohantoonAI account";
  const time = new Date(item.session_at).toUTCString();
  const device = userAgentLabel(item.session_user_agent);
  const title = welcome ? "Welcome to PohantoonAI!" : "New account sign-in";
  const intro = welcome
    ? "Your verified PohantoonAI account is ready. You can begin setting up your school workspace."
    : "A new sign-in session was created for your PohantoonAI account.";
  const safety = "If you do not recognize this activity, open the PohantoonAI app, go to Owner & Security, review your account credentials and enable two-factor authentication. If you use Google sign-in, review your Google account security too.";
  const rows = [
    ["Date & time", time],
    ["Device", device],
    ["Approximate location", location],
  ];
  const rowMarkup = rows.map(([key, value]) =>
    `<tr><td style="padding:11px 8px;color:#64748b;font-size:13px">${htmlEscape(key)}</td><td style="padding:11px 8px;color:#0f172a;font-size:13px;font-weight:600;text-align:right">${htmlEscape(value)}</td></tr>`).join("");
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:32px 12px;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#0f172a">
  <main style="max-width:560px;margin:0 auto;border:1px solid #e2e8f0;border-radius:16px;overflow:hidden;background:#fff">
    <header style="background:#102a4c;padding:24px 30px;color:#fff;font-size:21px;font-weight:700">Pohantoon<span style="color:#68d4bd">AI</span></header>
    <section style="padding:30px">
      <div style="font-size:12px;letter-spacing:1.5px;font-weight:700;color:#087f75">${welcome ? "WELCOME" : "SECURITY NOTIFICATION"}</div>
      <h1 style="margin:12px 0 14px;font-size:27px;line-height:1.2">${title}</h1>
      <p style="font-size:15px;line-height:1.7;color:#475569">${intro}</p>
      <table role="presentation" style="width:100%;border-collapse:collapse;margin:24px 0;background:#f8fafc;border-radius:9px">${rowMarkup}</table>
      ${welcome ? '<p style="font-size:15px;line-height:1.7">Start with your plan, school details and secure account settings.</p>' : ""}
      <div style="border-left:3px solid #d97706;padding:12px 16px;background:#fffbeb;margin-top:24px">
        <strong style="font-size:14px">Was this not you?</strong>
        <p style="margin:8px 0 0;font-size:13px;line-height:1.6">${safety}</p>
      </div>
    </section>
    <footer style="padding:18px 30px;border-top:1px solid #e2e8f0;color:#64748b;font-size:12px;line-height:1.5">
      PohantoonAI account notification · Sent automatically from no_reply@pohantoonai.com.
      Never share your password or verification code. This email contains no sign-in links.
    </footer>
  </main>
</body></html>`;
  const text = `${title}\n\n${intro}\n\nDate & time: ${time}\nDevice: ${device}\nApproximate location: ${location}\n\nWas this not you?\n${safety}\n\nPohantoonAI security · no_reply@pohantoonai.com`;
  return { subject, html, text };
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST") return respond(405, "method_not_allowed");
  const rawAuth = request.headers.get("Authorization") ?? "";
  const match = /^Bearer\s+(\S+)$/i.exec(rawAuth);
  if (!match) return respond(401, "authentication_required");

  const baseUrl = Deno.env.get("SUPABASE_URL");
  const pubKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!baseUrl || !pubKey || !serviceKey || !resendKey) {
    return respond(503, "email_provider_not_configured");
  }

  const verified = await fetch(baseUrl + "/auth/v1/user", {
    headers: { authorization: rawAuth, apikey: pubKey },
  }).catch(() => null);
  if (!verified?.ok) return respond(401, "invalid_session");

  const user = await verified.json();
  const claims = jwtClaims(match[1]);
  const userId = user?.id;
  const sessionId = claims?.session_id;
  if (typeof userId !== "string" || !uuid.test(userId) ||
      typeof sessionId !== "string" || !uuid.test(sessionId) ||
      claims?.sub !== userId) return respond(401, "invalid_session");

  // No user-supplied email, IP, or kind is used. Supabase Auth owns the session.
  const privileged = {
    "apikey": serviceKey, "Authorization": `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
  };
  const reserved = await fetch(baseUrl + "/rest/v1/rpc/reserve_account_auth_email", {
    method: "POST",
    headers: privileged,
    body: JSON.stringify({ p_user_id: userId, p_session_id: sessionId }),
  }).catch(() => null);
  if (!reserved?.ok) return respond(503, "notification_unavailable");
  const rows: Reservation[] = await reserved.json();
  const item = Array.isArray(rows) ? rows[0] : null;
  if (!item) return respond(200, "no_new_notification");

  const updateStatus = async (status: "sent" | "failed", providerId?: string) =>
    await fetch(
      baseUrl + "/rest/v1/account_auth_email_notifications?id=eq." +
      encodeURIComponent(item.notification_id),
      {
        method: "PATCH",
        headers: { ...privileged, "Prefer": "return=minimal" },
        body: JSON.stringify({
          status,
          ...(status === "sent"
            ? { sent_at: new Date().toISOString(), provider_message_id: providerId ?? null }
            : {}),
        }),
      },
    );

  const location = await approximateLocation(item.session_ip);
  const message = emailContent(item, location);
  const sent = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendKey}`,
      "Content-Type": "application/json",
      "Idempotency-Key": `pohantoonai/account-auth/${item.notification_id}`,
    },
    body: JSON.stringify({
      from: "PohantoonAI Security <no_reply@pohantoonai.com>",
      to: [item.recipient_email],
      ...message,
    }),
  }).catch(() => null);
  if (!sent?.ok) {
    await updateStatus("failed").catch(() => null);
    return respond(503, "delivery_failed");
  }
  const result = await sent.json().catch(() => ({}));
  const saved = await updateStatus("sent", result.id).catch(() => null);
  if (!saved?.ok) return respond(503, "delivery_status_unavailable");
  return respond(200, "notification_sent");
});
