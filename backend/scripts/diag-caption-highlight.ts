/**
 * Structural diagnostics for V3.4B caption highlight overlay renderer.
 * Run: npm run diag:caption-highlight
 */
import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import type { CaptionsBurnInV1Resolved } from "../src/modules/edit/edit.types";
import {
  buildCaptionHighlightBurnPlan,
  buildOverlayFfmpegInputArgs,
  buildTimedOverlayFilterComplex,
  captionsConfigForAssBurn,
  renderCaptionHighlightPlate,
  tokenizeCaptionText,
  validateOverlayFilterComplex,
  type TimedOverlayPlate,
} from "../src/services/captionHighlight";
import { createCanvas } from "@napi-rs/canvas";
import { segmentsToAssContent } from "../src/services/assSubtitles.service";
import type { TranscriptSegment } from "../src/services/transcription.service";

const baseCfg: CaptionsBurnInV1Resolved = {
  mode: "segments",
  language: "auto",
  burnIn: true,
  style: "clean_pro",
  fontSize: "medium",
  fontFamily: "heebo",
  position: "bottom",
  color: "white",
  wordHighlight: "color",
  boxShape: "pill",
  offsetX: 0,
  offsetY: 0,
};

function assertPlateIntegrity(pngPath: string, expectedActive: number, tokenCount: number): void {
  assert.ok(existsSync(pngPath), `missing plate ${pngPath}`);
  const buf = readFileSync(pngPath);
  assert.ok(buf.length > 200, "png too small");
  void expectedActive;
  void tokenCount;
}

async function renderShapeSample(
  text: string,
  activeIndex: number,
  shape: "rectangle" | "rounded" | "pill",
  outDir: string,
  mode: "color" | "box",
): Promise<string> {
  const cfg: CaptionsBurnInV1Resolved = {
    ...baseCfg,
    wordHighlight: mode,
    boxShape: shape,
    normalTextColor: "white",
    activeTextColor: "yellow",
    boxColor: "yellow",
  };
  const plan = await buildCaptionHighlightBurnPlan(
    [{ startSec: 0, endSec: 2, text, words: undefined }],
    cfg,
    path.join(outDir, `${shape}-${mode}`),
  );
  assert.ok(plan.plateCount >= 1, "plan has plates");
  const p = plan.plates.find((x) => x.activeWordIndex === activeIndex) ?? plan.plates[0]!;
  assertPlateIntegrity(p.platePath, activeIndex, tokenizeCaptionText(text).length);
  return p.platePath;
}

function dialogueLines(ass: string): string[] {
  return ass.split("\n").filter((l) => l.startsWith("Dialogue:"));
}

/** Production ASS path must never emit deprecated inline word-highlight tags. */
function assertKillSwitchStaticAss(): void {
  const seg: TranscriptSegment = {
    startSec: 0,
    endSec: 2,
    text: "hello world now",
    words: [
      { startSec: 0, endSec: 0.8, text: "hello" },
      { startSec: 0.8, endSec: 1.6, text: "world" },
      { startSec: 1.6, endSec: 2, text: "now" },
    ],
  };
  for (const wh of ["color", "box"] as const) {
    const cfg: CaptionsBurnInV1Resolved = { ...baseCfg, wordHighlight: wh };
    const assCfg = captionsConfigForAssBurn(cfg);
    assert.equal(assCfg.wordHighlight, "none", `kill switch forces none for ${wh}`);
    const ass = segmentsToAssContent([seg], { ...assCfg, title: `kill-${wh}` });
    const events = dialogueLines(ass).length;
    assert.ok(events >= 1, `${wh} static ASS has dialogue`);
    assert.ok(!ass.includes("{\\1c"), `${wh} production ASS has no inline color tags`);
    assert.ok(!ass.includes("{\\bord"), `${wh} production ASS has no inline box tags`);
    const rawDeprecated = segmentsToAssContent([seg], { ...cfg, title: `deprecated-${wh}` });
    assert.ok(
      rawDeprecated.includes(wh === "box" ? "{\\bord" : "{\\1c"),
      `${wh} deprecated ASS path still testable in isolation`,
    );
  }
  console.info("diag:caption-highlight ok kill-switch static ASS (flag-off / fallback path)");
}

function syntheticTimedPlates(count: number): TimedOverlayPlate[] {
  return Array.from({ length: count }, (_, i) => ({
    path: `plate-${i}.png`,
    startSec: i * 0.5,
    endSec: (i + 1) * 0.5,
  }));
}

function assertFilterComplexLabels(): void {
  for (const n of [1, 2, 3, 60] as const) {
    const built = buildTimedOverlayFilterComplex(syntheticTimedPlates(n));
    assert.ok(built, `filter build for ${n} plates`);
    validateOverlayFilterComplex(built);
    if (n === 1) {
      assert.ok(built.filter.includes("[0:v][1:v]overlay") && built.filter.endsWith("[vout]"));
    }
    if (n === 3) {
      assert.ok(built.filter.includes("[vx0][2:v]overlay"));
      assert.ok(built.filter.includes("[vx1][3:v]overlay"));
    }
  }
  console.info("diag:caption-highlight ok filter_complex labels (1,2,3,60)");
}

