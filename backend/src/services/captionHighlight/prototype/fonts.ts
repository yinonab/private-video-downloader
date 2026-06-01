import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { GlobalFonts } from "@napi-rs/canvas";

const HEEBO_URL =
  "https://raw.githubusercontent.com/google/fonts/main/ofl/heebo/Heebo%5Bwght%5D.ttf";

const FONT_CANDIDATES = [
  () => process.env.LINKCLIP_POC_FONT_HEEBO,
  () => path.join(process.cwd(), "fonts", "poc", "Heebo-Variable.ttf"),
  () => "/usr/share/fonts/truetype/linkclip/Heebo-Variable.ttf",
  () => "C:\\Windows\\Fonts\\arial.ttf",
  () => "/usr/share/fonts/truetype/noto/NotoSansHebrew-Regular.ttf",
];

let registeredFamily: string | null = null;

async function downloadHeebo(dest: string): Promise<void> {
  const res = await fetch(HEEBO_URL);
  if (!res.ok) throw new Error(`font download HTTP ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  mkdirSync(path.dirname(dest), { recursive: true });
  writeFileSync(dest, buf);
}

/**
 * Register a Hebrew-capable font for the PoC. Prefers Heebo (matches production Dockerfile intent).
 */
export async function ensurePoCFont(familyLabel = "LinkClipPoCHeebo"): Promise<string> {
  if (registeredFamily) return registeredFamily;

  for (const pick of FONT_CANDIDATES) {
    const p = pick();
    if (p && existsSync(p)) {
      GlobalFonts.registerFromPath(p, familyLabel);
      registeredFamily = familyLabel;
      return familyLabel;
    }
  }

  const dest = path.join(process.cwd(), "fonts", "poc", "Heebo-Variable.ttf");
  if (!existsSync(dest)) {
    await downloadHeebo(dest);
  }
  GlobalFonts.registerFromPath(dest, familyLabel);
  registeredFamily = familyLabel;
  return familyLabel;
}

export function poCFontCss(family: string, fontSize: number, fontWeight: number): string {
  return `${fontWeight} ${fontSize}px ${family}`;
}
