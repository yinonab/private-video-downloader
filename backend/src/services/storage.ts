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

/** Absolute directory for one upload bundle: `devices/<deviceId>/uploads/<uploadId>/`. */
export function getUploadDir(deviceId: string, uploadId: string): string {
  return path.join(getDeviceBaseDir(deviceId), "uploads", uploadId);
}

const SAFE_SOURCE_EXT = new Set(["mp4", "mov", "webm"]);

/** POSIX storage key for uploaded source video (`source.<ext>`). */
export function uploadSourceStorageKey(deviceId: string, uploadId: string, ext: string): string {
  const normalized = ext.replace(/^\./, "").toLowerCase();
  const safe = SAFE_SOURCE_EXT.has(normalized) ? normalized : "mp4";
  return path.posix.join("devices", deviceId, "uploads", uploadId, `source.${safe}`);
}

/** POSIX storage key for upload JPEG thumbnail. */
export function uploadThumbnailStorageKey(deviceId: string, uploadId: string): string {
  return path.posix.join("devices", deviceId, "uploads", uploadId, "thumbnail.jpg");
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
