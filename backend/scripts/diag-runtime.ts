/**
 * Production runtime diagnostic: download/edit toolchain must be present before serving traffic.
 * Run: npm run diag:runtime
 */
import { execSync, spawnSync } from "node:child_process";
import dotenv from "dotenv";
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

/** Minimal env so optional ytdlp probe can load config when .env is absent (e.g. CI). */
function ensureDiagEnv(): void {
  const stubs: Record<string, string> = {
    DATABASE_URL: "postgresql://diag/diag",
    REDIS_URL: "redis://127.0.0.1:6379",
    STORAGE_DIR: path.join(backendRoot, "storage"),
    ADMIN_TOKEN: "diag-admin-token",
    DEVICE_TOKEN_SECRET: "diag-device-token-secret",
  };
  for (const [k, v] of Object.entries(stubs)) {
    if (!process.env[k]?.trim()) process.env[k] = v;
  }
}

async function main(): Promise<void> {
  dotenv.config({ path: path.join(backendRoot, ".env") });
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
      const curlCffi = pipShow("curl_cffi");
      record("curl_cffi", curlCffi.ok, curlCffi.detail);
      if (curlCffi.ok) {
        const imp = commandOk("yt-dlp", ["--list-impersonate-targets"]);
        const out = (() => {
          try {
            const r = spawnSync("yt-dlp", ["--list-impersonate-targets"], {
              encoding: "utf8",
              timeout: 30_000,
            });
            return `${r.stdout || ""}\n${r.stderr || ""}`;
          } catch {
            return "";
          }
        })();
        const available = out
          .split(/\r?\n/)
          .filter((ln) => /curl_cffi\s*$/.test(ln) && !/unavailable/i.test(ln)).length;
        record(
          "yt-dlp impersonate targets",
          available >= 1,
          available >= 1
            ? `${available} available via curl_cffi`
            : imp.ok
              ? "curl_cffi installed but no usable impersonate targets"
              : imp.detail
        );
      } else {
        record("yt-dlp impersonate targets", false, "curl_cffi required for TikTok impersonation");
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

  {
    try {
      ensureDiagEnv();
      const { probeYtDlpCookiesTempCopy } = await import("../src/services/ytdlp");
      const probe = await probeYtDlpCookiesTempCopy();
      if (!probe.configured) {
        record("yt-dlp cookies temp copy", true, "COOKIES_FILE not configured (skipped)", false);
      } else if (probe.ok) {
        record(
          "yt-dlp cookies temp copy",
          true,
          `writable temp ok (${probe.tempBasename ?? "temp"}, ${probe.bytesCopied} bytes)`,
          false
        );
      } else {
        record("yt-dlp cookies temp copy", false, probe.error ?? "temp copy probe failed", false);
      }
    } catch (e) {
      record(
        "yt-dlp cookies temp copy",
        false,
        e instanceof Error ? e.message : String(e),
        false
      );
    }
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
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
