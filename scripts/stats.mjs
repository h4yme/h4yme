// Draws the activity panel from live GitHub data.
// Run with GH_TOKEN set: node scripts/stats.mjs
import { readFileSync, writeFileSync } from "node:fs";

const LOGIN = "h4yme";
const W = 1280, PAD = 28, CONTENT = W - PAD * 2;

const QUERY = `query($login: String!) {
  user(login: $login) {
    followers { totalCount }
    repositories(first: 100, ownerAffiliations: OWNER, privacy: PUBLIC, isFork: false) {
      totalCount
      nodes {
        stargazerCount
        languages(first: 10, orderBy: { field: SIZE, direction: DESC }) { edges { size node { name } } }
      }
    }
    contributionsCollection {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date weekday contributionCount contributionLevel } }
      }
    }
  }
}`;

async function loadUser() {
  const token = process.env.GH_TOKEN;
  if (!token) throw new Error("GH_TOKEN is not set");
  const res = await fetch("https://api.github.com/graphql", {
    method: "POST",
    headers: { authorization: `bearer ${token}`, "content-type": "application/json", "user-agent": LOGIN },
    body: JSON.stringify({ query: QUERY, variables: { login: LOGIN } })
  });
  if (!res.ok) throw new Error(`GitHub responded with ${res.status}`);
  const body = await res.json();
  if (body.errors) throw new Error(body.errors.map(e => e.message).join("; "));
  return body.data.user;
}

const number = n => n.toLocaleString("en-US");
const plural = (n, word) => `${word}${n === 1 ? "" : "s"}`;
const shortDate = iso => new Date(`${iso}T00:00:00Z`).toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: "UTC" }).toLowerCase();

function summarize(user) {
  const calendar = user.contributionsCollection.contributionCalendar;
  const days = calendar.weeks.flatMap(w => w.contributionDays);

  let longest = 0, run = 0;
  for (const d of days) {
    run = d.contributionCount > 0 ? run + 1 : 0;
    if (run > longest) longest = run;
  }
  /* Today may simply not have contributions yet */
  let current = 0;
  const recent = [...days].reverse();
  if (recent[0]?.contributionCount === 0) recent.shift();
  for (const d of recent) {
    if (d.contributionCount === 0) break;
    current++;
  }
  const best = days.reduce((a, b) => (b.contributionCount > a.contributionCount ? b : a), days[0]);

  const repos = user.repositories;
  const bytes = {};
  for (const repo of repos.nodes) {
    for (const edge of repo.languages.edges) bytes[edge.node.name] = (bytes[edge.node.name] || 0) + edge.size;
  }
  const totalBytes = Object.values(bytes).reduce((a, b) => a + b, 0);
  const languages = Object.entries(bytes).sort((a, b) => b[1] - a[1]).slice(0, 6)
    .map(([name, size]) => ({ name: name.toLowerCase(), share: totalBytes ? size / totalBytes : 0 }));

  return {
    weeks: calendar.weeks.slice(-53),
    total: calendar.totalContributions,
    activeDays: days.filter(d => d.contributionCount > 0).length,
    current, longest, best,
    repoCount: repos.totalCount,
    stars: repos.nodes.reduce((n, r) => n + r.stargazerCount, 0),
    followers: user.followers.totalCount,
    languages
  };
}

const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const font = weight => readFileSync(new URL(`../assets/fonts/geist-mono-${weight}.woff2`, import.meta.url)).toString("base64");

const PALETTE = {
  dark: {
    ink: "#f4f4f5", mut: "#a0a0a8", dim: "#5a5a64", track: "#1c1f26", bar: "#4ade80",
    levels: { NONE: "#1c1f26", FIRST_QUARTILE: "#14532d", SECOND_QUARTILE: "#15803d", THIRD_QUARTILE: "#22c55e", FOURTH_QUARTILE: "#4ade80" }
  },
  light: {
    ink: "#09090b", mut: "#52525b", dim: "#a1a1aa", track: "#ebedf0", bar: "#16a34a",
    levels: { NONE: "#ebedf0", FIRST_QUARTILE: "#bbf7d0", SECOND_QUARTILE: "#4ade80", THIRD_QUARTILE: "#16a34a", FOURTH_QUARTILE: "#166534" }
  }
};
const LEVELS = ["NONE", "FIRST_QUARTILE", "SECOND_QUARTILE", "THIRD_QUARTILE", "FOURTH_QUARTILE"];

function text(x, y, value, cls, extra = "") {
  return `<text x="${x}" y="${y}" class="${cls}" ${extra}>${esc(value)}</text>`;
}

function dashes(y) {
  return text(PAD, y, "+" + "-".repeat(100) + "+", "s20 dim");
}

function statsRow(s, top) {
  const items = [
    [number(s.total), "", "contributions"],
    [number(s.activeDays), "", "active days"],
    [number(s.current), plural(s.current, "day"), "current streak"],
    [number(s.longest), plural(s.longest, "day"), "longest streak"],
    [number(s.best.contributionCount), "", `best day, ${shortDate(s.best.date)}`]
  ];
  const col = CONTENT / items.length;
  return items.map(([value, unit, label], i) => {
    const x = PAD + col * i;
    const unitX = x + value.length * 27.6 + 8;
    return text(x, top + 40, value, "s46 ink") +
      (unit ? text(unitX, top + 40, unit, "s20 mut") : "") +
      text(x, top + 72, label, "s18 mut");
  }).join("");
}

