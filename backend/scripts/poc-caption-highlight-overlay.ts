/**
 * Isolated PoC — Creator Captions Highlight overlay renderer (V3.4A).
 * Not wired to production edit worker.
 *
 * Run: npm run poc:caption-highlight
 */
import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  approximateActiveIndices,
  renderCaptionHighlightPlate,
  tokenizeCaptionText,
  type BoxShape,
  type RenderPlateInput,
  type TextDirection,
} from "../src/services/captionHighlight/prototype";

const PLAY_W = 960;
const PLAY_H = 540;

const OUT_DIR = path.join(process.cwd(), ".poc-output", "caption-highlight");

const COLORS = {
  normal: "#FFFFFF",
  active: "#FFD966",
  box: "rgba(255, 217, 102, 0.88)",
};

type SampleDef = {
  readonly id: string;
  readonly text: string;
  readonly direction: TextDirection;
  readonly maxLineWidthPx?: number;
};

const SAMPLES: readonly SampleDef[] = [
  { id: "he1", text: "מה משותף לדברים הבאים", direction: "rtl" },
  { id: "he-punct", text: "שלום, זה מבחן קצר.", direction: "rtl" },
  { id: "en1", text: "What do these things have in common?", direction: "ltr" },
  {
    id: "he-two-line",
    text: "מה משותף לדברים הבאים ולמה זה חשוב מאוד לכולם עכשיו",
    direction: "rtl",
    maxLineWidthPx: 420,
  },
  {
    id: "edited-fallback",
    text: "edited words here now",
    direction: "auto",
  },
];

function baseInput(
  sample: SampleDef,
  activeWordIndex: number,
  boxShape: BoxShape,
): RenderPlateInput {
  return {
    text: sample.text,
    activeWordIndex,
    direction: sample.direction,
    fontFamily: "heebo",
    fontSize: 32,
    fontWeight: 700,
    normalTextColor: COLORS.normal,
    activeTextColor: COLORS.active,
    boxColor: COLORS.box,
    boxShape,
    maxLines: 2,
    canvasWidth: PLAY_W,
    canvasHeight: PLAY_H,
    position: "bottom",
    maxLineWidthPx: sample.maxLineWidthPx ?? 780,
    lineGapPx: 10,
    tokenGapPx: 10,
    boxPaddingXPx: 8,
    boxPaddingYPx: 5,
  };
}

function assertLayoutIntegrity(
  sampleId: string,
  activeIndex: number,
  shape: BoxShape,
  tokenCount: number,
  activeDrawn: number,
  layoutTokenIndices: number[],
): void {
  if (activeDrawn !== 1) {
    throw new Error(`${sampleId} active=${activeIndex} shape=${shape}: active drawn ${activeDrawn} times (expected 1)`);
  }
  const unique = new Set(layoutTokenIndices);
  if (unique.size !== layoutTokenIndices.length) {
    throw new Error(`${sampleId} active=${activeIndex}: duplicate token boxes in layout`);
  }
  if (layoutTokenIndices.length !== tokenCount) {
    throw new Error(
      `${sampleId} active=${activeIndex}: layout has ${layoutTokenIndices.length} tokens, expected ${tokenCount}`,
    );
  }
}

async function renderSamplePlates(
  sample: SampleDef,
  shapes: readonly BoxShape[],
): Promise<{ paths: string[]; he1ForVideo: string[] }> {
  const tokens = tokenizeCaptionText(sample.text);
  const indices = approximateActiveIndices(tokens.length);
  const paths: string[] = [];
  const he1ForVideo: string[] = [];

  for (const activeIndex of indices) {
    const shapeList: BoxShape[] =
      sample.id === "he1" && activeIndex === 1 ? [...shapes] : ["pill"];

    for (const shape of shapeList) {
      const result = await renderCaptionHighlightPlate(baseInput(sample, activeIndex, shape));
      const layoutIndices = result.layout.lines.flatMap((ln) => ln.boxes.map((b) => b.tokenIndex));
      assertLayoutIntegrity(sample.id, activeIndex, shape, tokens.length, result.activeTokenCount, layoutIndices);

      const fileName = `${sample.id}-active${activeIndex}-${shape}.png`;
      const outPath = path.join(OUT_DIR, fileName);
      writeFileSync(outPath, result.png);
      paths.push(outPath);

      if (sample.id === "he1" && shape === "pill") {
        he1ForVideo.push(outPath);
      }

      console.info(
        `poc:caption-highlight ok sample=${sample.id} active=${activeIndex} shape=${shape} dir=${result.layout.direction} tokens=${tokens.length} lines=${result.layout.lines.length}`,
      );
    }
  }

  return { paths, he1ForVideo };
}

function tryFfmpegComposite(platePaths: readonly string[], outMp4: string): boolean {
  if (platePaths.length < 2) return false;
  const ffmpeg = spawnSync("ffmpeg", ["-version"], { encoding: "utf8" });
  if (ffmpeg.status !== 0) {
    console.info("poc:caption-highlight ffmpeg not available — skipping composite MP4");
    return false;
  }

  const duration = platePaths.length;
  const args: string[] = ["-hide_banner", "-y", "-f", "lavfi", "-i", `color=c=black:s=${PLAY_W}x${PLAY_H}:d=${duration}:r=30`];
  for (const p of platePaths) {
    args.push("-loop", "1", "-t", "1", "-i", p);
  }

  let filter = "";
  let prev = "[0:v]";
  for (let i = 0; i < platePaths.length; i++) {
    const next = i === platePaths.length - 1 ? "[vout]" : `[vx${i}]`;
    filter += `${prev}[${i + 1}:v]overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2:enable='between(t,${i},${i + 1})'${next};`;
    prev = next;
  }
  filter = filter.replace(/;$/, "");

  args.push("-filter_complex", filter, "-map", "[vout]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-t", String(duration), outMp4);

  const run = spawnSync("ffmpeg", args, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
  if (run.status !== 0) {
    console.info(`poc:caption-highlight ffmpeg composite failed: ${(run.stderr ?? "").slice(-400)}`);
    return false;
  }
  return true;
}

async function main(): Promise<void> {
  const t0 = Date.now();
  mkdirSync(OUT_DIR, { recursive: true });

  const shapes: BoxShape[] = ["rectangle", "rounded", "pill"];
  const allPaths: string[] = [];
  let he1VideoPlates: string[] = [];

  for (const sample of SAMPLES) {
    const { paths, he1ForVideo } = await renderSamplePlates(sample, shapes);
    allPaths.push(...paths);
    if (he1ForVideo.length) he1VideoPlates = he1ForVideo;
  }

  const mp4Path = path.join(OUT_DIR, "linkclip-caption-highlight-poc.mp4");
  const mp4Ok = tryFfmpegComposite(he1VideoPlates, mp4Path);

  const manifest = {
    outputDir: OUT_DIR,
    pngCount: allPaths.length,
    pngPaths: allPaths,
    mp4: mp4Ok ? mp4Path : null,
    renderer: "@napi-rs/canvas",
    elapsedMs: Date.now() - t0,
    tmpFallback: path.join(os.tmpdir(), "linkclip-caption-highlight-poc"),
  };

  const manifestPath = path.join(OUT_DIR, "manifest.json");
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));

  console.info(`poc:caption-highlight complete png=${allPaths.length} manifest=${manifestPath}`);
  if (mp4Ok) console.info(`poc:caption-highlight mp4=${mp4Path}`);
  else console.info("poc:caption-highlight mp4=skipped");
}

main().catch((err: unknown) => {
  console.error("poc:caption-highlight failed:", err instanceof Error ? err.message : String(err));
  process.exit(1);
});
