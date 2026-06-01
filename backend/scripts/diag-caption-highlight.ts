/**
 * Structural diagnostics for V3.4B caption highlight overlay renderer.
 * Run: npm run diag:caption-highlight
 */
import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import type { CaptionsBurnInV1Resolved } from "../src/modules/edit/edit.types";
import {
  buildCaptionHighlightBurnPlan,
  captionsConfigForAssBurn,
  renderCaptionHighlightPlate,
  tokenizeCaptionText,
} from "../src/services/captionHighlight";
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

async function main(): Promise<void> {
  assertKillSwitchStaticAss();

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
    ];

    for (const s of samples) {
      const dir = path.join(outRoot, s.id);
      const cfg = { ...baseCfg, ...s.cfg };
      const plan = await buildCaptionHighlightBurnPlan([s.seg], cfg, dir);
      assert.ok(plan.plateCount > 0, `${s.id} plates`);
      for (const p of plan.plates) {
        assertPlateIntegrity(p.platePath, p.activeWordIndex, tokenizeCaptionText(s.seg.text).length);
      }
      console.info(`diag:caption-highlight ok sample=${s.id} plates=${plan.plateCount} fallback=${plan.usedFallbackTiming}`);
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
      const plates = readdirSync(path.join(outRoot, "he1"))
        .filter((f) => f.endsWith(".png"))
        .slice(0, 4)
        .map((f) => path.join(outRoot, "he1", f));
      if (plates.length >= 2) {
        const mp4 = path.join(outRoot, "smoke.mp4");
        const args = [
          "-hide_banner",
          "-y",
          "-f",
          "lavfi",
          "-i",
          "color=c=black:s=960x540:d=2:r=30",
          "-loop",
          "1",
          "-t",
          "1",
          "-i",
          plates[0]!,
          "-loop",
          "1",
          "-t",
          "1",
          "-i",
          plates[1]!,
          "-filter_complex",
          "[0:v][1:v]overlay=enable='between(t,0,1)'[v1];[v1][2:v]overlay=enable='between(t,1,2)'[vout]",
          "-map",
          "[vout]",
          "-c:v",
          "libx264",
          "-pix_fmt",
          "yuv420p",
          mp4,
        ];
        const run = spawnSync("ffmpeg", args, { encoding: "utf8" });
        assert.equal(run.status, 0, "ffmpeg smoke composite");
        assert.ok(existsSync(mp4), "smoke mp4 exists");
        console.info("diag:caption-highlight ok ffmpeg smoke composite");
      }
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