function heatmap(s, c, top) {
  const left = PAD + 52, pitch = (CONTENT - 52) / s.weeks.length, cell = Math.floor(pitch - 3);
  let out = "", lastMonth = -1, lastLabelX = -100;
  s.weeks.forEach((week, x) => {
    const month = new Date(`${week.contributionDays[0].date}T00:00:00Z`).getUTCMonth();
    const px = left + x * pitch;
    if (month !== lastMonth) {
      if (px - lastLabelX > 50 && x + 2 < s.weeks.length) {
        const name = new Date(Date.UTC(2000, month, 1)).toLocaleDateString("en-US", { month: "short", timeZone: "UTC" }).toLowerCase();
        out += text(px, top + 14, name, "s16 dim");
        lastLabelX = px;
      }
      lastMonth = month;
    }
    for (const day of week.contributionDays) {
      out += `<rect x="${px.toFixed(1)}" y="${(top + 28 + day.weekday * pitch).toFixed(1)}" width="${cell}" height="${cell}" rx="4" fill="${c.levels[day.contributionLevel]}"/>`;
    }
  });
  for (const [row, name] of [[1, "mon"], [3, "wed"], [5, "fri"]]) {
    out += text(PAD, top + 28 + row * pitch + cell - 4, name, "s16 dim");
  }
  const bottom = top + 28 + 7 * pitch;
  const legendY = bottom + 8;
  const size = 14, right = W - PAD;
  const startX = right - 48 - LEVELS.length * (size + 4);
  out += text(startX - 12, legendY + 12, "less", "s16 dim", 'text-anchor="end"');
  LEVELS.forEach((level, i) => {
    out += `<rect x="${startX + i * (size + 4)}" y="${legendY}" width="${size}" height="${size}" rx="3" fill="${c.levels[level]}"/>`;
  });
  out += text(right, legendY + 12, "more", "s16 dim", 'text-anchor="end"');
  return { svg: out, bottom: legendY + size };
}

function languages(s, c, top) {
  const colW = (CONTENT - 48) / 2, rowH = 34, nameW = 140, pctW = 76;
  const rows = Math.ceil(s.languages.length / 2);
  let out = text(PAD, top + 16, "top languages", "s18 ink") + text(PAD + 13 * 10.8 + 12, top + 16, "(public repos)", "s18 dim");
  s.languages.forEach((lang, i) => {
    const column = i < rows ? 0 : 1, row = i < rows ? i : i - rows;
    const x = PAD + column * (colW + 48), y = top + 40 + row * rowH;
    const barX = x + nameW, barW = colW - nameW - pctW;
    out += text(x, y + 13, lang.name, "s18 mut");
    out += `<rect x="${barX}" y="${y + 2}" width="${barW}" height="12" rx="6" fill="${c.track}"/>`;
    out += `<rect x="${barX}" y="${y + 2}" width="${Math.max(6, barW * lang.share).toFixed(1)}" height="12" rx="6" fill="${c.bar}"/>`;
    out += text(x + colW, y + 13, `${(lang.share * 100).toFixed(1)}%`, "s18 ink", 'text-anchor="end"');
  });
  return { svg: out, bottom: top + 40 + rows * rowH };
}

function render(s, c, stamp) {
  let y = 37;
  let body = text(PAD, y, "+-- ", "s20 dim") + text(PAD + 48, y, "activity", "s20 ink") +
    text(PAD + 48 + 8 * 12 + 12, y, "-".repeat(90) + "+", "s20 dim");
  y += 20;
  body += statsRow(s, y);
  const map = heatmap(s, c, y + 104);
  body += map.svg;
  const langs = languages(s, c, map.bottom + 28);
  body += langs.svg;
  y = langs.bottom + 20;
  body += text(PAD, y, `${number(s.repoCount)} public repos / ${number(s.stars)} stars / ${number(s.followers)} followers`, "s18 mut");
  body += text(W - PAD, y, `updated ${stamp} utc`, "s18 dim", 'text-anchor="end"');
  y += 34;
  body += dashes(y);
  const h = y + 20;
  const label = `GitHub activity: ${number(s.total)} contributions in the last year, longest streak ${s.longest} ${plural(s.longest, "day")}. Top languages: ${s.languages.map(l => l.name).join(", ")}.`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${h}" width="${W}" height="${h}" role="img" aria-label="${esc(label)}"><defs><style>
@font-face{font-family:"GM";font-weight:400;src:url(data:font/woff2;base64,${font(400)}) format("woff2")}
@font-face{font-family:"GM";font-weight:600;src:url(data:font/woff2;base64,${font(600)}) format("woff2")}
text{font-family:"GM",ui-monospace,"SF Mono",Menlo,Consolas,monospace;white-space:pre}
.s16{font-size:16px}.s18{font-size:18px}.s20{font-size:20px}.s46{font-size:46px}
.ink{fill:${c.ink};font-weight:600}.mut{fill:${c.mut}}.dim{fill:${c.dim}}
</style></defs>${body}</svg>`;
}

const summary = summarize(await loadUser());
const stamp = new Date().toISOString().slice(0, 16).replace("T", " ");
for (const [mode, colors] of Object.entries(PALETTE)) {
  writeFileSync(new URL(`../assets/stats-${mode}.svg`, import.meta.url), render(summary, colors, stamp));
}
console.log(`Drew ${number(summary.total)} contributions, ${summary.languages.length} languages`);
