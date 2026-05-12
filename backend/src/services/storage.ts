import fs from "node:fs/promises";
import path from "node:path";
import { config } from "../config";

export function getDeviceBaseDir(deviceId: string): string {
  return path.join(config.storageDir, "devices", deviceId);
}

export function getVideoDir(deviceId: string): string {
  return path.join(getDeviceBaseDir(deviceId), "videos");
}

export function getAudioDir(deviceId: string): string {
  return path.join(getDeviceBaseDir(deviceId), "audio");
}

export function getThumbDir(deviceId: string): string {
  return path.join(getDeviceBaseDir(deviceId), "thumbs");
}

export function getEditsDir(deviceId: string): string {
  return path.join(getDeviceBaseDir(deviceId), "edits");
}

export async function ensureDeviceDirs(deviceId: string): Promise<void> {
  await fs.mkdir(getVideoDir(deviceId), { recursive: true });
  await fs.mkdir(getAudioDir(deviceId), { recursive: true });
  await fs.mkdir(getThumbDir(deviceId), { recursive: true });
  await fs.mkdir(getEditsDir(deviceId), { recursive: true });
}

export function resolveAbsoluteFromStorageKey(storageKey: string): string {
  const normalized = storageKey.replace(/\\/g, "/").replace(/^\/+/, "");
  const base = path.resolve(config.storageDir);
  const resolved = path.resolve(base, normalized);
  const rel = path.relative(base, resolved);
  if (rel.startsWith("..") || path.isAbsolute(rel)) {
    throw new Error("Invalid storage key");
  }
  return resolved;
}

export async function deleteJobFilesFromDisk(deviceId: string, jobId: string): Promise<void> {
  const dirs = [getVideoDir(deviceId), getAudioDir(deviceId), getThumbDir(deviceId)];
  for (const dir of dirs) {
    let entries: string[];
    try {
      entries = await fs.readdir(dir);
    } catch {
      continue;
    }
    const matches = entries.filter((f) => f.startsWith(`${jobId}.`) || f.startsWith(`${jobId}_`));
    await Promise.all(matches.map((f) => fs.unlink(path.join(dir, f)).catch(() => undefined)));
  }
}
