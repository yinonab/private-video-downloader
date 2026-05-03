import pino, { type LoggerOptions } from "pino";
import { config } from "../config";

/** Fastify 5+ expects a logger options object here, not a Pino instance. */
export const fastifyLoggerOptions: LoggerOptions = {
  level: process.env.LOG_LEVEL ?? (config.isDev ? "debug" : "info"),
  ...(config.isDev
    ? {
        transport: {
          target: "pino-pretty",
          options: { colorize: true },
        },
      }
    : {}),
};

export const logger = pino(fastifyLoggerOptions);