async function writeSolidTestPlate(outPath: string, width: number, height: number): Promise<void> {
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = "rgba(255, 217, 102, 0.92)";
  const bw = Math.round(width * 0.35);
  const bh = Math.round(height * 0.08);
  ctx.fillRect(Math.round((width - bw) / 2), Math.round(height * 0.72), bw, bh);
  writeFileSync(outPath, await canvas.encode("png"));
}

async function ffmpegOverlaySmoke(
  label: string,
  plateCount: number,
  videoW: number,
  videoH: number,
  outDir: string,
): Promise<void> {
  const plates: TimedOverlayPlate[] = [];
  for (let i = 0; i < plateCount; i++) {
    const platePath = path.join(outDir, `smoke-${label}-${i}.png`);
    await writeSolidTestPlate(platePath, videoW, videoH);
    plates.push({ path: platePath, startSec: i * 0.5, endSec: (i + 1) * 0.5 });
  }
  const built = buildTimedOverlayFilterComplex(plates);
  assert.ok(built);
  validateOverlayFilterComplex(built);
  const duration = plateCount * 0.5;
  const mp4 = path.join(outDir, `smoke-${label}.mp4`);
  const args = [
    "-hide_banner",
    "-y",
    "-f",
    "lavfi",
    "-i",
    `color=c=black:s=${videoW}x${videoH}:d=${duration}:r=30`,
    ...buildOverlayFfmpegInputArgs(plates),
    "-filter_complex",
    built.filter,
    "-map",
    "[vout]",
    "-c:v",
    "libx264",
    "-pix_fmt",
    "yuv420p",
    mp4,
  ];
  const run = spawnSync("ffmpeg", args, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 });
  if (run.status !== 0) {
    throw new Error(
      `ffmpeg overlay smoke ${label} failed: ${(run.stderr ?? "").slice(-800)}`,
    );
  }
  assert.ok(existsSync(mp4), `smoke mp4 ${label}`);
  console.info(`diag:caption-highlight ok ffmpeg overlay smoke ${label} plates=${plateCount} ${videoW}x${videoH}`);
}

