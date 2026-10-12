// The Tiny Bird Gazette — a broadsheet-style daily built from live feeds.
// Served at /gazette. Every upstream fetch goes through Cloudflare's edge cache
// (cf.cacheTtl), so the presses only actually run every few minutes per colo.
//
// Sources (no API keys needed):
//   News       – BBC News section feeds + NPR News (RSS)
//   Comics     – xkcd (RSS) + a house strip drawn here in SVG
//   Obituaries – Wikipedia: Category:<year> deaths (most recently added) + "On this day" deaths
//   Help Wanted– We Work Remotely (RSS), falling back to HN Jobs (hnrss)
//   Weather    – Open-Meteo, using the reader's Cloudflare-provided location

const UA = "TinyBirdGazette/1.0 (+https://tinybirdbigdreams.com/gazette)";
const FEED_TTL = 900; // seconds
const FOUNDED = Date.UTC(2024, 0, 1);

const FEEDS = {
  world: { name: "BBC News", url: "https://feeds.bbci.co.uk/news/world/rss.xml" },
  nation: { name: "NPR", url: "https://feeds.npr.org/1001/rss.xml" },
  business: { name: "BBC News", url: "https://feeds.bbci.co.uk/news/business/rss.xml" },
  tech: { name: "BBC News", url: "https://feeds.bbci.co.uk/news/technology/rss.xml" },
  science: { name: "BBC News", url: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml" },
  arts: { name: "BBC News", url: "https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml" },
  sport: { name: "BBC Sport", url: "https://feeds.bbci.co.uk/sport/rss.xml" },
  xkcd: { name: "xkcd", url: "https://xkcd.com/rss.xml" },
};
const JOB_FEEDS = [
  { name: "We Work Remotely", url: "https://weworkremotely.com/remote-jobs.rss" },
  { name: "Hacker News Jobs", url: "https://hnrss.org/jobs" },
];

export async function handleGazette(request) {
  const cf = request.cf || {};
  const tz = cf.timezone || "America/New_York";
  const now = new Date();
  const day = localDate(now, tz);

  const [feeds, jobs, wiki, weather] = await Promise.all([
    fetchAllFeeds(),
    fetchJobs(),
    fetchWikipedia(day),
    fetchWeather(cf),
  ]);

  const body = renderPaper({ day, tz, cf, feeds, jobs, wiki, weather, now });
  return new Response(body, {
    headers: {
      "content-type": "text/html;charset=UTF-8",
      "cache-control": "public, max-age=300",
      "x-robots-tag": "noindex",
    },
  });
}

/* ------------------------------ fetching ------------------------------ */

async function getText(url, ttl = FEED_TTL, accept = "*/*") {
  try {
    const res = await fetch(url, {
      headers: { "user-agent": UA, accept },
      cf: { cacheTtl: ttl, cacheEverything: true },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    return await res.text();
  } catch {
    return null;
  }
}

async function getJSON(url, ttl = FEED_TTL) {
  const t = await getText(url, ttl, "application/json");
  if (!t) return null;
  try { return JSON.parse(t); } catch { return null; }
}

async function fetchAllFeeds() {
  const keys = Object.keys(FEEDS);
  const results = await Promise.all(keys.map((k) => getText(FEEDS[k].url)));
  const out = {};
  const seen = new Set();
  keys.forEach((k, i) => {
    const items = results[i] ? parseFeed(results[i]) : [];
    // A story can appear in several BBC section feeds; print it once.
    out[k] = items
      .filter((it) => {
        const key = (it.link || it.title).replace(/[?#].*$/, "");
        if (!it.title || seen.has(key)) return false;
        seen.add(key);
        return true;
      })
      .map((it) => ({ ...it, source: FEEDS[k].name }));
  });
  return out;
}

async function fetchJobs() {
  for (const f of JOB_FEEDS) {
    const xml = await getText(f.url);
    const items = xml ? parseFeed(xml) : [];
    if (items.length) return items.slice(0, 24).map((it) => ({ ...it, source: f.name }));
  }
  return [];
}

async function fetchWikipedia(day) {
  const mm = String(day.month).padStart(2, "0");
  const dd = String(day.day).padStart(2, "0");
  const recentURL =
    "https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2" +
    `&generator=categorymembers&gcmtitle=${encodeURIComponent(`Category:${day.year} deaths`)}` +
    "&gcmsort=timestamp&gcmdir=desc&gcmlimit=16&gcmnamespace=0" +
    "&prop=extracts|description|pageimages&exintro=1&explaintext=1&exsentences=3&exlimit=max" +
    "&piprop=thumbnail&pithumbsize=240&pilimit=max";
  const [recent, onThisDay] = await Promise.all([
    getJSON(recentURL, 3600),
    getJSON(`https://en.wikipedia.org/api/rest_v1/feed/onthisday/all/${mm}/${dd}`, 6 * 3600),
  ]);
  return {
    obits: parseRecentDeaths(recent),
    events: (onThisDay?.selected || onThisDay?.events || []).slice(0, 8),
    pastDeaths: (onThisDay?.deaths || []).slice(0, 8),
    births: (onThisDay?.births || []).slice(0, 6),
  };
}

export function parseRecentDeaths(json) {
  const pages = json?.query?.pages || [];
  return pages
    .filter((p) => p.extract && !p.missing)
    .map((p) => {
      const ex = p.extract.replace(/\s+/g, " ").trim();
      // "Jane Doe (March 3, 1940 – October 9, 2026) was ..." → lifespan + cleaner text
      const m = ex.match(/\(([^()]*?\b(\d{3,4}))\s*[–—-]\s*([^()]*?\b(\d{4}))\)/);
      let died = null;
      if (m) {
        const d = Date.parse(m[3].replace(/^.*?;\s*/, "").trim());
        died = Number.isNaN(d) ? null : d;
      }
      return {
        title: p.title,
        description: p.description || "",
        lifespan: m ? `${m[2]} – ${m[4]}` : "",
        died,
        text: m ? ex.replace(m[0], "").replace(/\s+,/g, ",").replace(/\s{2,}/g, " ") : ex,
        image: p.thumbnail?.source || null,
        link: `https://en.wikipedia.org/wiki/${encodeURIComponent(p.title.replace(/ /g, "_"))}`,
      };
    })
    .sort((a, b) => (b.died || 0) - (a.died || 0))
    .slice(0, 9);
}

async function fetchWeather(cf) {
  const lat = Number(cf.latitude) || 40.71;
  const lon = Number(cf.longitude) || -74.01;
  const city = cf.latitude ? cf.city || cf.region || "Your Town" : "New York";
  const imperial = !cf.country || ["US", "LR", "MM"].includes(cf.country);
  const url =
    `https://api.open-meteo.com/v1/forecast?latitude=${lat.toFixed(2)}&longitude=${lon.toFixed(2)}` +
    "&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m" +
    "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset" +
    "&forecast_days=5&timezone=auto" +
    (imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "");
  const data = await getJSON(url, 1800);
  if (!data?.current) return { city, error: true };
  return { city, imperial, current: data.current, daily: data.daily };
}

/* ------------------------------ feed parsing ------------------------------ */

const NAMED = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", rsquo: "’", lsquo: "‘",
  rdquo: "”", ldquo: "“", ndash: "–", mdash: "—", hellip: "…", eacute: "é", copy: "©",
};

export function decodeEntities(s) {
  return String(s).replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e) => {
    if (e[0] === "#") {
      const n = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : "";
    }
    return NAMED[e.toLowerCase()] ?? m;
  });
}

function unCDATA(s) {
  return s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
}

function tag(block, name) {
  const re = new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, "i");
  const m = block.match(re);
  return m ? unCDATA(m[1]).trim() : "";
}

function attr(block, tagName, attrName) {
  const re = new RegExp(`<${tagName}\\b[^>]*\\b${attrName}=["']([^"']+)["']`, "i");
  const m = block.match(re);
  return m ? decodeEntities(m[1]) : "";
}

export function stripTags(html) {
  // Feeds often double-encode HTML, so decode → strip → decode.
  return decodeEntities(
    decodeEntities(html)
      .replace(/<(script|style)[\s\S]*?<\/\1>/gi, "")
      .replace(/<[^>]+>/g, " ")
  )
    .replace(/\s+/g, " ")
    .trim();
}

export function parseFeed(xml) {
  const blocks = xml.match(/<(item|entry)\b[\s\S]*?<\/\1>/gi) || [];
  return blocks.map((b) => {
    const rawDesc = tag(b, "description") || tag(b, "summary") || tag(b, "content");
    const rawContent = tag(b, "content:encoded") || rawDesc;
    let link = stripTags(tag(b, "link")) || attr(b, "link", "href");
    let image =
      attr(b, "media:thumbnail", "url") ||
      attr(b, "media:content", "url") ||
      (/<enclosure\b[^>]*type=["']image/i.test(b) ? attr(b, "enclosure", "url") : "");
    if (!image) {
      const m = decodeEntities(rawContent).match(/<img\b[^>]*\bsrc=["']([^"']+)["']/i);
      if (m) image = decodeEntities(m[1]);
    }
    // BBC hands out 240px thumbnails; ask for a print-worthy size instead.
    if (image) image = image.replace(/(ichef\.bbci\.co\.uk\/[^/]+\/[^/]+\/)240\//, "$1800/");
    const decodedContent = decodeEntities(rawContent);
    const imgTitle = (decodedContent.match(/<img\b[^>]*\btitle=["']([^"']*)["']/i) || [])[1];
    const imgAlt = (decodedContent.match(/<img\b[^>]*\balt=["']([^"']*)["']/i) || [])[1];
    return {
      title: stripTags(tag(b, "title")),
      link: /^https?:\/\//i.test(link) ? link : "",
      summary: stripTags(rawDesc),
      image: /^https?:\/\//i.test(image || "") ? image : null,
      imageTitle: imgTitle ? decodeEntities(imgTitle) : "",
      imageAlt: imgAlt ? decodeEntities(imgAlt) : "",
      date: Date.parse(stripTags(tag(b, "pubDate") || tag(b, "published") || tag(b, "updated") || tag(b, "dc:date"))) || null,
      region: stripTags(tag(b, "region")),
    };
  });
}

/* ------------------------------ helpers ------------------------------ */

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

function trunc(s, n) {
  s = String(s || "");
  if (s.length <= n) return s;
  return s.slice(0, s.lastIndexOf(" ", n) > n * 0.6 ? s.lastIndexOf(" ", n) : n).replace(/[,;:.\s]+$/, "") + "…";
}

function localDate(now, tz) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", { timeZone: tz, year: "numeric", month: "numeric", day: "numeric", weekday: "long" })
      .formatToParts(now)
      .map((p) => [p.type, p.value])
  );
  const year = +parts.year, month = +parts.month, d = +parts.day;
  return {
    year, month, day: d, weekday: parts.weekday,
    long: new Intl.DateTimeFormat("en-US", { timeZone: tz, dateStyle: "full" }).format(now),
    seed: year * 10000 + month * 100 + d,
  };
}

function roman(n) {
  const map = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
  let out = "";
  for (const [v, s] of map) while (n >= v) { out += s; n -= v; }
  return out;
}

function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function timeAgo(ts, now) {
  if (!ts) return "";
  const m = Math.round((now - ts) / 60000);
  if (m < 60) return `${Math.max(m, 1)} min. ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h} hr. ago`;
  return `${Math.round(h / 24)} days ago`;
}

const WX = [
  [[0], "Clear", "☀"], [[1, 2], "Partly Cloudy", "⛅"], [[3], "Overcast", "☁"],
  [[45, 48], "Fog", "≋"], [[51, 53, 55, 56, 57], "Drizzle", "☂"], [[61, 63, 65, 66, 67], "Rain", "☂"],
  [[71, 73, 75, 77], "Snow", "❄"], [[80, 81, 82], "Showers", "☂"], [[85, 86], "Snow Showers", "❄"],
  [[95, 96, 99], "Thunderstorms", "⚡"],
];
function wx(code) {
  const hit = WX.find(([codes]) => codes.includes(code));
  return hit ? { word: hit[1], icon: hit[2] } : { word: "Changeable", icon: "~" };
}

/* ------------------------------ rendering ------------------------------ */

function headlineLink(it, cls = "") {
  const t = esc(it.title);
  return it.link ? `<a class="${cls}" href="${esc(it.link)}" target="_blank" rel="noopener">${t}</a>` : t;
}

function figure(it, cls = "") {
  if (!it.image) return "";
  return `<figure class="photo ${cls}"><div class="halftone"><img src="${esc(it.image)}" alt="" loading="lazy" referrerpolicy="no-referrer"></div><figcaption>${esc(trunc(it.title, 90))} <span class="credit">— ${esc(it.source)}</span></figcaption></figure>`;
}

function story(it, { size = "md", summaryLen = 320, withImage = false, now }) {
  if (!it) return "";
  return `<article class="story story-${size}">
    <h3 class="hed">${headlineLink(it)}</h3>
    <div class="byline">From the wires of ${esc(it.source)}${it.date ? ` · ${esc(timeAgo(it.date, now))}` : ""}</div>
    ${withImage ? figure(it) : ""}
    <p>${esc(trunc(it.summary || "Details to follow in later editions.", summaryLen))}</p>
  </article>`;
}

function briefs(items, now) {
  if (!items.length) return `<p class="wire-down">The wire for this desk is silent. Our correspondents are presumed to be at lunch.</p>`;
  return items
    .map((it) => `<div class="brief"><h4>${headlineLink(it)}</h4><p>${esc(trunc(it.summary, 170))}${it.date ? ` <span class="ago">(${esc(timeAgo(it.date, now))})</span>` : ""}</p></div>`)
    .join("");
}

function sheetHead(folio, section, day) {
  return `<header class="folio"><span>${esc(folio)}</span><span class="folio-title">THE TINY BIRD GAZETTE</span><span>${esc(day.long)}</span></header>
  <h2 class="section-flag">${esc(section)}</h2>`;
}

function renderPaper({ day, cf, feeds, jobs, wiki, weather, now }) {
  const no = Math.floor((Date.UTC(day.year, day.month - 1, day.day) - FOUNDED) / 86400000) + 1;
  const vol = roman(day.year - 2023);
  const pick = (arr, n) => (arr || []).slice(0, n);

  // Front page: lead = the first world story that has art.
  const world = feeds.world || [];
  const leadIdx = Math.max(0, world.findIndex((it) => it.image));
  const lead = world[leadIdx];
  const worldRest = world.filter((_, i) => i !== leadIdx);
  const nation = feeds.nation || [];
  const cw = weather.current ? wx(weather.current.weather_code) : null;
  const unit = weather.imperial ? "°F" : "°C";

  const front = `
  <section class="sheet front" id="a1">
    <div class="ears">
      <div class="ear">
        ${cw
          ? `<b>${esc(weather.city).toUpperCase()} WEATHER</b><div class="ear-big"><span class="glyph">${cw.icon}\uFE0E</span> ${Math.round(weather.current.temperature_2m)}${unit}</div>${esc(cw.word)}. High ${Math.round(weather.daily.temperature_2m_max[0])}, low ${Math.round(weather.daily.temperature_2m_min[0])}. <a href="#weather">Report, Page F1</a>`
          : `<b>WEATHER</b><div class="ear-big">?</div>The weather office did not answer the telephone.`}
      </div>
      <div class="masthead">
        <div class="motto">“All the News That Fits in a Nest”</div>
        <h1>The Tiny Bird Gazette</h1>
      </div>
      <div class="ear right">
        <b>LATE CITY EDITION</b><div class="ear-big">10¢</div>Comics, obituaries &amp; classifieds inside.
      </div>
    </div>
    <div class="dateline">
      <span>VOL. ${esc(vol)} · No. ${no.toLocaleString("en-US")}</span>
      <span>${esc(day.long.toUpperCase())}</span>
      <span>${esc((cf.city || "Everywhere").toUpperCase())} EDITION</span>
    </div>

    <div class="front-grid">
      <div class="lead">
        ${lead ? `<div class="kicker">World</div><h2 class="lead-hed">${headlineLink(lead)}</h2>
        <div class="deck">${esc(trunc(lead.summary, 160))}</div>
        <div class="byline">From the wires of ${esc(lead.source)}${lead.date ? ` · ${esc(timeAgo(lead.date, now))}` : ""}</div>
        ${figure(lead, "lead-photo")}
        <div class="cols cols-2 dropcap"><p>${esc(lead.summary || "")}</p>${pick(worldRest, 3).map((it) => `<p><b>${headlineLink(it)}.</b> ${esc(trunc(it.summary, 220))}</p>`).join("")}<p class="jump">Continued on Page A2</p></div>`
          : `<h2 class="lead-hed">Presses Roll on a Quiet Wire</h2><p class="wire-down">No world news reached the newsroom in time for this edition.</p>`}
      </div>
      <aside class="side">
        <div class="kicker">The Nation</div>
        ${story(nation[0], { size: "lg", summaryLen: 260, withImage: true, now })}
        <hr class="rule">
        ${story(nation[1], { size: "sm", summaryLen: 180, now })}
        <div class="box index">
          <h4>INSIDE TODAY</h4>
          <ul>
            <li><a href="#a2">World &amp; Nation</a><span>A2</span></li>
            <li><a href="#b1">Business &amp; Technology</a><span>B1</span></li>
            <li><a href="#c1">Arts &amp; Sport</a><span>C1</span></li>
            <li><a href="#d1">The Funny Pages</a><span>D1</span></li>
            <li><a href="#e1">Obituaries</a><span>E1</span></li>
            <li><a href="#f1">Classifieds · Help Wanted</a><span>F1</span></li>
          </ul>
        </div>
      </aside>
    </div>
    <div class="fold" aria-hidden="true"></div>
    <div class="below-fold cols cols-4">
      ${pick(worldRest.slice(3), 2).concat(pick(nation.slice(2), 2)).map((it) => story(it, { size: "sm", summaryLen: 200, now })).join("")}
    </div>
    ${almanac(wiki.events, day)}
  </section>`;

  const a2 = `
  <section class="sheet" id="a2">
    ${sheetHead("A2", "World & Nation", day)}
    <div class="cols cols-3">
      <div class="kicker">Abroad</div>
      ${briefs(pick(worldRest.slice(5), 10), now)}
      <div class="kicker">At Home</div>
      ${briefs(pick(nation.slice(4), 10), now)}
    </div>
  </section>`;

  const b1 = `
  <section class="sheet" id="b1">
    ${sheetHead("B1", "Business & Technology", day)}
    <div class="split">
      <div>${story((feeds.business || [])[0], { size: "lg", withImage: true, now })}<div class="cols cols-2">${briefs(pick((feeds.business || []).slice(1), 6), now)}</div></div>
      <div>${story((feeds.tech || [])[0], { size: "lg", withImage: true, now })}<div class="cols cols-2">${briefs(pick((feeds.tech || []).slice(1), 6), now)}</div></div>
    </div>
    <hr class="rule thick">
    <div class="kicker">Science &amp; Environment</div>
    <div class="cols cols-4">${briefs(pick(feeds.science, 8), now)}</div>
  </section>`;

  const c1 = `
  <section class="sheet" id="c1">
    ${sheetHead("C1", "Arts & Leisure · Sport", day)}
    <div class="split">
      <div><div class="kicker">The Arts</div>${story((feeds.arts || [])[0], { size: "lg", withImage: true, now })}<div class="cols cols-2">${briefs(pick((feeds.arts || []).slice(1), 6), now)}</div></div>
      <div><div class="kicker">Sport</div>${story((feeds.sport || [])[0], { size: "lg", withImage: true, now })}<div class="cols cols-2">${briefs(pick((feeds.sport || []).slice(1), 8), now)}</div></div>
    </div>
  </section>`;

  const d1 = `
  <section class="sheet funnies" id="d1">
    ${sheetHead("D1", "The Funny Pages", day)}
    ${houseStrip(day)}
    ${xkcdStrip((feeds.xkcd || [])[0])}
    <div class="split three">
      ${horoscopes(day)}
      ${jumble(day)}
      ${advice(day)}
    </div>
  </section>`;

  const e1 = `
  <section class="sheet obits" id="e1">
    ${sheetHead("E1", "Obituaries", day)}
    <p class="obit-intro">Notable lives recently concluded, as recorded by the editors of Wikipedia.</p>
    <div class="cols cols-3">
      ${wiki.obits.length
        ? wiki.obits.map((o) => `<article class="obit">
            ${o.image ? `<div class="halftone portrait"><img src="${esc(o.image)}" alt="" loading="lazy" referrerpolicy="no-referrer"></div>` : ""}
            <h3><a href="${esc(o.link)}" target="_blank" rel="noopener">${esc(o.title)}</a></h3>
            ${o.lifespan ? `<div class="lifespan">${esc(o.lifespan)}</div>` : ""}
            ${o.description ? `<div class="obit-desc">${esc(o.description)}</div>` : ""}
            <p>${esc(trunc(o.text, 420))}</p>
          </article>`).join("")
        : `<p class="wire-down">The obituary desk has received no notices for this edition.</p>`}
    </div>
    <hr class="rule thick">
    <div class="kicker">Remembered On This Day</div>
    <div class="cols cols-4 remembered">
      ${wiki.pastDeaths.map((d) => `<p><b>${esc(d.year)}</b> — ${esc(d.text)}</p>`).join("") || `<p class="wire-down">The archive room is locked.</p>`}
    </div>
  </section>`;

  const f1 = `
  <section class="sheet classifieds" id="f1">
    ${sheetHead("F1", "Classified Advertisements", day)}
    <div class="classified-grid">
      <div class="help-wanted">
        <h3 class="class-head">HELP WANTED</h3>
        <div class="cols cols-3 ads">
          ${jobs.length
            ? jobs.map((j) => {
                const [co, ...role] = j.title.split(/:\s+/);
                const heading = role.length ? role.join(": ") : j.title;
                return `<div class="ad"><b>${esc(heading.toUpperCase())}</b>${role.length ? ` — ${esc(co)}.` : ""} ${esc(trunc(j.summary, 140))}${j.region ? ` <i>${esc(j.region)}.</i>` : ""} ${j.link ? `<a href="${esc(j.link)}" target="_blank" rel="noopener">Apply ›</a>` : ""}</div>`;
              }).join("")
            : `<div class="ad"><b>NEWSPAPER BOY/GIRL</b> — The job wire is down. Inquire within.</div>`}
        </div>
        <p class="ads-credit">Listings via ${esc(jobs[0]?.source || "the job wire")}.</p>
      </div>
      <aside>
        ${weatherBox(weather)}
        <div class="box house-ad">
          <div class="ha-small">ADVERTISEMENT</div>
          <div class="ha-big">TINY BIRD<br>BIG DREAMS</div>
          <p>Small studio. Large ambitions. Apps &amp; websites built with care.</p>
          <a href="/">Visit the Studio ›</a>
        </div>
        ${personals(day)}
      </aside>
    </div>
  </section>`;

  return pageShell(front + a2 + b1 + c1 + d1 + e1 + f1, day);
}

function almanac(events, day) {
  if (!events?.length) return "";
  return `<div class="almanac box"><h4>ON THIS DAY · ${esc(day.long.split(",").slice(1).join(",").replace(/,\s*\d{4}$/, "").trim().toUpperCase())}</h4>
    <div class="cols cols-4">${events.slice(0, 6).map((e) => `<p><b>${esc(e.year)}</b> — ${esc(trunc(e.text, 160))}</p>`).join("")}</div></div>`;
}

function weatherBox(w) {
  if (!w.daily) return `<div class="box weather" id="weather"><h4>THE WEATHER</h4><p>Forecast unavailable. Look out the window.</p></div>`;
  const unit = w.imperial ? "°" : "°";
  const rows = w.daily.time.map((t, i) => {
    const d = new Date(t + "T12:00:00Z").toLocaleDateString("en-US", { weekday: "short", timeZone: "UTC" });
    const c = wx(w.daily.weather_code[i]);
    return `<tr><td>${esc(d)}</td><td class="wx-icon">${c.icon}\uFE0E</td><td>${esc(c.word)}</td><td>${Math.round(w.daily.temperature_2m_max[i])}${unit}/${Math.round(w.daily.temperature_2m_min[i])}${unit}</td><td>${w.daily.precipitation_probability_max?.[i] ?? "—"}%</td></tr>`;
  }).join("");
  const sun = (s) => (s ? s.split("T")[1] : "—");
  return `<div class="box weather" id="weather"><h4>THE WEATHER · ${esc(w.city.toUpperCase())}</h4>
    <p class="wx-now">Now: ${Math.round(w.current.temperature_2m)}${w.imperial ? "°F" : "°C"}, ${esc(wx(w.current.weather_code).word.toLowerCase())}. Humidity ${w.current.relative_humidity_2m}%. Wind ${Math.round(w.current.wind_speed_10m)} ${w.imperial ? "mph" : "km/h"}.</p>
    <table><thead><tr><th>Day</th><th></th><th>Sky</th><th>Hi/Lo</th><th>Rain</th></tr></thead><tbody>${rows}</tbody></table>
    <p class="wx-sun">Sunrise ${esc(sun(w.daily.sunrise[0]))} · Sunset ${esc(sun(w.daily.sunset[0]))}</p></div>`;
}

/* ------------------------------ the funny pages ------------------------------ */

const GAGS = [
  ["Today I fly to the moon!", "That's 238,900 miles.", "...After a snack."],
  ["I read the whole newspaper.", "Even the classifieds?", "I applied to be a weathervane."],
  ["Big dreams need big wings.", "Your wings are tiny.", "Then I'll dream in installments."],
  ["The early bird gets the worm!", "...", "Relax. I'm sleeping in today."],
  ["The forecast says wind.", "Bad for flying?", "Free ride!"],
  ["I'm writing my memoirs.", "You're three weeks old.", "Volume One: The Egg Years."],
  ["Stop the presses!", "What happened?!", "I found a crumb."],
  ["I'm going to start a business.", "Doing what?", "Tweeting. Professionally."],
  ["Do you ever feel small?", "I'm a worm.", "Good talk."],
];

function bird(x, y, flip = false) {
  const s = flip ? -1 : 1;
  return `<g transform="translate(${x} ${y}) scale(${s} 1)">
    <ellipse cx="0" cy="0" rx="26" ry="20" class="ink-fill-light"/>
    <circle cx="18" cy="-18" r="13" class="ink-fill-light"/>
    <circle cx="22" cy="-20" r="2.6" class="ink"/>
    <path d="M30 -18 L42 -14 L30 -11 Z" class="ink"/>
    <path d="M-12 -4 Q-2 -16 10 -4 Q-2 6 -12 -4 Z" class="ink-fill-light"/>
    <path d="M-24 2 L-38 -6 L-34 6 Z" class="ink-fill-light"/>
    <path d="M-6 19 L-8 30 M6 19 L8 30" class="ink-line"/>
  </g>`;
}

function worm(x, y) {
  return `<g transform="translate(${x} ${y})">
    <path d="M-30 10 Q-20 -6 -10 10 T10 10 T26 0" class="worm"/>
    <circle cx="27" cy="-1" r="2.2" class="ink"/>
  </g>`;
}

function bubble(x, y, text, tailX) {
  const words = text.split(" ");
  const lines = [];
  let cur = "";
  for (const w of words) {
    if ((cur + " " + w).trim().length > 17) { lines.push(cur.trim()); cur = w; } else cur += " " + w;
  }
  lines.push(cur.trim());
  const h = 14 + lines.length * 15;
  const w = 150;
  return `<g>
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="14" class="bubble"/>
    <path d="M${tailX - 6} ${y + h - 1} L${tailX} ${y + h + 16} L${tailX + 8} ${y + h - 1}" class="bubble-tail"/>
    <text x="${x + w / 2}" y="${y + 19}" text-anchor="middle" class="letters">${lines.map((l, i) => `<tspan x="${x + w / 2}" dy="${i ? 15 : 0}">${esc(l)}</tspan>`).join("")}</text>
  </g>`;
}

function houseStrip(day) {
  const gag = GAGS[day.seed % GAGS.length];
  const speakers = [0, 1, 0]; // 0 = bird, 1 = worm
  const panels = gag.map((line, i) => {
    const px = i * 240;
    const who = speakers[i];
    return `<g transform="translate(${px} 0)">
      <rect x="4" y="4" width="228" height="182" class="panel"/>
      <path d="M4 160 L232 160" class="ink-line thin"/>
      ${bird(70, 135)}
      ${worm(175, 150)}
      ${bubble(who ? 70 : 12, 14, line, who ? 190 : 90)}
    </g>`;
  }).join("");
  return `<figure class="strip">
    <div class="strip-title"><span>TINY BIRD</span><span class="strip-by">by the Gazette Art Dept.</span></div>
    <svg viewBox="0 0 720 190" role="img" aria-label="Tiny Bird comic strip: ${esc(gag.join(" / "))}">${panels}</svg>
  </figure>`;
}

function xkcdStrip(it) {
  if (!it?.image) return "";
  return `<figure class="strip xkcd">
    <div class="strip-title"><span>${esc((it.title || "xkcd").toUpperCase())}</span><span class="strip-by">by Randall Munroe · <a href="${esc(it.link)}" target="_blank" rel="noopener">xkcd.com</a></span></div>
    <img src="${esc(it.image)}" alt="${esc(it.imageAlt || it.title)}" title="${esc(it.imageTitle)}" loading="lazy">
    ${it.imageTitle ? `<figcaption>${esc(it.imageTitle)}</figcaption>` : ""}
  </figure>`;
}

const SIGNS = [
  ["Aries", "♈"], ["Taurus", "♉"], ["Gemini", "♊"], ["Cancer", "♋"], ["Leo", "♌"], ["Virgo", "♍"],
  ["Libra", "♎"], ["Scorpio", "♏"], ["Sagittarius", "♐"], ["Capricorn", "♑"], ["Aquarius", "♒"], ["Pisces", "♓"],
];
const FORTUNES = [
  "A small idea pecks at the shell. Let it out.",
  "Someone is reading over your shoulder. Turn the page slowly.",
  "Avoid large decisions before your second cup of coffee.",
  "A worm of opportunity surfaces after the rain. Be early.",
  "The crossword is not out to get you. Probably.",
  "Your nest is cozier than you think. Invite a friend.",
  "An old letter, or an old email, deserves a reply.",
  "Fly a different route home today.",
  "Your lucky number is the page you are reading.",
  "Trade one worry for one walk.",
  "A tiny step today is a big leap by Thursday.",
  "Do not argue with a pigeon. It cannot be won.",
  "Finances look up. So does the sky — look at it.",
  "Say yes to the second invitation.",
  "Tidy one drawer. The rest of life will feel lighter.",
  "Someone admires your plumage. Accept the compliment.",
];
function horoscopes(day) {
  const r = rng(day.seed);
  const pool = [...FORTUNES];
  return `<div class="box horoscope"><h4>STARGAZER</h4>${SIGNS.map(([n, g]) => {
    const f = pool.splice(Math.floor(r() * pool.length), 1)[0] || FORTUNES[0];
    if (!pool.length) pool.push(...FORTUNES);
    return `<p><b><span class="glyph">${g}\uFE0E</span> ${esc(n.toUpperCase())}</b> ${esc(f)}</p>`;
  }).join("")}<p class="fine">For entertainment only. The stars decline all liability.</p></div>`;
}

const JUMBLE_WORDS = ["FEATHER", "MORNING", "PRESS", "HEADLINE", "NEST", "SPARROW", "COLUMN", "EDITION", "PIGEON", "BREEZE", "PAPER", "INKWELL", "CANARY", "TYPESET", "ROBIN", "GAZETTE", "WEATHER", "PUZZLE", "COMICS", "REPORT", "FINCH", "COFFEE", "SUNDAY", "SCOOP"];
function jumble(day) {
  const r = rng(day.seed * 7 + 3);
  const words = [...JUMBLE_WORDS].sort(() => r() - 0.5).slice(0, 5);
  const scramble = (w) => {
    let s = w;
    for (let tries = 0; tries < 10 && s === w; tries++) s = [...w].sort(() => r() - 0.5).join("");
    return s;
  };
  return `<div class="box jumble"><h4>JUMBLE</h4><p class="fine">Unscramble these newsroom words.</p>
    ${words.map((w) => `<div class="tiles">${[...scramble(w)].map((c) => `<span>${c}</span>`).join("")}</div>`).join("")}
    <p class="answers">Answers: ${words.join(", ")}</p></div>`;
}

const ADVICE = [
  ["Dear Tiny Bird,", "My neighbor's cat stares at me all day. What should I do?", "— Watched in Wisconsin", "Dear Watched: Stare back. Then move your feeder."],
  ["Dear Tiny Bird,", "I have big dreams but small wings. Is it hopeless?", "— Grounded in Georgia", "Dear Grounded: Every big flight is just a lot of small flaps. Start flapping."],
  ["Dear Tiny Bird,", "My family says I spend too much time reading the paper.", "— Inky in Idaho", "Dear Inky: Tell them the comics are research."],
  ["Dear Tiny Bird,", "How do I ask my boss for a raise?", "— Underpaid in Utah", "Dear Underpaid: Bring numbers, bring a plan, and bring a muffin."],
  ["Dear Tiny Bird,", "I keep starting projects and never finishing them.", "— Half-Built in Houston", "Dear Half-Built: Finish the smallest one this week. Momentum is a habit."],
];
function advice(day) {
  const [salute, q, sig, a] = ADVICE[day.seed % ADVICE.length];
  return `<div class="box advice"><h4>ASK TINY BIRD</h4><p><i>${esc(salute)}</i> ${esc(q)}</p><p class="sig">${esc(sig)}</p><p>${esc(a)}</p></div>`;
}

const PERSONALS = [
  "LOST: one sunflower seed, sentimental value. Last seen near the birdbath. Reward.",
  "FOUND: a perfectly good twig. Owner may claim with description.",
  "SWF (Small Winged Female) seeks companion for long flights south. Must enjoy suet.",
  "FOR SALE: nest, lightly used, two-egg capacity, great views. Motivated seller.",
  "WANTED: early riser to deliver the Gazette. Must own bicycle and good aim.",
  "TO THE BLUE JAY on Elm St.: we know it was you. Return the bread.",
  "PIANO LESSONS for beginners. Patience guaranteed. No woodpeckers, please.",
  "GARAGE SALE Saturday. Bird feeders, birdhouses, one slightly confused scarecrow.",
];
function personals(day) {
  const r = rng(day.seed + 99);
  const picks = [...PERSONALS].sort(() => r() - 0.5).slice(0, 5);
  return `<div class="box personals"><h4>LOST · FOUND · PERSONALS</h4>${picks.map((p) => `<p>${esc(p)}</p>`).join("")}</div>`;
}

/* ------------------------------ the page ------------------------------ */

function pageShell(sheets, day) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>The Tiny Bird Gazette — ${esc(day.long)}</title>
<meta name="description" content="A daily broadsheet built from live news feeds: news, comics, obituaries and help wanted.">
<link rel="icon" href="/favicon.ico">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=UnifrakturMaguntia&family=Old+Standard+TT:ital,wght@0,400;0,700;1,400&family=Playfair+Display:ital,wght@0,700;0,900;1,700&family=Patrick+Hand&display=swap" rel="stylesheet">
<style>${CSS}</style>
</head>
<body>
<nav class="desk-nav" aria-label="Sections">
  <a href="#a1">A1 Front</a><a href="#a2">A2 World</a><a href="#b1">B1 Business</a><a href="#c1">C1 Arts &amp; Sport</a><a href="#d1">D1 Comics</a><a href="#e1">E1 Obits</a><a href="#f1">F1 Classifieds</a>
</nav>
<main>${sheets}</main>
<footer class="desk-foot">Printed fresh from the wires of BBC News, NPR, xkcd, Wikipedia, Open-Meteo and the job boards. Headlines link to the original reporting. <a href="/">Tiny Bird, Big Dreams</a></footer>
</body>
</html>`;
}

const PAPER_NOISE = `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='260' height='260'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 .35  0 0 0 0 .27  0 0 0 0 .15  0 0 0 .10 0'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>")`;

const CSS = `
:root{
  --paper:#f3ead2; --paper-edge:#e2d3a9; --ink:#1d1a15; --ink-soft:#3b352c; --rule:#2a251d;
  --desk:#3a2f25; --desk-2:#2a221b; --accent:#8a1c12;
}
@media (prefers-color-scheme: dark){ :root{ --desk:#17130f; --desk-2:#0d0b09; } }
*{box-sizing:border-box}
html{scroll-behavior:smooth;background:var(--desk-2)}
body{margin:0;background:radial-gradient(ellipse at top,var(--desk),var(--desk-2)) fixed;color:var(--ink);font-family:"Old Standard TT",Georgia,"Times New Roman",serif;font-size:15px;line-height:1.42;-webkit-font-smoothing:antialiased}
a{color:inherit;text-decoration:none}
a:hover{text-decoration:underline;text-decoration-thickness:1px}
.desk-nav{position:sticky;top:0;z-index:10;display:flex;gap:4px;justify-content:center;flex-wrap:wrap;padding:8px 16px;background:rgba(20,16,12,.88);backdrop-filter:blur(4px);font:600 12px/1 "Old Standard TT",serif;letter-spacing:.08em;text-transform:uppercase}
.desk-nav a{color:#efe3c4;padding:6px 10px;border:1px solid rgba(239,227,196,.25);border-radius:2px}
.desk-nav a:hover{background:rgba(239,227,196,.12);text-decoration:none}
main{padding:28px 16px 8px}
.sheet{position:relative;max-width:1180px;margin:0 auto 42px;padding:30px 40px 40px;background-color:var(--paper);background-image:${PAPER_NOISE},radial-gradient(circle at 12% 18%,rgba(160,120,50,.10) 0 40px,transparent 90px),radial-gradient(circle at 88% 76%,rgba(150,110,40,.09) 0 30px,transparent 110px);box-shadow:inset 0 0 90px rgba(150,110,40,.28),inset 0 0 6px rgba(120,90,30,.4),0 18px 40px rgba(0,0,0,.45),0 2px 4px rgba(0,0,0,.35);text-shadow:0 0 .35px rgba(29,26,21,.55);scroll-margin-top:60px}
.sheet:nth-child(even){transform:rotate(.25deg)}
.sheet:nth-child(odd):not(.front){transform:rotate(-.2deg)}
.fold{position:relative;height:0;margin:22px -40px;border-top:1px solid rgba(80,60,20,.12);box-shadow:0 0 18px 6px rgba(120,90,30,.10)}

/* masthead */
.ears{display:grid;grid-template-columns:170px 1fr 170px;gap:16px;align-items:center;border-bottom:1px solid var(--rule);padding-bottom:10px}
.ear{border:1px solid var(--rule);padding:8px 10px;font-size:11.5px;line-height:1.35;text-align:center}
.ear b{display:block;font-size:10.5px;letter-spacing:.1em;border-bottom:1px solid var(--rule);padding-bottom:4px;margin-bottom:4px}
.ear-big{font:900 26px/1.1 "Playfair Display",serif;margin:2px 0}
.ear a{text-decoration:underline}
.masthead{text-align:center}
.masthead h1{margin:0;font-family:"UnifrakturMaguntia",serif;font-weight:400;font-size:clamp(38px,7.4vw,92px);line-height:1;letter-spacing:.01em}
.motto{font-style:italic;font-size:13px;margin-bottom:4px}
.dateline{display:flex;justify-content:space-between;gap:12px;border-top:3px double var(--rule);border-bottom:3px double var(--rule);margin-top:3px;padding:5px 2px;font-size:11.5px;font-weight:700;letter-spacing:.09em}

/* sections */
.folio{display:flex;justify-content:space-between;font-size:11px;letter-spacing:.08em;border-bottom:1px solid var(--rule);padding-bottom:5px}
.folio-title{font-family:"UnifrakturMaguntia",serif;letter-spacing:0;font-size:16px}
.section-flag{font:900 clamp(30px,4.6vw,52px)/1 "Playfair Display",serif;text-align:center;margin:12px 0 10px;padding-bottom:10px;border-bottom:3px double var(--rule);letter-spacing:-.01em}
.kicker{font-size:11px;font-weight:700;letter-spacing:.18em;text-transform:uppercase;border-bottom:1px solid var(--rule);margin:8px 0 8px;padding-bottom:3px;column-span:all}
.byline{font-size:10.5px;letter-spacing:.1em;text-transform:uppercase;margin:4px 0 8px;color:var(--ink-soft)}
.deck{font:italic 700 17px/1.3 "Playfair Display",serif;margin:6px 0}
.hed{font-family:"Playfair Display",serif;font-weight:900;line-height:1.08;margin:4px 0 2px}
.story-lg .hed{font-size:26px}
.story-md .hed{font-size:20px}
.story-sm .hed{font-size:17px}
.story p,.brief p,.cols p{margin:0 0 .6em;text-align:justify;hyphens:auto}
.story{break-inside:avoid;margin-bottom:10px}

.front-grid{display:grid;grid-template-columns:2fr 1fr;gap:26px;margin-top:16px}
.lead-hed{font:900 clamp(30px,4.4vw,50px)/1.02 "Playfair Display",serif;margin:2px 0 4px;letter-spacing:-.01em}
.side{border-left:1px solid var(--rule);padding-left:22px}
.cols{column-gap:24px;column-rule:1px solid rgba(42,37,29,.6)}
.cols-2{column-count:2}.cols-3{column-count:3}.cols-4{column-count:4}
.dropcap > p:first-child::first-letter{float:left;font:900 64px/.8 "Playfair Display",serif;padding:6px 6px 0 0}
.jump{font-style:italic;font-size:12px;text-align:right!important}
.split{display:grid;grid-template-columns:1fr 1fr;gap:28px}
.split > div + div{border-left:1px solid var(--rule);padding-left:28px}
.split.three{grid-template-columns:1.2fr 1fr 1fr;gap:20px;margin-top:22px}
.split.three > div + div{border-left:none;padding-left:16px}
.brief{break-inside:avoid;margin-bottom:8px;padding-bottom:6px;border-bottom:1px dotted rgba(42,37,29,.5)}
.brief h4{font:700 15px/1.15 "Playfair Display",serif;margin:0 0 3px}
.brief p{font-size:13.5px}
.ago{font-size:11px;color:var(--ink-soft);white-space:nowrap}
.rule{border:0;border-top:1px solid var(--rule);margin:12px 0}
.rule.thick{border-top:3px double var(--rule);margin:20px 0 6px}
.wire-down{font-style:italic;color:var(--ink-soft)}
.below-fold .story{margin-bottom:0}

/* photos: grayscale + halftone dots */
.photo{margin:8px 0 10px;break-inside:avoid}
.halftone{position:relative;overflow:hidden;background:#ddd2b6}
.halftone img{display:block;width:100%;height:auto;filter:grayscale(1) contrast(1.25) brightness(1.04) sepia(.18);mix-blend-mode:multiply}
.halftone::after{content:"";position:absolute;inset:0;background:radial-gradient(circle,rgba(29,26,21,.55) 32%,transparent 36%) 0 0/3px 3px;mix-blend-mode:multiply;opacity:.38;pointer-events:none}
figcaption{font-size:11.5px;font-style:italic;margin-top:4px;border-bottom:1px solid rgba(42,37,29,.4);padding-bottom:4px}
.credit{font-style:normal;font-size:10px;letter-spacing:.06em;text-transform:uppercase}

.box{border:1px solid var(--rule);outline:3px double var(--rule);outline-offset:-7px;padding:16px 16px 12px;margin:16px 0;break-inside:avoid}
.box h4{margin:0 0 8px;text-align:center;font:900 15px/1 "Playfair Display",serif;letter-spacing:.12em;border-bottom:1px solid var(--rule);padding-bottom:6px}
.index ul{list-style:none;margin:0;padding:0;font-size:13.5px}
.index li{display:flex;justify-content:space-between;border-bottom:1px dotted rgba(42,37,29,.5);padding:3px 0}
.almanac{margin-top:24px}
.almanac p{font-size:13px}

/* funny pages */
.strip{margin:14px 0 22px;border:2px solid var(--ink);padding:8px 10px 10px;background:rgba(255,255,255,.18)}
.strip-title{display:flex;justify-content:space-between;align-items:baseline;border-bottom:2px solid var(--ink);margin-bottom:8px;padding-bottom:4px}
.strip-title span:first-child{font:900 22px/1 "Playfair Display",serif;letter-spacing:.06em}
.strip-by{font-size:11px;font-style:italic}
.strip svg{display:block;width:100%;height:auto}
.strip .panel{fill:#fbf6e6;stroke:var(--ink);stroke-width:3}
.strip .ink{fill:var(--ink)}
.strip .ink-fill-light{fill:#fbf6e6;stroke:var(--ink);stroke-width:2.5}
.strip .ink-line{stroke:var(--ink);stroke-width:2.5;fill:none}
.strip .thin{stroke-width:1.2;stroke-dasharray:4 4}
.strip .worm{stroke:var(--ink);stroke-width:7;fill:none;stroke-linecap:round}
.strip .bubble{fill:#fff;stroke:var(--ink);stroke-width:2}
.strip .bubble-tail{fill:#fff;stroke:var(--ink);stroke-width:2;stroke-linejoin:round}
.strip .letters{font:18px "Patrick Hand",cursive;fill:var(--ink)}
.xkcd img{display:block;max-width:100%;margin:0 auto;filter:sepia(.15) contrast(1.05);mix-blend-mode:multiply}
.xkcd figcaption{text-align:center;border:0}
.horoscope p{font-size:13px;margin:0 0 5px}
.fine{font-size:11px;font-style:italic;text-align:center}
.tiles{display:flex;gap:4px;justify-content:center;margin:6px 0}
.tiles span{width:26px;height:28px;border:1.5px solid var(--ink);display:grid;place-items:center;font:700 16px "Old Standard TT",serif;background:rgba(255,255,255,.3)}
.answers{transform:rotate(180deg);font-size:11px;text-align:center;margin-top:14px;color:var(--ink-soft)}
.advice p{font-size:14px}
.sig{text-align:right;font-style:italic}

/* obituaries */
.obit-intro{text-align:center;font-style:italic;margin:0 0 14px}
.obit{break-inside:avoid;margin-bottom:16px;padding-bottom:10px;border-bottom:1px solid rgba(42,37,29,.55)}
.obit h3{font:900 19px/1.1 "Playfair Display",serif;margin:0;text-transform:uppercase;letter-spacing:.02em}
.portrait{float:left;width:72px;margin:3px 10px 4px 0;border:1px solid var(--rule)}
.lifespan{font-size:12px;font-weight:700;letter-spacing:.08em}
.obit-desc{font-style:italic;font-size:13px;margin:2px 0 4px}
.obit p{font-size:13.5px;clear:none}
.remembered p{font-size:12.5px}

/* classifieds */
.classified-grid{display:grid;grid-template-columns:2.1fr 1fr;gap:24px}
.class-head{font:900 34px/1 "Playfair Display",serif;text-align:center;margin:0 0 10px;border-bottom:2px solid var(--rule);padding-bottom:6px;letter-spacing:.08em}
.ads{column-rule:1px solid var(--rule)}
.ad{break-inside:avoid;font-size:12px;line-height:1.3;border:1px solid rgba(42,37,29,.7);padding:6px 7px;margin-bottom:6px;text-align:justify;hyphens:auto}
.ad b{font-size:12.5px}
.ad a{font-weight:700;text-decoration:underline}
.ads-credit{font-size:11px;font-style:italic;text-align:right}
.weather table{width:100%;border-collapse:collapse;font-size:12.5px}
.weather th,.weather td{border-bottom:1px dotted rgba(42,37,29,.5);padding:3px 2px;text-align:left}
.wx-icon,.glyph{font-size:15px;filter:grayscale(1) contrast(1.4) brightness(.6)}
.wx-now,.wx-sun{font-size:13px}
.house-ad{text-align:center;background:rgba(29,26,21,.06)}
.ha-small{font-size:9.5px;letter-spacing:.2em}
.ha-big{font:900 30px/1 "Playfair Display",serif;margin:8px 0;letter-spacing:.04em}
.house-ad a{display:inline-block;margin-top:4px;border:1.5px solid var(--ink);padding:5px 12px;font-weight:700;letter-spacing:.06em}
.personals p{font-size:12.5px;border-bottom:1px dotted rgba(42,37,29,.5);padding-bottom:4px}
.desk-foot{max-width:1180px;margin:0 auto 40px;padding:0 16px;color:#cdbf9e;font-size:12px;text-align:center;font-style:italic}
.desk-foot a{text-decoration:underline}

@media (max-width:980px){
  .cols-4{column-count:2}.cols-3{column-count:2}
  .split.three{grid-template-columns:1fr 1fr}
}
@media (max-width:760px){
  main{padding:16px 8px 4px}
  .sheet{padding:18px 16px 24px;transform:none!important}
  .fold{margin:16px -16px}
  .ears{grid-template-columns:1fr}
  .ear{display:none}
  .dateline{flex-direction:column;align-items:center;gap:2px}
  .front-grid,.split,.split.three,.classified-grid{grid-template-columns:1fr}
  .side,.split > div + div{border-left:0;padding-left:0}
  .cols-2,.cols-3,.cols-4{column-count:1}
  .lead .cols-2{column-count:1}
  .desk-nav{justify-content:flex-start;flex-wrap:nowrap;overflow-x:auto}
  .desk-nav a{white-space:nowrap}
}
@media print{
  body{background:none}
  .desk-nav,.desk-foot{display:none}
  main{padding:0}
  .sheet{box-shadow:none;transform:none!important;page-break-after:always;margin:0;background:none}
}
`;
