import dns from "node:dns/promises";
import net from "node:net";
import { AppError, codes } from "../types/errors";

const BLOCKED_HOSTNAMES = new Set([
  "localhost",
  "127.0.0.1",
  "0.0.0.0",
  "::1",
  "metadata.google.internal",
]);

function isPrivateIPv4(parts: number[]): boolean {
  const [a, b] = parts;
  if (a === 10) return true;
  if (a === 127) return true;
  if (a === 0) return true;
  if (a === 169 && b === 254) return true;
  if (a === 192 && b === 168) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 100 && b >= 64 && b <= 127) return true;
  return false;
}

function isPrivateIPv6(addr: string): boolean {
  const lower = addr.toLowerCase();
  if (lower === "::1") return true;
  if (lower.startsWith("fc") || lower.startsWith("fd")) return true;
  if (lower.startsWith("fe80:")) return true;
  return false;
}

export function normalizeUrl(urlString: string): string {
  const u = new URL(urlString.trim());
  if (u.protocol !== "http:" && u.protocol !== "https:") {
    throw new AppError(codes.INVALID_URL, "Only http(s) URLs are allowed", 400);
  }
  u.hash = "";
  return u.toString();
}

export async function assertUrlSafeForFetch(urlString: string): Promise<void> {
  let parsed: URL;
  try {
    parsed = new URL(urlString.trim());
  } catch {
    throw new AppError(codes.INVALID_URL, "Invalid URL", 400);
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new AppError(codes.INVALID_URL, "Only http(s) URLs are allowed", 400);
  }

  const host = parsed.hostname.toLowerCase();
  if (BLOCKED_HOSTNAMES.has(host)) {
    throw new AppError(codes.INVALID_URL, "Host is not allowed", 400);
  }

  if (net.isIP(host)) {
    if (net.isIPv4(host)) {
      const parts = host.split(".").map((p: string) => Number(p));
      if (parts.length !== 4 || parts.some((n) => Number.isNaN(n))) {
        throw new AppError(codes.INVALID_URL, "Invalid IPv4", 400);
      }
      if (isPrivateIPv4(parts)) {
        throw new AppError(codes.INVALID_URL, "Private network addresses are not allowed", 400);
      }
    } else if (net.isIPv6(host)) {
      if (isPrivateIPv6(host)) {
        throw new AppError(codes.INVALID_URL, "Private network addresses are not allowed", 400);
      }
    }
    return;
  }

  let records: { family: number; address: string }[];
  try {
    records = await dns.lookup(host, { all: true });
  } catch {
    throw new AppError(codes.INVALID_URL, "Could not resolve host", 400);
  }

  for (const r of records) {
    if (net.isIPv4(r.address)) {
      const parts = r.address.split(".").map((p: string) => Number(p));
      if (isPrivateIPv4(parts)) {
        throw new AppError(codes.INVALID_URL, "Resolved to a private network address", 400);
      }
    } else if (net.isIPv6(r.address)) {
      if (isPrivateIPv6(r.address)) {
        throw new AppError(codes.INVALID_URL, "Resolved to a private network address", 400);
      }
    }
  }
}
