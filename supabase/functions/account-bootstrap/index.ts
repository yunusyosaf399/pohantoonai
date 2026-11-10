// pohantoonai / account-bootstrap
// Only accepts signed-in users; verifies the JWT with Supabase Auth on EVERY call.
// Uses the caller's JWT and public-table RLS, never the service_role or a client-supplied user id.
// This endpoint is idempotent and does not grant organization/school permissions.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST") return json({ code: "method_not_allowed" }, 405);

  const bearer = request.headers.get("Authorization") ?? "";
  if (!/^Bearer\s+\S+$/i.test(bearer)) {
    return json({ code: "authentication_required" }, 401);
  }

  const baseUrl = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if (!baseUrl || !key) return json({ code: "service_unavailable" }, 503);

  const headers = {
    "Authorization": bearer,
    "apikey": key,
    "Content-Type": "application/json",
  };

  try {
    // Fetching the current Auth user validates JWT signature, expiry and revocation state
    // according to Supabase Auth. Never trust a submitted user_id.
    const identity = await fetch(baseUrl + "/auth/v1/user", {
      method: "GET",
      headers,
    });
    if (!identity.ok) return json({ code: "invalid_session" }, 401);
    const user = await identity.json();
    const id: unknown = user?.id;
    if (typeof id !== "string" ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
      return json({ code: "invalid_session" }, 401);
    }

    // Preferences bootstrap is safe to call repeatedly: never overwrite an
    // existing user's selected theme with the default.
    for (const path of ["user_profiles", "user_preferences"]) {
      const upsert = await fetch(baseUrl + "/rest/v1/" + path, {
        method: "POST",
        headers: { ...headers, "Prefer": "resolution=ignore-duplicates,return=minimal" },
        body: JSON.stringify({ user_id: id }),
      });
      if (!upsert.ok) return json({ code: "profile_initialization_failed" }, 503);
    }

    const result = await fetch(
      baseUrl + "/rest/v1/user_preferences?user_id=eq." +
        encodeURIComponent(id) + "&select=theme_mode",
      { method: "GET", headers },
    );
    if (!result.ok) return json({ code: "preferences_unavailable" }, 503);
    const rows = await result.json();
    const theme = Array.isArray(rows) && rows[0] &&
      ["system", "light", "dark"].includes(rows[0].theme_mode)
        ? rows[0].theme_mode : "system";

    return json({ user_id: id, theme_mode: theme, onboarding_stage: "account_created" }, 200);
  } catch {
    // Don't leak Auth tokens, headers, SDK internals, or connection details.
    return json({ code: "service_unavailable" }, 503);
  }
});
