import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { GlobalFonts } from "@napi-rs/canvas";
import type { CaptionsBurnInV1Resolved } from "../../modules/edit/edit.types";

const HEEBO_URL =
  "https://raw.githubusercontent.com/google/fonts/main/ofl/heebo/Heebo%5Bwght%5D.ttf";

const FONT_FILES: Record<CaptionsBurnInV1Resolved["fontFamily"], string> = {
  default: "Heebo-Variable.ttf",
  heebo: "Heebo-Variable.ttf",
  rubik: "Rubik-Variable.ttf",
  assistant: "Assistant-Variable.ttf",
  noto_sans_hebrew: "Heebo-Variable.ttf",
};

const registered = new Map<string, string>();

async function downloadFont(dest: string, url = HEEBO_URL): Promise<void> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`caption font download HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  mkdirSync(path.dirname(dest), { recursive: true });
  writeFileSync(dest, buf);
}

function fontPathCandidates(fileName: string): string[] {
  return [
    process.env.LINKCLIP_CAPTION_FONT_DIR
      ? path.join(process.env.LINKCLIP_CAPTION_FONT_DIR, fileName)
      : "",
    path.join(process.cwd(), "fonts", "poc", fileName),
    path.join("/usr/share/fonts/truetype/linkclip", fileName),
    path.join(process.cwd(), "fonts", "linkclip", fileName),
  ].filter(Boolean);
}

export async function ensureCaptionFont(
  family: CaptionsBurnInV1Resolved["fontFamily"],
): Promise<string> {
  const cached = registered.get(family);
  if (cached) return cached;

  const fileName = FONT_FILES[family] ?? FONT_FILES.default;
  const label = `LinkClipCap_${family}`;

  for (const p of fontPathCandidates(fileName)) {
    if (existsSync(p)) {
      GlobalFonts.registerFromPath(p, label);
      registered.set(family, label);
      return label;
    }
  }

  const dest = path.join(process.cwd(), "fonts", "linkclip", fileName);
  if (!existsSync(dest)) {
    const url =
      fileName === "Rubik-Variable.ttf"
        ? "https://raw.githubusercontent.com/google/fonts/main/ofl/rubik/Rubik%5Bwght%5D.ttf"
        : fileName === "Assistant-Variable.ttf"
          ? "https://raw.githubusercontent.com/google/fonts/main/ofl/assistant/Assistant%5Bwght%5D.ttf"
          : HEEBO_URL;
    await downloadFont(dest, url);
  }
  GlobalFonts.registerFromPath(dest, label);
  registered.set(family, label);
  return label;
}

export function captionFontCss(family: string, fontSize: number, fontWeight: number): string {
  return `${fontWeight} ${fontSize}px ${family}`;
}
