// Abre o probe no Chrome headless (mudo, sem vsync) e grava as linhas PERF|.
// Uso: node --experimental-websocket run_chrome.mjs <url> <log> [--cpu=4] [--dpr=2] [--size=1280,720] [--timeout=600] [--vsync]
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const [url, logPath, ...rest] = process.argv.slice(2);
const opt = Object.fromEntries(rest.map((a) => {
  const [k, v] = a.replace(/^--/, "").split("=");
  return [k, v ?? "1"];
}));
const cpu = Number(opt.cpu || 1);
const dpr = opt.dpr || "1";
const size = opt.size || "1280,720";
const timeout = Number(opt.timeout || 600) * 1000;
const port = 9300 + Math.floor(Math.random() * 500);
const profile = fs.mkdtempSync(path.join(process.env.SCRATCH || os.tmpdir(), "chrome-prof-"));

const args = [
  "--headless=new", "--mute-audio", `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
  "--use-angle=metal", "--enable-gpu", "--ignore-gpu-blocklist", "--no-first-run", "--no-default-browser-check",
  `--window-size=${size}`, `--force-device-scale-factor=${dpr}`, "--autoplay-policy=no-user-gesture-required",
  "--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows",
];
if (!opt.vsync) args.push("--disable-gpu-vsync", "--disable-frame-rate-limit");
args.push("about:blank");
const chrome = spawn("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", args, { stdio: ["ignore", "ignore", "pipe"] });
let chromeErr = "";
chrome.stderr.on("data", (d) => { chromeErr += d.toString(); if (chromeErr.length > 200000) chromeErr = chromeErr.slice(-100000); });

const log = fs.createWriteStream(logPath);
const t0 = Date.now();
const stamp = () => ((Date.now() - t0) / 1000).toFixed(1);
function line(s) { log.write(`[${stamp()}] ${s}\n`); }

async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
async function targets() {
  for (let i = 0; i < 100; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/json`);
      const j = await r.json();
      const p = j.filter((t) => t.type === "page");
      if (p.length) return p;
    } catch {}
    await sleep(200);
  }
  throw new Error("chrome não respondeu");
}

let done = false;
function finish(code) {
  if (done) return;
  done = true;
  line(`END code=${code}`);
  log.end();
  try { chrome.kill("SIGTERM"); } catch {}
  setTimeout(() => { try { fs.rmSync(profile, { recursive: true, force: true }); } catch {} process.exit(code); }, 1500);
}

const pages = await targets();
const page = pages.find((t) => t.url === "about:blank") || pages[0];
const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
function send(method, params = {}) {
  return new Promise((res) => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
}
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); return; }
  if (m.method === "Runtime.consoleAPICalled") {
    const text = m.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
    if (text.includes("PERF|") || /error|ERROR|SCRIPT/.test(text)) line(text);
    if (text.includes("PERF|DONE")) finish(0);
    const shot = text.match(/PERF\|SHOT\|([\w.-]+)/);
    if (shot) {
      send("Page.captureScreenshot", { format: "png" }).then((r) => {
        if (r && r.data) { fs.writeFileSync(`${logPath}.${shot[1]}.png`, Buffer.from(r.data, "base64")); line(`shot saved ${shot[1]}`); }
      });
    }
  } else if (m.method === "Runtime.exceptionThrown") {
    line("EXC " + JSON.stringify(m.params.exceptionDetails).slice(0, 500));
  } else if (m.method === "Inspector.targetCrashed") {
    line("CRASH"); finish(3);
  }
};
await new Promise((r) => (ws.onopen = r));
await send("Page.enable");
if (cpu > 1) { await send("Emulation.setCPUThrottlingRate", { rate: cpu }); line(`cpu throttle x${cpu}`); }
await send("Page.navigate", { url });
await sleep(300);
await send("Runtime.enable");
await send("Inspector.enable");
line(`navigated ${url} size=${size} dpr=${dpr} cpu=${cpu}`);
setTimeout(() => { line("TIMEOUT"); fs.writeFileSync(logPath + ".chrome.txt", chromeErr); finish(2); }, timeout);
chrome.on("exit", (c) => { line(`chrome exit ${c}`); fs.writeFileSync(logPath + ".chrome.txt", chromeErr); finish(4); });
