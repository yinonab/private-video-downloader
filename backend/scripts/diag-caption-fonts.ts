/**
 * Check fontconfig resolution for caption burn-in families (V3.2).
 * Run: npm run diag:caption-fonts
 */
import { execSync } from "node:child_process";

const families = ["Noto Sans Hebrew", "Heebo", "Rubik", "Assistant"];

function fcMatch(family: string): string {
  try {
    return execSync(`fc-match -f '%{family}\\n' '${family.replace(/'/g, "'\\''")}'`, {
      encoding: "utf8",
    }).trim();
  } catch {
    return "(fc-match failed)";
  }
}

console.info("caption fonts diagnostic (fontconfig):");
for (const f of families) {
  const resolved = fcMatch(f);
  const ok = resolved.toLowerCase().includes(f.split(" ")[0]!.toLowerCase());
  console.info(`  ${f} -> ${resolved}${ok ? "" : " (fallback)"}`);
}

try {
  execSync("fc-list | head -n 3", { encoding: "utf8", stdio: "pipe" });
  console.info("fontconfig: OK");
} catch {
  console.warn("fontconfig: fc-list unavailable");
}
