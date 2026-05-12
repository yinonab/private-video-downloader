import "dotenv/config";
import { PrismaClient } from "@prisma/client";
import { createDownloadWorker } from "./download.worker";
import { createEditWorker } from "./edit.worker";
import { logger } from "../services/logger";

async function main(): Promise<void> {
  const prisma = new PrismaClient();
  await prisma.$connect();

  const downloadWorker = createDownloadWorker(prisma);
  const editWorker = createEditWorker(prisma);

  const shutdown = async (): Promise<void> => {
    logger.info("worker shutting down");
    await Promise.all([downloadWorker.close(), editWorker.close()]);
    await prisma.$disconnect();
    process.exit(0);
  };

  process.on("SIGINT", () => void shutdown());
  process.on("SIGTERM", () => void shutdown());

  logger.info("download + edit workers listening");
}

main().catch((err) => {
  logger.error({ err }, "worker crashed");
  process.exit(1);
});
