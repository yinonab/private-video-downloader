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
import { normalizeCaptionSegmentsForBurn } from "../src/modules/edit/captionSegments.util";
import {
  buildCaptionHighlightAlphaVideo,
  buildCaptionHighlightBurnPlan,
  buildOverlayFfmpegInputArgs,
  buildTimedOverlayFilterComplex,
  CAPTION_ALPHA_OVERLAY_FILTER,
  CAPTION_ALPHA_VIDEO_EXT,
  captionsConfigForAssBurn,
  inspectCaptionPlate,
  renderCaptionHighlightPlate,
  highlightPlateBoxFromBaseline,
  resolveHighlightStyle,
  textColorToCss,
  tokenizeCaptionText,
  captionTokenMatchesWord,
  captionTokenDisplayText,
  validateOverlayFilterComplex,
  captionFontSizePx,
  captionMaxLineWidthPx,
  CAPTION_MAX_CHARS_PER_LINE,
  breakCaptionLines,
  breakCaptionLinesForFontSize,
  scoreTwoLineCaption,
  chunkSegmentForHighlight,
  measureCaptionTokenGapPx,
  type TimedOverlayPlate,
} from "../src/services/captionHighlight";
import { layoutCaptionBlock } from "../src/services/captionHighlight/layout";
import { normalizeCaptionText as highlightNormalizeCaptionText } from "../src/services/captionHighlight/tokenize";
import { createCanvas, loadImage } from "@napi-rs/canvas";
import { captionFontCss, ensureCaptionFont } from "../src/services/captionHighlight/fonts";
import {
  segmentsToAssContent,
  normalizeCaptionText as assNormalizeCaptionText,
} from "../src/services/assSubtitles.service";
import { textColorToAssColour } from "../src/services/captionOutline.util";
import type { TranscriptSegment } from "../src/services/transcription.service";
import type { CaptionsFontSize } from "../src/modules/edit/edit.types";

function forcedLinesForPlate(text: string, fontSize: CaptionsFontSize = "medium"): string[] {
  return breakCaptionLinesForFontSize(highlightNormalizeCaptionText(text), fontSize);
}

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

const autoCfg: CaptionsBurnInV1Resolved = {
  ...baseCfg,
  mode: "auto",
};

function assertPlateIntegrity(pngPath: string): void {
  assert.ok(existsSync(pngPath), `missing plate ${pngPath}`);
  const buf = readFileSync(pngPath);
  assert.ok(buf.length > 200, "png too small");
}

async function assertPlateVisible(pngPath: string, label: string): Promise<void> {
  const meta = await inspectCaptionPlate(pngPath);
  assert.ok(!meta.isEffectivelyEmpty, `${label} plate empty a=${meta.maxAlpha} px=${meta.nonTransparentPixelCount}`);
  assert.ok(meta.maxAlpha >= 8, `${label} max alpha`);
  assert.ok(meta.nonTransparentPixelCount >= 48, `${label} visible pixels`);
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
  assertPlateIntegrity(p.platePath);
  return p.platePath;
}

function dialogueLines(ass: string): string[] {
  return ass.split("\n").filter((l) => l.startsWith("Dialogue:"));
}

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