async function main(): Promise<void> {
  assertKillSwitchStaticAss();
  assertFilterComplexLabels();

  const outRoot = mkdtempSync(path.join(os.tmpdir(), "linkclip-diag-cap-"));
  mkdirSync(outRoot, { recursive: true });

  try {
    const he1 = "מה משותף לדברים הבאים";
    const hePunct = "שלום, זה מבחן קצר.";
    const en1 = "What do these things have in common?";
    const heTwo =
      "מה משותף לדברים הבאים ולמה זה חשוב מאוד לכולם עכשיו";
    const edited = "edited words here now";

    const samples: { id: string; seg: TranscriptSegment; cfg?: Partial<CaptionsBurnInV1Resolved> }[] = [
      {
        id: "he1",
        seg: {
          startSec: 0,
          endSec: 3,
          text: he1,
          words: [
            { startSec: 0, endSec: 0.5, text: "מה" },
            { startSec: 0.5, endSec: 1, text: "משותף" },
            { startSec: 1, endSec: 1.5, text: "לדברים" },
            { startSec: 1.5, endSec: 2, text: "הבאים" },
          ],
        },
      },
      {
        id: "he-punct",
        seg: { startSec: 0, endSec: 2.5, text: hePunct },
      },
      {
        id: "en1",
        seg: {
          startSec: 0,
          endSec: 3,
          text: en1,
          words: [
            { startSec: 0, endSec: 0.4, text: "What" },
            { startSec: 0.4, endSec: 0.7, text: "do" },
            { startSec: 0.7, endSec: 1, text: "these" },
            { startSec: 1, endSec: 1.3, text: "things" },
            { startSec: 1.3, endSec: 1.6, text: "have" },
            { startSec: 1.6, endSec: 2, text: "in" },
            { startSec: 2, endSec: 2.5, text: "common?" },
          ],
        },
        cfg: { wordHighlight: "color" },
      },
      {
        id: "he-two-line",
        seg: { startSec: 0, endSec: 4, text: heTwo },
        cfg: { fontSize: "medium" },
      },
      {
        id: "edited-fallback",
        seg: {
          startSec: 0,
          endSec: 2.4,
          text: edited,
          words: [
            { startSec: 0, endSec: 1.2, text: "hello" },
            { startSec: 1.2, endSec: 2.4, text: "world" },
          ],
        },
      },
      {
        id: "missing-words",
        seg: { startSec: 0, endSec: 2, text: he1 },
      },
      {
        id: "portrait-probe",
        seg: {
          startSec: 0,
          endSec: 2,
          text: he1,
          words: [
            { startSec: 0, endSec: 0.5, text: "מה" },
            { startSec: 0.5, endSec: 1, text: "משותף" },
            { startSec: 1, endSec: 1.5, text: "לדברים" },
            { startSec: 1.5, endSec: 2, text: "הבאים" },
          ],
        },
        cfg: { wordHighlight: "box", boxShape: "pill" },
      },
    ];

    for (const s of samples) {
      const dir = path.join(outRoot, s.id);
      const cfg = { ...baseCfg, ...s.cfg };
      const videoSize =
        s.id === "portrait-probe"
          ? { width: 1080, height: 1920 }
          : undefined;
      const plan = await buildCaptionHighlightBurnPlan([s.seg], cfg, dir, videoSize);
      assert.ok(plan.plateCount > 0, `${s.id} plates`);
      if (videoSize) {
        assert.equal(plan.canvasWidth, 1080, `${s.id} canvas width`);
        assert.equal(plan.canvasHeight, 1920, `${s.id} canvas height`);
      }
      for (const p of plan.plates) {
        assertPlateIntegrity(p.platePath, p.activeWordIndex, tokenizeCaptionText(s.seg.text).length);
      }
      console.info(
        `diag:caption-highlight ok sample=${s.id} plates=${plan.plateCount} size=${plan.canvasWidth}x${plan.canvasHeight} fallback=${plan.usedFallbackTiming}`,
      );
    }

    for (const shape of ["rectangle", "rounded", "pill"] as const) {
      await renderShapeSample(he1, 1, shape, outRoot, "box");
      console.info(`diag:caption-highlight ok shape=${shape} mode=box`);
    }

    const single = await renderCaptionHighlightPlate({
      text: he1,
      activeWordIndex: 0,
      direction: "rtl",
      fontFamily: "heebo",
      fontSize: 32,
      fontWeight: 700,
      normalTextColor: "#FFFFFF",
      activeTextColor: "#FFD966",
      boxColor: "rgba(255,217,102,0.88)",
      boxShape: "pill",
      drawBox: true,
      maxLines: 2,
      canvasWidth: 960,
      canvasHeight: 540,
      position: "bottom",
      maxLineWidthPx: 780,
      lineGapPx: 10,
      tokenGapPx: 10,
      boxPaddingXPx: 8,
      boxPaddingYPx: 5,
    });
    assert.equal(single.activeTokenCount, 1, "single plate one active token");
    const order = single.layout.lines.flatMap((ln) => ln.boxes.map((b) => b.tokenIndex));
    assert.deepEqual(order, [0, 1, 2, 3], "hebrew logical token order in layout");

    const ff = spawnSync("ffmpeg", ["-version"], { encoding: "utf8" });
    if (ff.status === 0) {
      const smokeDir = path.join(outRoot, "ffmpeg-smoke");
      mkdirSync(smokeDir, { recursive: true });
      await ffmpegOverlaySmoke("n1", 1, 960, 540, smokeDir);
      await ffmpegOverlaySmoke("n3", 3, 960, 540, smokeDir);
      await ffmpegOverlaySmoke("portrait", 3, 1080, 1920, smokeDir);

      const boxPlan = await buildCaptionHighlightBurnPlan(
        [
          {
            startSec: 0,
            endSec: 2,
            text: he1,
            words: [
              { startSec: 0, endSec: 0.5, text: "מה" },
              { startSec: 0.5, endSec: 1, text: "משותף" },
              { startSec: 1, endSec: 1.5, text: "לדברים" },
              { startSec: 1.5, endSec: 2, text: "הבאים" },
            ],
          },
        ],
        { ...baseCfg, wordHighlight: "box", boxShape: "pill" },
        path.join(smokeDir, "box-plates"),
        { width: 1080, height: 1920 },
      );
      assert.ok(boxPlan.plateCount >= 1);
      const timed = boxPlan.plates.map((p) => ({
        path: p.platePath,
        startSec: p.startSec,
        endSec: p.endSec,
      }));
      const built = buildTimedOverlayFilterComplex(timed)!;
      validateOverlayFilterComplex(built);
      const boxMp4 = path.join(smokeDir, "box-visible.mp4");
      const boxArgs = [
        "-hide_banner",
        "-y",
        "-f",
        "lavfi",
        "-i",
        "color=c=black:s=1080x1920:d=2:r=30",
        ...buildOverlayFfmpegInputArgs(timed),
        "-filter_complex",
        built.filter,
        "-map",
        "[vout]",
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        boxMp4,
      ];
      const boxRun = spawnSync("ffmpeg", boxArgs, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 });
      assert.equal(boxRun.status, 0, `box visible smoke: ${(boxRun.stderr ?? "").slice(-400)}`);
      assert.ok(existsSync(boxMp4), "box visible mp4");
      console.info("diag:caption-highlight ok ffmpeg box-visible portrait composite");
    } else {
      console.info("diag:caption-highlight skip ffmpeg (not installed)");
    }

    console.info(`diag:caption-highlight — ok (assets under ${outRoot})`);
  } finally {
    rmSync(outRoot, { recursive: true, force: true });
  }
}

main().catch((err: unknown) => {
  console.error("diag:caption-highlight failed:", err instanceof Error ? err.message : String(err));
  process.exit(1);
});
