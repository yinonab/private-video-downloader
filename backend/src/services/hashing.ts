import crypto from "node:crypto";

export function generateDeviceToken(): string {
  return crypto.randomBytes(32).toString("base64url");
}

export function hashDeviceToken(token: string, secret: string): string {
  return crypto.createHmac("sha256", secret).update(token).digest("hex");
}

export function hashUrl(normalizedUrl: string): string {
  return crypto.createHash("sha256").update(normalizedUrl).digest("hex");
}
