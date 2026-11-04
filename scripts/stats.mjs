// Draws the ASCII activity panel from live GitHub data.
// Run with GH_TOKEN set: node scripts/stats.mjs
import { readFileSync, writeFileSync } from "node:fs";

const LOGIN = "h4yme";
const FS = 20, CW = 12, LH = 30, PAD = 28, COLS = 102, INNER = COLS - 4, W = PAD * 2 + COLS * CW;

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
const plural = (n, word) => `${number(n)} ${word}${n === 1 ? "" : "s"}`;
const shortDate = iso => new Date(`${iso}T00:00:00Z`).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).toLowerCase();

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

const T = (t, c = "mut") => ({ t, c });
const width = segs => segs.reduce((n, s) => n + s.t.length, 0);
const LEVEL = {
  NONE: T(".", "dim"),
  FIRST_QUARTILE: T(":", "mut"),
  SECOND_QUARTILE: T("+", "ink"),
  THIRD_QUARTILE: T("*", "ok"),
  FOURTH_QUARTILE: T("#", "ok")
};

function heatmap(weeks) {
  const months = new Array(weeks.length).fill(" ");
  let last = -1;
  weeks.forEach((week, x) => {
    const month = new Date(`${week.contributionDays[0].date}T00:00:00Z`).getUTCMonth();
    if (month !== last && x + 3 <= weeks.length) {
      const name = new Date(Date.UTC(2000, month, 1)).toLocaleDateString("en-US", { month: "short", timeZone: "UTC" }).toLowerCase();
      if (months.slice(Math.max(0, x - 1), x + 3).every(c => c === " ")) [...name].forEach((c, i) => { months[x + i] = c; });
      last = month;
    }
  });
  const rows = [[T("    ", "dim"), T(months.join(""), "dim")]];
  const labels = { 1: "mon ", 3: "wed ", 5: "fri " };
  for (let day = 0; day < 7; day++) {
    const row = [T(labels[day] || "    ", "dim")];
    for (const week of weeks) {
      const cell = week.contributionDays.find(d => d.weekday === day);
      row.push(cell ? LEVEL[cell.contributionLevel] : T(" ", "dim"));
    }
    rows.push(row);
  }
  return rows;
}

function stat(key, value, size) {
  return [T(key, "mut"), T(" " + ".".repeat(size - key.length - value.length - 2) + " ", "dim"), T(value, "ink")];
}

function framed(segs) {
  const pad = INNER - width(segs);
  if (pad < 0) throw new Error("Row too long: " + segs.map(s => s.t).join(""));
  return [T("| ", "dim"), ...segs, T(" ".repeat(pad), "dim"), T(" |", "dim")];
}

function buildRows(s) {
  const SIDE = 37, GAP = "    ";
  const side = [
    stat("contributions", number(s.total), SIDE),
    stat("active days", number(s.activeDays), SIDE),
    stat("current streak", plural(s.current, "day"), SIDE),
    stat("longest streak", plural(s.longest, "day"), SIDE),
    stat("best day", `${number(s.best.contributionCount)} on ${shortDate(s.best.date)}`, SIDE),
    stat("public repos", number(s.repoCount), SIDE),
    stat("stars", number(s.stars), SIDE),
    stat("followers", number(s.followers), SIDE)
  ];
  const map = heatmap(s.weeks);
  const mapWidth = 4 + s.weeks.length;
  const rows = map.map((row, i) => [...row, T(" ".repeat(mapWidth - width(row)), "dim"), T(GAP, "dim"), ...side[i]]);

  rows.push([]);
  rows.push([T("top languages", "ink"), T(" (public repos)", "dim")]);
  const BAR = 74;
  for (const lang of s.languages) {
    const filled = Math.max(lang.share > 0 ? 1 : 0, Math.round(lang.share * BAR));
    rows.push([
      T(lang.name.padEnd(16), "mut"),
      T("#".repeat(filled), "ok"),
      T("-".repeat(BAR - filled), "dim"),
      T(`${(lang.share * 100).toFixed(1).padStart(7)}%`, "ink")
    ]);
  }
  rows.push([]);
  const stamp = new Date().toISOString().slice(0, 16).replace("T", " ");
  rows.push([T(`updated ${stamp} utc`, "dim"), T(" _", "cur ink")]);
  return rows;
}

function topRow(title) {
  return [T("+-- ", "dim"), T(title, "ink"), T(" " + "-".repeat(COLS - 6 - title.length) + "+", "dim")];
}

const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const font = weight => readFileSync(new URL(`../assets/fonts/geist-mono-${weight}.woff2`, import.meta.url)).toString("base64");

const PALETTE = {
  dark: { ink: "#f4f4f5", mut: "#a0a0a8", dim: "#4a4a54", ok: "#4ade80" },
  light: { ink: "#09090b", mut: "#52525b", dim: "#b4b4bc", ok: "#15803d" }
};

function render(rows, c, s) {
  const all = [topRow("activity"), ...rows.map(framed), [T("+" + "-".repeat(COLS - 2) + "+", "dim")]];
  const h = all.length * LH + 32;
  const text = all.map((segs, i) => {
    const spans = segs.map(x => `<tspan class="${x.c}">${esc(x.t)}</tspan>`).join("");
    return `<text x="${PAD}" y="${16 + LH * i + 21}" xml:space="preserve">${spans}</text>`;
  }).join("");
  const label = `GitHub activity: ${number(s.total)} contributions in the last year, longest streak ${plural(s.longest, "day")}. Top languages: ${s.languages.map(l => l.name).join(", ")}.`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${h}" width="${W}" height="${h}" role="img" aria-label="${esc(label)}"><defs><style>
@font-face{font-family:"GM";font-weight:400;src:url(data:font/woff2;base64,${font(400)}) format("woff2")}
@font-face{font-family:"GM";font-weight:600;src:url(data:font/woff2;base64,${font(600)}) format("woff2")}
text{font-family:"GM",ui-monospace,"SF Mono",Menlo,Consolas,monospace;font-size:${FS}px}
.ink{fill:${c.ink};font-weight:600}.mut{fill:${c.mut}}.dim{fill:${c.dim}}.ok{fill:${c.ok};font-weight:600}
.cur{animation:blink 1.1s steps(1) infinite}
@keyframes blink{50%{opacity:0}}
@media (prefers-reduced-motion:reduce){.cur{animation:none}}
</style></defs>${text}</svg>`;
}

const summary = summarize(await loadUser());
const rows = buildRows(summary);
for (const [mode, colors] of Object.entries(PALETTE)) {
  writeFileSync(new URL(`../assets/stats-${mode}.svg`, import.meta.url), render(rows, colors, summary));
}
console.log(`Drew ${number(summary.total)} contributions, ${summary.languages.length} languages`);
