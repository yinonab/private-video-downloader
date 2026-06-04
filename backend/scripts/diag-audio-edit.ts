/**
 * Audio edit pipeline diagnostic — synthetic MP3, trim/speed/quality exports, ffprobe checks.
 * Run: npm run diag:audio-edit
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildEditAudioFfmpegArgs } from "../src/modules/edit/edit.ffmpeg";
import { resolveEditOperations } from "../src/modules/edit/edit.schemas";
import type { EditOperation } from "../src/modules/edit/edit.schemas";
import { ffprobeMedia } from "../src/services/ffmpegNormalize";

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "linkclip-audio-edit-diag-"));

function fail(msg: string): never {
  console.error(`FAIL: ${msg}`);
  process.exit(1);
}

function ok(msg: string): void {
  console.log(`OK: ${msg}`);
}

function runFfmpeg(args: string[]): number | null {
  const r = spawnSync("ffmpeg", args, { encoding: "utf8", timeout: 120_000 });
  if (r.error) fail(r.error.message);
  return r.status;
}

function assert(cond: boolean, msg: string): void {
  if (!cond) fail(msg);
}

async function main(): Promise<void> {
  const srcMp3 = path.join(tmpDir, "source.mp3");
  const sine = spawnSync(
    "ffmpeg",
    [
      "-hide_banner",
      "-y",
      "-f",
      "lavfi",
      "-i",
      "sine=frequency=440:duration=12",
      "-vn",
      "-codec:a",
      "libmp3lame",
      "-b:a",
      "192k",
      srcMp3,
    ],
    { encoding: "utf8", timeout: 60_000 }
  );
  if (sine.status !== 0 || !fs.existsSync(srcMp3)) {
    fail("Could not generate synthetic MP3 source");
  }
  ok("synthetic source MP3");

  const srcProbe = await ffprobeMedia(srcMp3);
  const durationSec = srcProbe.durationMs > 0 ? srcProbe.durationMs / 1000 : 0;
  assert(durationSec >= 10, `source duration too short: ${durationSec}`);
  assert(srcProbe.audio != null, "source missing audio stream");
  assert(srcProbe.video == null, "source must not have video stream");

  const cases: { name: string; ops: EditOperation[]; minOutSec?: number; maxOutSec?: number }[] = [
    {
      name: "trim",
      ops: [
        { type: "trim", startSec: 2, endSec: 8 },
        { type: "audioQuality", preset: "high" },
      ],
      minOutSec: 5,
      maxOutSec: 7,
    },
    {
      name: "speed",
      ops: [
        { type: "speed", factor: 1.5 },
        { type: "audioQuality", preset: "high" },
      ],
      minOutSec: 1,
      maxOutSec: 14,
    },
    {
      name: "trim+speed",
      ops: [
        { type: "trim", startSec: 1, endSec: 9 },
        { type: "speed", factor: 2 },
        { type: "audioQuality", preset: "high" },
      ],
      minOutSec: 3,
      maxOutSec: 10,
    },
    {
      name: "quality-standard",
      ops: [{ type: "audioQuality", preset: "standard" }],
    },
    {
      name: "quality-high",
      ops: [{ type: "audioQuality", preset: "high" }],
    },
    {
      name: "quality-best",
      ops: [{ type: "audioQuality", preset: "best" }],
    },
  ];

  for (const c of cases) {
    const outPath = path.join(tmpDir, `${c.name}.mp3`);
    const plan = resolveEditOperations(c.ops);
    const built = buildEditAudioFfmpegArgs({
      inputPath: srcMp3,
      outputPath: outPath,
      durationSec,
      plan,
    });
    const code = runFfmpeg(built.args);
    assert(code === 0, `${c.name}: ffmpeg exit ${code}`);
    assert(fs.existsSync(outPath), `${c.name}: output missing`);
    const st = fs.statSync(outPath);
    assert(st.size > 500, `${c.name}: output too small`);

    const probe = await ffprobeMedia(outPath);
    assert(probe.audio != null, `${c.name}: output missing audio`);
    assert(probe.video == null, `${c.name}: output must not have video`);
    const fmt = (probe.formatName ?? "").toLowerCase();
    assert(fmt.includes("mp3") || fmt.includes("mpeg"), `${c.name}: unexpected format ${fmt}`);

    const outDur = probe.durationMs > 0 ? probe.durationMs / 1000 : 0;
    if (c.minOutSec != null) {
      assert(outDur >= c.minOutSec * 0.85, `${c.name}: duration ${outDur}s < min ${c.minOutSec}`);
    }
    if (c.maxOutSec != null) {
      assert(outDur <= c.maxOutSec * 1.15, `${c.name}: duration ${outDur}s > max ${c.maxOutSec}`);
    }
    ok(`${c.name} (${Math.round(outDur * 10) / 10}s, ${st.size} bytes)`);
  }

  console.log("\nAll audio edit diagnostic checks passed.");
  fs.rmSync(tmpDir, { recursive: true, force: true });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
