import "dotenv/config";
import { buildApp } from "./app";
import { config } from "./config";
import { logger } from "./services/logger";

async function main(): Promise<void> {
  const app = await buildApp();
  await app.listen({ port: config.PORT, host: "0.0.0.0" });
  logger.info({ port: config.PORT }, "api listening");
}

main().catch((err) => {
  logger.error({ err }, "api failed to start");
  process.exit(1);
});
