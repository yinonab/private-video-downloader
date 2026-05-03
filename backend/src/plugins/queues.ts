import { Queue } from "bullmq";
import { FastifyPluginAsync } from "fastify";
import fp from "fastify-plugin";
import type Redis from "ioredis";

export const DOWNLOAD_QUEUE_NAME = "download";

declare module "fastify" {
  interface FastifyInstance {
    downloadQueue: Queue;
  }
}

const queuesPluginImpl: FastifyPluginAsync = async (app) => {
  const redis = app.redis as Redis | undefined;
  if (redis == null || typeof redis.duplicate !== "function") {
    throw new Error(
      "queuesPlugin: Redis client missing or invalid (expected ioredis with duplicate()). Register the redis plugin before queues."
    );
  }

  const connection = redis.duplicate({ maxRetriesPerRequest: null });
  const downloadQueue = new Queue(DOWNLOAD_QUEUE_NAME, { connection });
  app.decorate("downloadQueue", downloadQueue);
  app.addHook("onClose", async () => {
    await downloadQueue.close();
    connection.disconnect();
  });
};

export default fp(queuesPluginImpl, { name: "queues", dependencies: ["redis"] });
