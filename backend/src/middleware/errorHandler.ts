import { FastifyError, FastifyReply, FastifyRequest } from "fastify";
import { AppError } from "../types/errors";
import { logger } from "../services/logger";

export function errorHandler(
  error: FastifyError | AppError | Error,
  request: FastifyRequest,
  reply: FastifyReply
): void {
  if (error instanceof AppError) {
    reply.status(error.statusCode).send({
      error: {
        code: error.code,
        message: error.message,
        details: error.details,
      },
    });
    return;
  }

  const statusCode = "statusCode" in error && typeof error.statusCode === "number" ? error.statusCode : 500;
  if (statusCode >= 500) {
    logger.error({ err: error, url: request.url }, "Unhandled error");
  }
  reply.status(statusCode).send({
    error: {
      code: "INTERNAL_ERROR",
      message: statusCode >= 500 ? "Internal server error" : error.message,
    },
  });
}