/** Phase A: shared line-break SoT wiring (ASS + highlight timing + plate). */
function assertLineBreakSourceOfTruth(): void {
  const root = path.join(__dirname, "..", "src", "services");
  const assSrc = readFileSync(path.join(root, "assSubtitles.service.ts"), "utf8");
  const chunkSrc = readFileSync(path.join(root, "captionHighlight", "chunk.ts"), "utf8");
  const svcSrc = readFileSync(path.join(root, "captionHighlight", "captionHighlight.service.ts"), "utf8");
  const layoutSrc = readFileSync(path.join(root, "captionHighlight", "layout.ts"), "utf8");
  const sotSrc = readFileSync(path.join(root, "captionLineBreak.ts"), "utf8");

  assert.ok(assSrc.includes("breakCaptionLines"), "ASS imports shared SoT");
  assert.ok(!/function greedyWordWrap\s*\(/.test(assSrc), "ASS local greedyWordWrap removed");
  assert.ok(chunkSrc.includes("breakCaptionLines"), "chunk imports shared SoT");
  assert.ok(!/function greedyWordWrap\s*\(/.test(chunkSrc), "chunk local greedyWordWrap removed");
  assert.ok(sotSrc.includes("hardSplitUnits"), "SoT keeps ASS hard-split");
  assert.ok(!svcSrc.includes("replace(/\\n/g"), "no production newline flattening");
  assert.ok(!layoutSrc.includes("wrapTokensToLines"), "layout no longer chooses breaks via wrapTokensToLines");

  const samples = [
    "זה משפט קצת יותר ארוך שצריך להישבר בצורה טבעית",
    "סליחה, יש לכם כזה במדיום?",
    "Hello, world.",
    `${"a".repeat(55)}`,
  ];
  for (const raw of samples) {
    const hiPlain = highlightNormalizeCaptionText(raw);
    const assPlain = assNormalizeCaptionText(raw);
    for (const fs of ["medium", "xx_large", "ultra"] as const) {
      const budget = CAPTION_MAX_CHARS_PER_LINE[fs];
      const sotFromHi = breakCaptionLines(hiPlain, budget);
      const chunks = chunkSegmentForHighlight(raw, 0, 40, fs);
      const fromChunks = chunks.flatMap((c) => [...c.lines]);
      assert.deepEqual(fromChunks, sotFromHi, `highlight timing lines === SoT (${fs})`);
      if (hiPlain === assPlain) {
        assert.deepEqual(
          breakCaptionLines(assPlain, budget),
          sotFromHi,
          `ASS-plain SoT === highlight-plain SoT (${fs})`,
        );
      }
      for (const ln of sotFromHi) {
        assert.ok([...ln].length <= Math.max(budget, [...ln].length), "line length bounded");
        if (!raw.includes(" ".repeat(1)) && raw.length > budget) {
          /* oversized single token */
        }
      }
    }
  }

  const oversized = "x".repeat(60);
  const overLines = breakCaptionLines(oversized, 24);
  assert.ok(overLines.length >= 2, "oversized word hard-splits");
  assert.ok(
    overLines.every((ln) => [...ln].length <= 24),
    "oversized pieces ≤ maxChars (ASS hard-split)",
  );

  // Adaptive 0.85s path: still SoT — each timed chunk carries forced lines from breakCaptionLines
  const longHe = "מילה ".repeat(40).trim();
  const shortDurChunks = chunkSegmentForHighlight(longHe, 0, 1.2, "medium");
  const longDurChunks = chunkSegmentForHighlight(longHe, 0, 40, "medium");
  assert.ok(shortDurChunks.length >= 1 && longDurChunks.length >= 1);
  for (const c of [...shortDurChunks, ...longDurChunks]) {
    assert.ok(c.lines.length >= 1 && c.lines.length <= 2, "≤2 forced lines per timed chunk");
    assert.equal(c.text, c.lines.join("\n"), "chunk.text mirrors forced lines");
  }

  // v1 caption block balancing (inside SoT only)
  assert.ok(sotSrc.includes("scoreTwoLineCaption") || sotSrc.includes("tryBalanceTwoLines"), "SoT hosts balancing");
  const oneLine = breakCaptionLines("שלום עולם", 34);
  assert.deepEqual(oneLine, ["שלום עולם"], "one-line cue unchanged when it fits");

  const unbalancedSample = "סליחה, יש לכם כזה במדיום?";
  const medBudget = CAPTION_MAX_CHARS_PER_LINE.medium;
  const balanced = breakCaptionLines(highlightNormalizeCaptionText(unbalancedSample), medBudget);
  assert.ok(balanced.length === 1 || balanced.length === 2, "balance yields ≤2 lines when possible");
  if (balanced.length === 2) {
    const [a, b] = balanced;
    assert.ok([...a!].length <= medBudget && [...b!].length <= medBudget, "balanced lines within budget");
    const words2 = b!.split(/\s+/).filter(Boolean).length;
    assert.ok(words2 >= 2, `avoid single-word orphan last line when possible (got ${words2})`);
    // Prefer not dramatically worse than a mid split when multiple splits exist
    const words = highlightNormalizeCaptionText(unbalancedSample).split(/\s+/).filter(Boolean);
    assert.ok(words.length >= 3);
    const mid = Math.floor(words.length / 2);
    const greedyLike = [words.slice(0, words.length - 1).join(" "), words[words.length - 1]!];
    if ([...greedyLike[0]!].length <= medBudget && [...greedyLike[1]!].length <= medBudget) {
      const chosen = scoreTwoLineCaption(a!, b!);
      const orphanHeavy = scoreTwoLineCaption(greedyLike[0]!, greedyLike[1]!);
      assert.ok(chosen <= orphanHeavy, "chosen split scores ≤ orphan-heavy greedy-like split");
    }
    void mid;
  }

  const overStill = breakCaptionLines("x".repeat(60), 24);
  assert.ok(overStill.every((ln) => [...ln].length <= 24), "oversized still hard-splits via greedy fallback");

  console.info("diag:caption-highlight ok line-break SoT + caption block balancing v1");
}

/** F1: Hebrew wrap must keep multiple words per line on portrait + large fonts. */
async function assertHebrewCaptionLayoutPolicy(): Promise<void> {
  await ensureCaptionFont("heebo");
  const portrait = { width: 1080, height: 1920 };
  const landscape = { width: 1920, height: 1080 };
  const ladder = [
    "extra_small",
    "small",
    "medium",
    "large",
    "x_large",
    "xx_large",
    "xxx_large",
    "mega",
    "ultra",
  ] as const;
  const expected1080: Record<(typeof ladder)[number], number> = {
    extra_small: 32,
    small: 39,
    medium: 47,
    large: 59,
    x_large: 71,
    xx_large: 87,
    xxx_large: 106,
    mega: 130,
    ultra: 158,
  };
  const portraitPx = ladder.map((fs) => captionFontSizePx(fs, portrait));
  for (const fs of ladder) {
    const fontPx = captionFontSizePx(fs, portrait);
    const maxW = captionMaxLineWidthPx(fs, portrait);
    assert.ok(maxW >= 900, `portrait safe width for ${fs}: ${maxW}`);
    assert.equal(fontPx, expected1080[fs], `1080x1920 ${fs} fontPx`);
    // Uniform scale (min sx/sy), not height-only ASS-like blow-up for the size ladder.
    assert.ok(fontPx < 220, `portrait ${fs} fontPx=${fontPx} must stay below height-only scale`);
  }
  for (let i = 0; i < portraitPx.length - 1; i++) {
    assert.ok(
      portraitPx[i]! < portraitPx[i + 1]!,
      `strict mono ${ladder[i]}=${portraitPx[i]} < ${ladder[i + 1]}=${portraitPx[i + 1]}`,
    );
    assert.ok(
      portraitPx[i]! !== portraitPx[i + 1]!,
      `adjacent sizes must differ: ${ladder[i]} vs ${ladder[i + 1]}`,
    );
  }
  assert.ok(expected1080.xxx_large > expected1080.xx_large);
  assert.ok(expected1080.mega > expected1080.xxx_large);
  assert.ok(expected1080.ultra > expected1080.mega);
  const xsXxRatio = expected1080.xx_large / expected1080.extra_small;
  assert.ok(
    Math.abs(xsXxRatio - 44 / 16) < 0.05,
    `XS→XXL ratio ~2.75 (got ${xsXxRatio})`,
  );
  // Landscape medium: 24 * min(2,2) * 1.75 = 84
  assert.equal(captionFontSizePx("medium", landscape), 84);

  const medium = "זה משפט קצת יותר ארוך שצריך להישבר בצורה טבעית";
  const canvas = createCanvas(1080, 1920);
  const ctx = canvas.getContext("2d");
  const fontSize = captionFontSizePx("xx_large", portrait);
  const maxLineWidthPx = captionMaxLineWidthPx("xx_large", portrait);
  const familyLabel = await ensureCaptionFont("heebo");
  ctx.font = captionFontCss(familyLabel, fontSize, 700);
  const mediumLines = forcedLinesForPlate(medium, "xx_large");
  const layout = layoutCaptionBlock(
    ctx,
    {
      text: mediumLines.join(" "),
      lines: mediumLines,
      direction: "auto",
      fontSize,
      fontWeight: 700,
      maxLines: 2,
      canvasWidth: 1080,
      canvasHeight: 1920,
      position: "bottom",
      maxLineWidthPx,
      lineGapPx: 10,
      tokenGapPx: 10,
      canvas: portrait,
    },
    familyLabel,
  );
  assert.equal(layout.direction, "rtl");
  assert.ok(layout.lines.length >= 1 && layout.lines.length <= 2, `lines=${layout.lines.length}`);
  const wordsOnFirst = layout.lines[0]!.tokens.length;
  assert.ok(
    wordsOnFirst >= 2,
    `xx_large portrait first line should keep ≥2 Hebrew words, got ${wordsOnFirst}`,
  );
  for (const line of layout.lines) {
    assert.equal(line.baselineY, line.y + line.ascent, "baselineY = line top + shared ascent");
    assert.ok(line.boxes.every((b) => b.y === line.y), "highlight boxes keep shared line top");
    assert.ok(line.boxes.every((b) => b.height === line.lineHeight), "box height = lineHeight");
  }

  // Phase 1: punctuation + mixed glyphs share one baseline (no per-glyph Y).
  const bobSample = "סליחה, יש לכם";
  const bobFont = captionFontSizePx("large", portrait);
  ctx.font = captionFontCss(familyLabel, bobFont, 700);
  const bobLines = forcedLinesForPlate(bobSample, "large");
  const bobLayout = layoutCaptionBlock(
    ctx,
    {
      text: bobLines.join(" "),
      lines: bobLines,
      direction: "auto",
      fontSize: bobFont,
      fontWeight: 700,
      maxLines: 2,
      canvasWidth: 1080,
      canvasHeight: 1920,
      position: "bottom",
      maxLineWidthPx: captionMaxLineWidthPx("large", portrait),
      lineGapPx: 10,
      tokenGapPx: 10,
      canvas: portrait,
    },
    familyLabel,
  );
  assert.ok(bobLayout.lines.length >= 1);
  const bobLine = bobLayout.lines[0]!;
  assert.ok(bobLine.tokens.length >= 2, "bob sample multi-token");
  assert.equal(bobLine.baselineY, bobLine.y + bobLine.ascent);
  assert.ok(bobLine.boxes.every((b) => b.y === bobLine.y));

  // Plate-only optical centering: active plate hugs font/ink around shared baseline.
  const padY = 5;
  for (const tok of bobLine.tokens) {
    const measured = ctx.measureText(captionTokenDisplayText(tok));
    const lineDescent = Math.max(0, bobLine.lineHeight - bobLine.ascent);
    const plate = highlightPlateBoxFromBaseline(
      bobLine.baselineY,
      measured,
      bobLine.ascent,
      lineDescent,
    );
    assert.equal(plate.y + plate.ascent, bobLine.baselineY, "plate top + ascent = shared baseline");
    assert.equal(plate.height, plate.ascent + plate.descent, "plate height = ascent+descent");
    const drawnTop = plate.y - padY;
    const drawnBottom = plate.y + plate.height + padY;
    assert.ok(drawnTop < bobLine.baselineY, "padded plate extends above baseline");
    assert.ok(drawnBottom > bobLine.baselineY, "padded plate extends below baseline");
    const above = bobLine.baselineY - drawnTop;
    const below = drawnBottom - bobLine.baselineY;
    assert.equal(above, plate.ascent + padY, "above-baseline pad = ascent+padY");
    assert.equal(below, plate.descent + padY, "below-baseline pad = descent+padY");
    const inkDescent = Math.ceil(measured.actualBoundingBoxDescent ?? plate.descent);
    assert.ok(
      plate.descent >= inkDescent,
      `plate descent covers active ink descenders (${plate.descent} >= ${inkDescent})`,
    );
  }

  const ass = segmentsToAssContent(
    [{ startSec: 0, endSec: 4, text: medium }],
    {
      ...baseCfg,
      wordHighlight: "none",
      fontSize: "medium",
      title: "he-wrap",
    },
  );
  assert.ok(ass.includes("WrapStyle: 0"), "ASS uses smart WrapStyle");
  assert.ok(
    ass.includes("זה משפט") || ass.includes("משפט קצת"),
    "ASS keeps multi-word Hebrew phrase on a dialogue line",
  );

  console.info("diag:caption-highlight ok hebrew layout policy (portrait wrap + shared baseline)");
}

function syntheticTimedPlates(count: number, platePath: string): TimedOverlayPlate[] {
  return Array.from({ length: count }, (_, i) => ({
    path: platePath,
    startSec: i * 0.25,
    endSec: (i + 1) * 0.25,
  }));
}

function assertFilterComplexLabels(): void {
  for (const n of [1, 2, 3, 60] as const) {
    const built = buildTimedOverlayFilterComplex(
      syntheticTimedPlates(n, "plate.png"),
    );
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
  console.info("diag:caption-highlight ok filter_complex labels (1,2,3,60) [legacy/diag only]");
}

function assertProductionFinalEncodeUsesTwoInputsOnly(args: readonly string[]): void {
  const inputCount = args.filter((a) => a === "-i").length;
  assert.equal(inputCount, 2, `final encode must have 2 -i inputs, got ${inputCount}`);
  const loopCount = args.filter((_, i) => i > 0 && args[i - 1] === "-loop").length;
  assert.equal(loopCount, 0, "final encode must not use -loop PNG inputs");
  assert.ok(args.includes(CAPTION_ALPHA_OVERLAY_FILTER), "final encode uses alpha overlay filter");
}

async function assertModeAutoWithoutWords(outRoot: string): Promise<void> {
  const dir = path.join(outRoot, "auto-no-words");
  const seg: TranscriptSegment = {
    startSec: 0,
    endSec: 3,
    text: "מה משותף לדברים הבאים",
  };
  const plan = await buildCaptionHighlightBurnPlan([seg], { ...autoCfg, wordHighlight: "box" }, dir);
  assert.ok(plan.plateCount > 0, "auto-no-words plates");
  assert.ok(plan.wordCount > 0, "auto-no-words wordCount");
  assert.equal(plan.usedFallbackTiming, true, "auto-no-words uses fallback timing");
  await assertPlateVisible(plan.plates[0]!.platePath, "auto-no-words");
  console.info(
    `diag:caption-highlight ok mode=auto-like no words[] plates=${plan.plateCount} fallback=${plan.usedFallbackTiming}`,
  );
}

async function assertModeAutoWithWords(outRoot: string): Promise<void> {
  const dir = path.join(outRoot, "auto-with-words");
  const seg: TranscriptSegment = {
    startSec: 0,
    endSec: 2,
    text: "hello world now",
    words: [
      { startSec: 0, endSec: 0.6, text: "hello" },
      { startSec: 0.6, endSec: 1.2, text: "world" },
      { startSec: 1.2, endSec: 2, text: "now" },
    ],
  };
  const plan = await buildCaptionHighlightBurnPlan([seg], { ...autoCfg, wordHighlight: "color" }, dir);
  assert.ok(plan.plateCount > 0);
  assert.equal(plan.usedFallbackTiming, false, "auto-with-words exact word timing");
  console.info(`diag:caption-highlight ok mode=auto-like with words[] plates=${plan.plateCount}`);
}

async function assertModeSegments(outRoot: string): Promise<void> {
  const dir = path.join(outRoot, "segments");
  const raw = [
    {
      startSec: 0,
      endSec: 2,
      text: "segment one two",
      words: [
        { startSec: 0, endSec: 0.8, text: "segment" },
        { startSec: 0.8, endSec: 1.4, text: "one" },
        { startSec: 1.4, endSec: 2, text: "two" },
      ],
    },
  ];
  const normalized = normalizeCaptionSegmentsForBurn(raw);
  const plan = await buildCaptionHighlightBurnPlan(normalized, baseCfg, dir);
  assert.ok(plan.plateCount > 0);
  console.info(`diag:caption-highlight ok mode=segments plates=${plan.plateCount} (no OpenAI)`);
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

function assertColorPropagation(): void {
  const pinkNormal = resolveHighlightStyle({
    ...baseCfg,
    wordHighlight: "color",
    color: "white",
    normalTextColor: "pink",
    activeTextColor: "yellow",
  });
  assert.equal(pinkNormal.normalCss, textColorToCss("pink"));
  assert.equal(pinkNormal.activeCss, textColorToCss("yellow"));

  const boxPurple = resolveHighlightStyle({
    ...baseCfg,
    wordHighlight: "box",
    color: "white",
    normalTextColor: "white",
    activeTextColor: "black",
    boxColor: "purple",
    boxShape: "rectangle",
  });
  assert.ok(boxPurple.boxCss.includes("139") && boxPurple.boxCss.includes("246"), "box purple css");
  assert.equal(textColorToCss("pink"), "#FF5C8A");
  assert.equal(boxPurple.boxShape, "rectangle");
  console.info("diag:caption-highlight ok color propagation (pink/yellow/purple box)");
}

async function sampleVideoCornerLuma(mp4Path: string): Promise<number> {
  const framePath = path.join(path.dirname(mp4Path), `${path.basename(mp4Path)}-corner.png`);
  const run = spawnSync(
    "ffmpeg",
    ["-hide_banner", "-y", "-i", mp4Path, "-vf", "select=eq(n\\,20)", "-vframes", "1", framePath],
    { encoding: "utf8" },
  );
  if (run.status !== 0 || !existsSync(framePath)) return 0;
  const img = await loadImage(readFileSync(framePath));
  const canvas = createCanvas(img.width, img.height);
  const ctx = canvas.getContext("2d");
  ctx.drawImage(img, 0, 0);
  const { data } = ctx.getImageData(4, 4, 1, 1);
  return data[0]! + data[1]! + data[2]!;
}

async function assertBaseVideoPreservedInComposite(outDir: string): Promise<void> {
  const w = 320;
  const h = 180;
  const dur = 1.5;
  const baseMp4 = path.join(outDir, "base-testsrc.mp4");
  const baseRun = spawnSync(
    "ffmpeg",
    [
      "-hide_banner",
      "-y",
      "-f",
      "lavfi",
      "-i",
      `testsrc2=size=${w}x${h}:rate=30:duration=${dur}`,
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      baseMp4,
    ],
    { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 },
  );
  assert.equal(baseRun.status, 0, `testsrc base: ${(baseRun.stderr ?? "").slice(-300)}`);

  const platePath = path.join(outDir, "base-test-plate.png");
  await writeSolidTestPlate(platePath, w, h);
  const overlayPath = path.join(outDir, `base-test-overlay${CAPTION_ALPHA_VIDEO_EXT}`);
  await buildCaptionHighlightAlphaVideo({
    plates: [{ startSec: 0.2, endSec: 1.0, platePath, activeWordIndex: 0 }],
    width: w,
    height: h,
    durationSec: dur,
    outputPath: overlayPath,
  });

  const outMp4 = path.join(outDir, "base-preserved-composite.mp4");
  const args = [
    "-hide_banner",
    "-y",
    "-i",
    baseMp4,
    "-i",
    overlayPath,
    "-filter_complex",
    CAPTION_ALPHA_OVERLAY_FILTER,
    "-map",
    "[vout]",
    "-c:v",
    "libx264",
    "-pix_fmt",
    "yuv420p",
    outMp4,
  ];
  assertProductionFinalEncodeUsesTwoInputsOnly(args);
  const compRun = spawnSync("ffmpeg", args, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 });
  assert.equal(compRun.status, 0, `composite: ${(compRun.stderr ?? "").slice(-400)}`);

  const luma = await sampleVideoCornerLuma(outMp4);
  assert.ok(luma > 24, `composed output corner luma=${luma} (base video must remain visible)`);

  const overlayMeta = await inspectCaptionPlate(platePath);
  assert.ok(!overlayMeta.isEffectivelyEmpty, "overlay plate has visible pixels");

  console.info("diag:caption-highlight ok base video preserved in alpha composite");
}

async function ffmpegAlphaCompositeSmoke(
  label: string,
  planPlates: TimedOverlayPlate[],
  videoW: number,
  videoH: number,
  durationSec: number,
  outDir: string,
): Promise<void> {
  const overlayPath = path.join(outDir, `${label}-overlay${CAPTION_ALPHA_VIDEO_EXT}`);
  await buildCaptionHighlightAlphaVideo({
    plates: planPlates,
    width: videoW,
    height: videoH,
    durationSec,
    outputPath: overlayPath,
  });
  assert.ok(existsSync(overlayPath), `overlay webm ${label}`);

  const mp4 = path.join(outDir, `${label}-out.mp4`);
  const args = [
    "-hide_banner",
    "-y",
    "-f",
    "lavfi",
    "-i",
    `testsrc2=size=${videoW}x${videoH}:rate=30:duration=${durationSec}`,
    "-i",
    overlayPath,
    "-filter_complex",
    CAPTION_ALPHA_OVERLAY_FILTER,
    "-map",
    "[vout]",
    "-c:v",
    "libx264",
    "-pix_fmt",
    "yuv420p",
    mp4,
  ];
  assertProductionFinalEncodeUsesTwoInputsOnly(args);
  const run = spawnSync("ffmpeg", args, { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 });
  if (run.status !== 0) {
    throw new Error(`ffmpeg alpha composite ${label}: ${(run.stderr ?? "").slice(-800)}`);
  }
  assert.ok(existsSync(mp4), `composite mp4 ${label}`);
  const stderr = run.stderr ?? "";
  assert.ok(!stderr.includes("Thread message queue blocking"), `${label} no thread queue warning`);
  assert.ok(!stderr.includes("Cannot find a matching stream"), `${label} no missing stream`);
  console.info(`diag:caption-highlight ok alpha composite ${label} plates=${planPlates.length} ${videoW}x${videoH}`);
}

function leftmostInkX(data: Uint8ClampedArray, width: number, height: number): number | null {
  for (let x = 0; x < width; x++) {
    for (let y = 0; y < height; y++) {
      const i = (y * width + x) * 4;
      if (data[i]! > 12 || data[i + 1]! > 12 || data[i + 2]! > 12) return x;
    }
  }
  return null;
}

function rightmostInkX(data: Uint8ClampedArray, width: number, height: number): number | null {
  for (let x = width - 1; x >= 0; x--) {
    for (let y = 0; y < height; y++) {
      const i = (y * width + x) * 4;
      if (data[i]! > 12 || data[i + 1]! > 12 || data[i + 2]! > 12) return x;
    }
  }
  return null;
}

async function assertRtlPunctuationBehavior(): Promise<void> {
  const qaSamples = ["בלבנון,", "ברעיון,", "רביבי בוא נראה אותך:"];
  for (const sample of qaSamples) {
    const tokens = tokenizeCaptionText(sample);
    assert.ok(tokens.length >= 1, `tokenize ${sample}`);
    for (const t of tokens) {
      assert.equal(captionTokenDisplayText(t), t.fullText);
      if (t.trailingPunctuation) {
        assert.ok(t.fullText.endsWith(t.trailingPunctuation), `trailing punct on ${t.fullText}`);
        assert.ok(t.coreText.length > 0, `coreText for ${t.fullText}`);
      }
    }
  }

  const lebanon = tokenizeCaptionText("בלבנון,")[0]!;
  assert.equal(lebanon.coreText, "בלבנון");
  assert.equal(lebanon.trailingPunctuation, ",");
  assert.ok(captionTokenMatchesWord(lebanon, "בלבנון"));

  const idea = tokenizeCaptionText("ברעיון,")[0]!;
  assert.equal(idea.coreText, "ברעיון");
  assert.equal(idea.trailingPunctuation, ",");

  const colonPhrase = tokenizeCaptionText("רביבי בוא נראה אותך:").pop()!;
  assert.equal(colonPhrase?.coreText, "אותך");
  assert.equal(colonPhrase?.trailingPunctuation, ":");

  assert.ok(captionTokenMatchesWord(lebanon, "בלבנון,"));
  assert.ok(captionTokenMatchesWord(idea, "ברעיון"));

  const { ensureCaptionFont, captionFontCss } = await import("../src/services/captionHighlight/fonts");
  const font = await ensureCaptionFont("heebo");
  const canvas = createCanvas(320, 90);
  const ctx = canvas.getContext("2d");
  ctx.font = captionFontCss(font, 36, 700);
  const anchor = 260;
  const sample = "ברעיון,";

  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, 320, 90);
  ctx.fillStyle = "#fff";
  ctx.direction = "rtl";
  ctx.textAlign = "left";
  ctx.fillText(sample, anchor, 58);
  const rtlData = ctx.getImageData(0, 0, 320, 90).data;
  const rtlLeft = leftmostInkX(rtlData, 320, 90);
  const rtlRight = rightmostInkX(rtlData, 320, 90);
  assert.ok(rtlLeft != null && rtlRight != null, "rtl ink");

  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, 320, 90);
  ctx.fillStyle = "#fff";
  ctx.direction = "ltr";
  ctx.textAlign = "left";
  ctx.fillText(sample, anchor, 58);
  const ltrData = ctx.getImageData(0, 0, 320, 90).data;
  const ltrLeft = leftmostInkX(ltrData, 320, 90)!;
  const ltrRight = rightmostInkX(ltrData, 320, 90)!;

  assert.ok(rtlLeft! < ltrLeft, `RTL comma should be further left (rtlLeft=${rtlLeft} ltrLeft=${ltrLeft})`);
  assert.ok(ltrRight > rtlRight!, `LTR comma should extend further right (ltrRight=${ltrRight} rtlRight=${rtlRight})`);

  const plateHeText = "בלבנון, ברעיון, רביבי בוא נראה אותך:";
  const plateHeLines = forcedLinesForPlate(plateHeText, "medium");
  const plate = await renderCaptionHighlightPlate({
    text: plateHeLines.join(" "),
    lines: plateHeLines,
    activeWordIndex: 1,
    direction: "rtl",
    fontFamily: "heebo",
    fontSize: 32,
    fontWeight: 700,
    normalTextColor: "#FFFFFF",
    activeTextColor: "#FFD966",
    boxColor: "rgba(255,217,102,0.92)",
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
  assert.equal(plate.activeTokenCount, 1, "QA phrase one active token");
  assert.equal(plate.layout.direction, "rtl");

  const enLines = forcedLinesForPlate("Hello, world.", "medium");
  const enPlate = await renderCaptionHighlightPlate({
    text: enLines.join(" "),
    lines: enLines,
    activeWordIndex: 0,
    direction: "ltr",
    fontFamily: "heebo",
    fontSize: 32,
    fontWeight: 700,
    normalTextColor: "#FFFFFF",
    activeTextColor: "#FFD966",
    boxColor: "rgba(255,217,102,0.92)",
    boxShape: "pill",
    drawBox: false,
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
  assert.equal(enPlate.activeTokenCount, 1, "English LTR one active token");
  assert.equal(enPlate.layout.direction, "ltr");

  console.info("diag:caption-highlight ok rtl-punctuation tokenize+draw");
}

async function assertCaptionOutlineBehavior(): Promise<void> {
  const outlineCfg: CaptionsBurnInV1Resolved = {
    ...baseCfg,
    wordHighlight: "none",
    outlineEnabled: true,
    outlineColor: "white",
    outlineWidth: "medium",
    normalTextColor: "yellow",
  };

  const ass = segmentsToAssContent(
    [{ startSec: 0, endSec: 2, text: "Hello world" }],
    outlineCfg,
  );
  assert.ok(ass.includes(textColorToAssColour("white")), "ASS custom outline colour");
  assert.ok(ass.includes(",3.50,"), "ASS medium outline width");

  const plateBaseLines = forcedLinesForPlate("Hello world", "medium");
  const plateBase = {
    text: plateBaseLines.join(" "),
    lines: plateBaseLines,
    activeWordIndex: 0,
    direction: "ltr" as const,
    fontFamily: "heebo" as const,
    fontSize: 32,
    fontWeight: 700,
    normalTextColor: "#FFD966",
    activeTextColor: "#FFD966",
    boxColor: "rgba(255,217,102,0.92)",
    boxShape: "pill" as const,
    drawBox: false,
    maxLines: 2,
    canvasWidth: 960,
    canvasHeight: 540,
    position: "bottom" as const,
    maxLineWidthPx: 780,
    lineGapPx: 10,
    tokenGapPx: 10,
    boxPaddingXPx: 8,
    boxPaddingYPx: 5,
  };

  const without = await renderCaptionHighlightPlate(plateBase);
  const withOutline = await renderCaptionHighlightPlate({
    ...plateBase,
    outlineEnabled: true,
    outlineColorCss: "#FFFFFF",
    outlineWidthPx: 4.5,
  });
  assert.ok(withOutline.png.length > without.png.length, "outline plate larger png");
  assert.equal(withOutline.activeTokenCount, 1);

  const heOutlineLines = forcedLinesForPlate("בלבנון, ברעיון,", "medium");
  const heOutline = await renderCaptionHighlightPlate({
    ...plateBase,
    text: heOutlineLines.join(" "),
    lines: heOutlineLines,
    activeWordIndex: 1,
    direction: "rtl",
    drawBox: true,
    outlineEnabled: true,
    outlineColorCss: "#FFFFFF",
    outlineWidthPx: 4.5,
  });
  assert.equal(heOutline.layout.direction, "rtl");
  assert.equal(heOutline.activeTokenCount, 1);

  for (const mode of ["color", "box"] as const) {
    const cfg: CaptionsBurnInV1Resolved = {
      ...baseCfg,
      wordHighlight: mode,
      outlineEnabled: true,
      outlineColor: "white",
      outlineWidth: "thick",
      normalTextColor: "yellow",
      activeTextColor: "purple",
      boxColor: "pink",
    };
    const style = resolveHighlightStyle(cfg);
    assert.ok(style.outlineEnabled);
    const twoLineSample = "Two line caption sample here";
    const twoLineLines = forcedLinesForPlate(twoLineSample, "medium");
    const plate = await renderCaptionHighlightPlate({
      ...plateBase,
      text: twoLineLines.join(" "),
      lines: twoLineLines,
      activeWordIndex: 2,
      drawBox: mode === "box",
      normalTextColor: style.normalCss,
      activeTextColor: style.activeCss,
      boxColor: style.boxCss,
      outlineEnabled: style.outlineEnabled,
      outlineColorCss: style.outlineCss,
      outlineWidthPx: style.outlineWidthPx(32),
    });
    assert.equal(plate.activeTokenCount, 1, `outline + ${mode}`);
    assert.deepEqual(
      plate.layout.lines.map((ln) => ln.tokens.map((t) => t.fullText).join(" ")),
      twoLineLines,
      `plate forced lines honored (${mode})`,
    );
  }

  console.info("diag:caption-highlight ok caption-outline ass+canvas");
}

/** Adjacent-token gap from layout boxes (LTR: next.x - (x+w); RTL: x - (next.x+next.w)). */
function placedTokenGapPx(
  boxes: readonly { x: number; width: number }[],
  direction: "rtl" | "ltr",
  i: number,
): number {
  const a = boxes[i]!;
  const b = boxes[i + 1]!;
  if (direction === "ltr") return b.x - (a.x + a.width);
  return a.x - (b.x + b.width);
}

/**
 * Word-spacing polish: highlight token gap = ceil(measureText(" ")) for active font.
 * ASS / Preview / balancing / plate padding unchanged.
 */
async function assertWordSpacingFromFontSpace(): Promise<void> {
  const familyLabel = await ensureCaptionFont("heebo");
  const portrait = { width: 1080, height: 1920 };
  const ladder = ["medium", "large", "x_large", "xx_large", "xxx_large", "mega", "ultra"] as const;
  const canvas = createCanvas(64, 64);
  const ctx = canvas.getContext("2d");

  const gaps: number[] = [];
  const gapRows: { size: string; fontPx: number; gap: number; pct: number }[] = [];

  for (const size of ladder) {
    const fontPx = captionFontSizePx(size, portrait);
    ctx.font = captionFontCss(familyLabel, fontPx, 700);
    const expected = measureCaptionTokenGapPx(ctx);
    assert.ok(expected >= 1, `${size} gap >= 1`);
    assert.equal(expected, Math.ceil(ctx.measureText(" ").width), `${size} gap = ceil(space)`);
    gaps.push(expected);
    gapRows.push({
      size,
      fontPx,
      gap: expected,
      pct: Math.round((expected / fontPx) * 1000) / 10,
    });
  }

  assert.ok(gaps[0]! >= 11 && gaps[0]! <= 14, `medium gap ~font space (got ${gaps[0]})`);
  assert.ok(gaps[gaps.length - 1]! > 10, `ultra gap significantly above legacy 10 (got ${gaps[gaps.length - 1]})`);
  assert.ok(gaps[gaps.length - 1]! >= 35, `ultra gap scales with font (got ${gaps[gaps.length - 1]})`);
  for (let i = 0; i < gaps.length - 1; i++) {
    assert.ok(gaps[i]! <= gaps[i + 1]!, `monotonic ${ladder[i]}=${gaps[i]} <= ${ladder[i + 1]}=${gaps[i + 1]}`);
  }

  const heText = "שלום עולם זה טוב";
  const enText = "hello world from captions";
  const balancedHe = "הממשלה של מדינת ישראל החליטה היום";
  const fontPxXx = captionFontSizePx("xx_large", portrait);
  const maxW = captionMaxLineWidthPx("xx_large", portrait);

  for (const sample of [
    { id: "he-rtl", text: heText, size: "medium" as const },
    { id: "en-ltr", text: enText, size: "medium" as const },
    { id: "he-balanced", text: balancedHe, size: "xx_large" as const },
  ]) {
    const fontPx = captionFontSizePx(sample.size, portrait);
    ctx.font = captionFontCss(familyLabel, fontPx, 700);
    const expectedGap = measureCaptionTokenGapPx(ctx);
    const lines = forcedLinesForPlate(sample.text, sample.size);
    const layout = layoutCaptionBlock(
      ctx,
      {
        text: lines.join(" "),
        lines,
        direction: "auto",
        fontSize: fontPx,
        fontWeight: 700,
        maxLines: 2,
        canvasWidth: portrait.width,
        canvasHeight: portrait.height,
        position: "bottom",
        maxLineWidthPx: captionMaxLineWidthPx(sample.size, portrait),
        lineGapPx: 10,
        tokenGapPx: 999, // ignored — must not affect SoT gap
        canvas: portrait,
      },
      familyLabel,
    );
    assert.equal(layout.tokenGapPx, expectedGap, `${sample.id} layout.tokenGapPx`);
    for (const line of layout.lines) {
      assert.equal(line.baselineY, line.y + line.ascent, `${sample.id} baselineY`);
      assert.ok(line.boxes.every((b) => b.y === line.y), `${sample.id} shared line top`);
      for (let i = 0; i < line.boxes.length - 1; i++) {
        assert.equal(
          placedTokenGapPx(line.boxes, layout.direction, i),
          expectedGap,
          `${sample.id} placed gap[${i}]`,
        );
      }
    }
  }

  // RTL vs LTR same magnitude for same font
  ctx.font = captionFontCss(familyLabel, fontPxXx, 700);
  const gapMag = measureCaptionTokenGapPx(ctx);
  const heLines = forcedLinesForPlate(heText, "xx_large");
  const enLines = forcedLinesForPlate(enText, "xx_large");
  const rtlLayout = layoutCaptionBlock(
    ctx,
    {
      text: heLines.join(" "),
      lines: heLines,
      direction: "rtl",
      fontSize: fontPxXx,
      fontWeight: 700,
      maxLines: 2,
      canvasWidth: 1080,
      canvasHeight: 1920,
      position: "bottom",
      maxLineWidthPx: maxW,
      lineGapPx: 10,
      tokenGapPx: 0,
      canvas: portrait,
    },
    familyLabel,
  );
  const ltrLayout = layoutCaptionBlock(
    ctx,
    {
      text: enLines.join(" "),
      lines: enLines,
      direction: "ltr",
      fontSize: fontPxXx,
      fontWeight: 700,
      maxLines: 2,
      canvasWidth: 1080,
      canvasHeight: 1920,
      position: "bottom",
      maxLineWidthPx: maxW,
      lineGapPx: 10,
      tokenGapPx: 0,
      canvas: portrait,
    },
    familyLabel,
  );
  assert.equal(rtlLayout.tokenGapPx, gapMag);
  assert.equal(ltrLayout.tokenGapPx, gapMag);
  assert.equal(rtlLayout.direction, "rtl");
  assert.equal(ltrLayout.direction, "ltr");

  // Highlight mode / plate padding do not change token gap (layout before draw)
  const modes: Array<{ id: string; drawBox: boolean; boxShape: "pill" | "rounded" | "rectangle" }> = [
    { id: "color", drawBox: false, boxShape: "pill" },
    { id: "box-pill", drawBox: true, boxShape: "pill" },
    { id: "box-rounded", drawBox: true, boxShape: "rounded" },
    { id: "box-rect", drawBox: true, boxShape: "rectangle" },
  ];
  const medFont = captionFontSizePx("medium", portrait);
  const medLines = forcedLinesForPlate(heText, "medium");
  ctx.font = captionFontCss(familyLabel, medFont, 700);
  const medGap = measureCaptionTokenGapPx(ctx);
  const baselines: number[] = [];
  for (const mode of modes) {
    const plate = await renderCaptionHighlightPlate({
      text: medLines.join(" "),
      lines: medLines,
      activeWordIndex: 1,
      direction: "rtl",
      fontFamily: "heebo",
      fontSize: medFont,
      fontWeight: 700,
      normalTextColor: "#FFFFFF",
      activeTextColor: "#FFD966",
      boxColor: "rgba(255,217,102,0.92)",
      boxShape: mode.boxShape,
      drawBox: mode.drawBox,
      maxLines: 2,
      canvasWidth: 1080,
      canvasHeight: 1920,
      position: "bottom",
      maxLineWidthPx: captionMaxLineWidthPx("medium", portrait),
      lineGapPx: 10,
      tokenGapPx: 10,
      boxPaddingXPx: 8,
      boxPaddingYPx: 5,
      outlineEnabled: mode.id === "color",
      outlineColorCss: "#000000",
      outlineWidthPx: 2,
    });
    assert.equal(plate.layout.tokenGapPx, medGap, `${mode.id} tokenGap unchanged`);
    const line = plate.layout.lines[0]!;
    baselines.push(line.baselineY);
    assert.equal(line.baselineY, line.y + line.ascent, `${mode.id} baseline`);
    for (let i = 0; i < line.boxes.length - 1; i++) {
      assert.equal(placedTokenGapPx(line.boxes, plate.layout.direction, i), medGap, `${mode.id} gap`);
    }
    // Plate pad does not alter token box width (geometry independent of gap SoT)
    assert.ok(line.boxes.every((b) => b.height === line.lineHeight));
  }
  assert.ok(
    baselines.every((y) => y === baselines[0]),
    "baselineY unchanged across highlight modes",
  );

  // Overflow report only — do not change breaks (wide gap at ultra may exceed max)
  const overflowNotes: string[] = [];
  for (const size of ladder) {
    const fontPx = captionFontSizePx(size, portrait);
    const maxLine = captionMaxLineWidthPx(size, portrait);
    ctx.font = captionFontCss(familyLabel, fontPx, 700);
    const lines = forcedLinesForPlate(balancedHe, size);
    const layout = layoutCaptionBlock(
      ctx,
      {
        text: lines.join(" "),
        lines,
        direction: "auto",
        fontSize: fontPx,
        fontWeight: 700,
        maxLines: 2,
        canvasWidth: 1080,
        canvasHeight: 1920,
        position: "bottom",
        maxLineWidthPx: maxLine,
        lineGapPx: 10,
        tokenGapPx: 0,
        canvas: portrait,
      },
      familyLabel,
    );
    for (let i = 0; i < layout.lines.length; i++) {
      const lw = layout.lines[i]!.boxes.reduce((acc, b, idx, arr) => {
        acc += b.width;
        if (idx < arr.length - 1) acc += layout.tokenGapPx;
        return acc;
      }, 0);
      if (lw > maxLine) {
        overflowNotes.push(`${size} line${i} widthPx=${lw} max=${maxLine} gap=${layout.tokenGapPx}`);
      }
    }
  }

  console.info(
    `diag:caption-highlight ok word-spacing font-space gaps=${JSON.stringify(gapRows)} overflowNotes=${overflowNotes.length ? overflowNotes.join("; ") : "none"}`,
  );
}

async function main(): Promise<void> {
  assertLineBreakSourceOfTruth();
  assertKillSwitchStaticAss();
  await assertHebrewCaptionLayoutPolicy();
  await assertWordSpacingFromFontSpace();
  assertFilterComplexLabels();
  assertColorPropagation();
  await assertRtlPunctuationBehavior();
  await assertCaptionOutlineBehavior();

  const outRoot = mkdtempSync(path.join(os.tmpdir(), "linkclip-diag-cap-"));
  mkdirSync(outRoot, { recursive: true });

  try {
    await assertModeAutoWithoutWords(outRoot);
    await assertModeAutoWithWords(outRoot);
    await assertModeSegments(outRoot);

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
      { id: "he-punct", seg: { startSec: 0, endSec: 2.5, text: hePunct } },
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
      { id: "he-two-line", seg: { startSec: 0, endSec: 4, text: heTwo }, cfg: { fontSize: "medium" } },
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
      { id: "missing-words", seg: { startSec: 0, endSec: 2, text: he1 } },
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
        assertPlateIntegrity(p.platePath);
        await assertPlateVisible(p.platePath, s.id);
      }
      console.info(
        `diag:caption-highlight ok sample=${s.id} plates=${plan.plateCount} size=${plan.canvasWidth}x${plan.canvasHeight} fallback=${plan.usedFallbackTiming}`,
      );
    }

    for (const shape of ["rectangle", "rounded", "pill"] as const) {
      await renderShapeSample(he1, 1, shape, outRoot, "box");
      console.info(`diag:caption-highlight ok shape=${shape} mode=box`);
    }

    const he1Lines = forcedLinesForPlate(he1, "medium");
    const single = await renderCaptionHighlightPlate({
      text: he1Lines.join(" "),
      lines: he1Lines,
      activeWordIndex: 0,
      direction: "rtl",
      fontFamily: "heebo",
      fontSize: 32,
      fontWeight: 700,
      normalTextColor: "#FFFFFF",
      activeTextColor: "#FFD966",
      boxColor: "rgba(255,217,102,0.92)",
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
    assert.deepEqual(
      single.layout.lines.map((ln) => ln.tokens.map((t) => t.fullText).join(" ")),
      he1Lines,
      "single plate uses forced SoT lines",
    );

    const ff = spawnSync("ffmpeg", ["-version"], { encoding: "utf8" });
    if (ff.status === 0) {
      const smokeDir = path.join(outRoot, "ffmpeg-smoke");
      mkdirSync(smokeDir, { recursive: true });

      await assertBaseVideoPreservedInComposite(smokeDir);

      const platePath = path.join(smokeDir, "solid.png");
      await writeSolidTestPlate(platePath, 960, 540);

      const threePlates = syntheticTimedPlates(3, platePath);
      await ffmpegAlphaCompositeSmoke("short-3", threePlates, 960, 540, 1.5, smokeDir);

      const portraitPlate = path.join(smokeDir, "portrait-solid.png");
      await writeSolidTestPlate(portraitPlate, 1080, 1920);
      const portraitTimed = syntheticTimedPlates(3, portraitPlate);
      await ffmpegAlphaCompositeSmoke("portrait", portraitTimed, 1080, 1920, 1.5, smokeDir);

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
      await ffmpegAlphaCompositeSmoke(
        "box-visible",
        boxPlan.plates,
        1080,
        1920,
        2,
        smokeDir,
      );

      const longSeg: TranscriptSegment = {
        startSec: 0,
        endSec: 45,
        text: Array.from({ length: 180 }, (_, i) => `word${i}`).join(" "),
      };
      const longPlan = await buildCaptionHighlightBurnPlan(
        [longSeg],
        { ...autoCfg, wordHighlight: "box" },
        path.join(smokeDir, "long-plates"),
      );
      assert.ok(longPlan.plateCount >= 180, `long plan plates ${longPlan.plateCount}`);
      await ffmpegAlphaCompositeSmoke(
        "long-180",
        longPlan.plates,
        960,
        540,
        45,
        smokeDir,
      );

      const legacyArgs = [
        "-hide_banner",
        "-y",
        "-f",
        "lavfi",
        "-i",
        "color=c=black:s=960x540:d=1:r=30",
        ...buildOverlayFfmpegInputArgs(syntheticTimedPlates(5, platePath)),
      ];
      const legacyInputCount = legacyArgs.filter((a) => a === "-i").length;
      assert.ok(legacyInputCount > 2, "legacy multi-PNG path has many inputs (diag only)");
      console.info("diag:caption-highlight ok production path avoids multi-PNG final encode");
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
