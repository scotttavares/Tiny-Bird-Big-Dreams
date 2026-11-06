// Cloudflare traffic for tinybirdbigdreams.com (zone analytics, falling back to the
// Web Analytics beacon). Used on /studio as a cross-check total.

function getMondayStr(ms) {
  const d = new Date(ms);
  const day = d.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setUTCDate(d.getUTCDate() + diff);
  return d.toISOString().slice(0, 10);
}


/* -------------------- Cloudflare Web Analytics -------------------- */

// Extract bare 32-char hex token from a raw value that may be the full <script> snippet
function beaconToken(raw) {
  if (!raw) return null;
  const m = raw.match(/["']token["']\s*:\s*["']([a-f0-9]{32})["']/i);
  return m ? m[1] : raw.trim();
}

function cfAuthHeader(env) {
  return { Authorization: `Bearer ${(env.CF_ANALYTICS_TOKEN || "").replace(/\s/g, "")}` };
}

let _cfAccountId = null;

async function cfGetAccountId(env) {
  if (_cfAccountId) return _cfAccountId;
  if (env.CF_ACCOUNT_ID) {
    _cfAccountId = env.CF_ACCOUNT_ID.trim();
    return _cfAccountId;
  }
  throw new Error("CF_ACCOUNT_ID secret not set");
}

// Shared aggregation logic for both zone-level and beacon traffic data
function parseCfGroups(groups, extractor) {
  const d7start = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const d1start = new Date(Date.now() - 1 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const totals = {
    d30: { visitors: 0, pageviews: 0 },
    d7: { visitors: 0, pageviews: 0 },
    d1: { visitors: 0, pageviews: 0 },
  };
  const weekly = {};
  for (const g of groups) {
    const date = g.dimensions?.date || "";
    const { v, pv } = extractor(g);
    totals.d30.visitors += v;
    totals.d30.pageviews += pv;
    if (date >= d7start) { totals.d7.visitors += v; totals.d7.pageviews += pv; }
    if (date >= d1start) { totals.d1.visitors += v; totals.d1.pageviews += pv; }
    const w = getMondayStr(new Date(date + "T00:00:00Z").getTime());
    if (!weekly[w]) weekly[w] = { visitors: 0, pageviews: 0 };
    weekly[w].visitors += v;
    weekly[w].pageviews += pv;
  }
  return { totals, weekly };
}

// Lookup zone tag — check explicit env secrets first, then auto-discover via REST API
async function cfGetZoneTag(hostname, env) {
  if (hostname === "tinybirdbigdreams.com" && env.CF_TBBD_ZONE_TAG) return env.CF_TBBD_ZONE_TAG.trim();
  const r = await fetch(
    `https://api.cloudflare.com/client/v4/zones?name=${encodeURIComponent(hostname)}&per_page=1`,
    { headers: cfAuthHeader(env) }
  );
  if (!r.ok) throw new Error("cf zones " + r.status);
  const j = await r.json();
  const id = j.result?.[0]?.id;
  if (!id) throw new Error("zone not found: " + hostname);
  return id;
}

// Zone-level CDN analytics — matches the numbers shown on the CF Domains dashboard
async function cfTrafficZone(zoneId, env) {
  const endDate = new Date().toISOString().slice(0, 10);
  const startDate = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const r = await fetch("https://api.cloudflare.com/client/v4/graphql", {
    method: "POST",
    headers: { ...cfAuthHeader(env), "Content-Type": "application/json" },
    body: JSON.stringify({
      query:
        `{viewer{zones(filter:{zoneTag:"${zoneId}"}){\n        httpRequests1dGroups(\n        filter:{AND:[{date_geq:"${startDate}"},{date_leq:"${endDate}"}]},\n        limit:365,orderBy:[date_ASC]\n        ){dimensions{date}sum{requests}uniq{uniques}}}}}`,
    }),
  });
  if (!r.ok) throw new Error("cf graphql zone " + r.status);
  const j = await r.json();
  if (j.errors?.length) throw new Error("cf gql zone: " + j.errors[0].message);
  const groups = j.data?.viewer?.zones?.[0]?.httpRequests1dGroups || [];
  return parseCfGroups(groups, (g) => ({ v: g.uniq?.uniques || 0, pv: g.sum?.requests || 0 }));
}

// Beacon-based Web Analytics — only tracks visits with the JS snippet installed
async function cfTrafficBeacon(siteTag, env) {
  const accountId = await cfGetAccountId(env);
  const endDate = new Date().toISOString().slice(0, 10);
  const startDate = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString().slice(0, 10);
  const r = await fetch("https://api.cloudflare.com/client/v4/graphql", {
    method: "POST",
    headers: { ...cfAuthHeader(env), "Content-Type": "application/json" },
    body: JSON.stringify({
      query:
        `{viewer{accounts(filter:{accountTag:"${accountId}"}){\n        rumPageloadEventsAdaptiveGroups(\n        filter:{AND:[{siteTag:"${siteTag}"},{date_geq:"${startDate}"},{date_leq:"${endDate}"}]},\n        limit:10000,orderBy:[date_ASC]\n        ){count dimensions{date}sum{visits}}}}}`,
    }),
  });
  if (!r.ok) throw new Error("cf graphql beacon " + r.status);
  const j = await r.json();
  if (j.errors?.length) throw new Error("cf gql beacon: " + j.errors[0].message);
  const groups = j.data?.viewer?.accounts?.[0]?.rumPageloadEventsAdaptiveGroups || [];
  return parseCfGroups(groups, (g) => ({ v: g.sum?.visits || 0, pv: g.count || 0 }));
}

// Try zone-level CDN analytics first (real traffic), fall back to JS beacon data
export async function cfTraffic(rawTag, hostname, env) {
  if (!env.CF_ANALYTICS_TOKEN) throw new Error("no cf token");
  try {
    const zoneId = await cfGetZoneTag(hostname, env);
    return await cfTrafficZone(zoneId, env);
  } catch {
    const siteTag = beaconToken(rawTag);
    if (!siteTag) throw new Error("no cf config");
    return await cfTrafficBeacon(siteTag, env);
  }
}

