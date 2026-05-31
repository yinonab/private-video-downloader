/**
 * Production runtime diagnostic: download/edit toolchain must be present before serving traffic.
 * Run: npm run diag:runtime
 */
import { execSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

type Check = { name: string; ok: boolean; detail: string; required: boolean };

const checks: Check[] = [];

function firstLine(text: string): string {
  return text.trim().split(/\r?\n/)[0] ?? "";
}

function commandOk(cmd: string, args: string[] = ["--version"]): { ok: boolean; detail: string } {
  try {
    const r = spawnSync(cmd, args, { encoding: "utf8", timeout: 30_000 });
    if (r.error) {
      const msg = r.error.message;
      return { ok: false, detail: msg.includes("ENOENT") ? "not found in PATH" : msg };
    }
    const out = (r.stdout || r.stderr || "").trim();
    if (r.status === 0) {
      return { ok: true, detail: firstLine(out) || "ok" };
    }
    return {
      ok: false,
      detail: firstLine(out || r.stderr || "") || `exit ${r.status ?? "unknown"}`,
    };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return { ok: false, detail: msg.includes("ENOENT") ? "not found in PATH" : msg };
  }
}

function pipShow(pkg: string): { ok: boolean; detail: string } {
  try {
    const out = execSync(`python3 -m pip show ${pkg}`, { encoding: "utf8", stdio: "pipe" });
    const version = /^Version:\s*(.+)$/m.exec(out)?.[1]?.trim();
    return { ok: true, detail: version ? `${pkg} ${version}` : pkg };
  } catch {
    return { ok: false, detail: `${pkg} not installed (python3 -m pip show failed)` };
  }
}

function hasCaptionFontsScript(): boolean {
  try {
    const pkgPath = path.join(backendRoot, "package.json");
    const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8")) as {
      scripts?: Record<string, string>;
    };
    return Boolean(pkg.scripts?.["diag:caption-fonts"]);
  } catch {
    return false;
  }
}

function fontconfigAvailable(): boolean {
  return commandOk("fc-match", ["--version"]).ok;
}

function runCaptionFontsDiag(): void {
  const npm = process.platform === "win32" ? "npm.cmd" : "npm";
  const r = spawnSync(npm, ["run", "diag:caption-fonts"], {
    cwd: backendRoot,
    encoding: "utf8",
    stdio: "inherit",
    timeout: 60_000,
    shell: process.platform === "win32",
  });
  checks.push({
    name: "caption-fonts (diag:caption-fonts)",
    ok: r.status === 0,
    detail:
      r.status === 0
        ? "passed"
        : `exited ${r.status ?? "unknown"}${r.error ? ` (${r.error.message})` : ""}`,
    required: true,
  });
}

function record(name: string, ok: boolean, detail: string, required = true): void {
  checks.push({ name, ok, detail, required });
}

console.info("LinkClip runtime diagnostic\n");

{
  const r = commandOk("yt-dlp", ["--version"]);
  record("yt-dlp", r.ok, r.detail);
}

{
  const py = commandOk("python3", ["--version"]);
  record("python3", py.ok, py.detail);
  if (py.ok) {
    const ejs = pipShow("yt-dlp-ejs");
    record("yt-dlp-ejs", ejs.ok, ejs.detail);
    const ytdlpPkg = pipShow("yt-dlp");
    if (!ytdlpPkg.ok) {
      record("yt-dlp (pip)", false, ytdlpPkg.detail);
    }
  } else {
    record("yt-dlp-ejs", false, "python3 required for pip show");
  }
}

{
  const r = commandOk("node", ["--version"]);
  record("node", r.ok, r.detail);
}

{
  const r = commandOk("ffmpeg", ["-version"]);
  record("ffmpeg", r.ok, r.detail ? firstLine(r.detail) : "ok");
}

if (hasCaptionFontsScript() && fontconfigAvailable()) {
  console.info("\n--- caption fonts ---\n");
  runCaptionFontsDiag();
} else if (hasCaptionFontsScript()) {
  checks.push({
    name: "caption-fonts (diag:caption-fonts)",
    ok: true,
    detail: "skipped (fontconfig/fc-match not available on this host)",
    required: false,
  });
}

console.info("\n--- summary ---\n");
let failedRequired = 0;
for (const c of checks) {
  const tag = c.ok ? "OK" : c.required ? "FAIL" : "SKIP";
  console.info(`[${tag}] ${c.name}: ${c.detail}`);
  if (!c.ok && c.required) failedRequired++;
}

if (failedRequired > 0) {
  console.error(`\n${failedRequired} required check(s) failed.`);
  process.exit(1);
}

console.info("\nAll required runtime checks passed.");
