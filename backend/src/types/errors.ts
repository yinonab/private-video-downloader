export class AppError extends Error {
  readonly statusCode: number;
  readonly code: string;
  readonly details?: string;

  constructor(code: string, message: string, statusCode = 400, details?: string) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    this.name = "AppError";
  }
}

export const codes = {
  INVALID_URL: "INVALID_URL",
  DEVICE_NOT_REGISTERED: "DEVICE_NOT_REGISTERED",
  DEVICE_BLOCKED: "DEVICE_BLOCKED",
  RATE_LIMITED: "RATE_LIMITED",
  INVITE_CODE_INVALID: "INVITE_CODE_INVALID",
  INVITE_CODE_EXPIRED: "INVITE_CODE_EXPIRED",
  ANALYZE_FAILED: "ANALYZE_FAILED",
  DOWNLOAD_FAILED: "DOWNLOAD_FAILED",
  FILE_NOT_FOUND: "FILE_NOT_FOUND",
  JOB_NOT_FOUND: "JOB_NOT_FOUND",
  UNAUTHORIZED: "UNAUTHORIZED",
  CONFLICT: "CONFLICT",
  BAD_REQUEST: "BAD_REQUEST",
} as const;
