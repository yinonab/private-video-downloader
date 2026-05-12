import { Queue } from "bullmq";
import { FastifyPluginAsync } from "fastify";
import fp from "fastify-plugin";
import type Redis from "ioredis";

export const DOWNLOAD_QUEUE_NAME = "download";
export const EDIT_QUEUE_NAME = "edit";

declare module "fastify" {
  interface FastifyInstance {
    downloadQueue: Queue;
    editQueue: Queue;
  }
}

const queuesPluginImpl: FastifyPluginAsync = async (app) => {
  const redis = app.redis as Redis | undefined;
  if (redis == null || typeof redis.duplicate !== "function") {
    throw new Error(
      "queuesPlugin: Redis client missing or invalid (expected ioredis with duplicate()). Register the redis plugin before queues."
    );
  }

  const downloadConnection = redis.duplicate({ maxRetriesPerRequest: null });
  const downloadQueue = new Queue(DOWNLOAD_QUEUE_NAME, { connection: downloadConnection });

  const editConnection = redis.duplicate({ maxRetriesPerRequest: null });
  const editQueue = new Queue(EDIT_QUEUE_NAME, { connection: editConnection });

  app.decorate("downloadQueue", downloadQueue);
  app.decorate("editQueue", editQueue);
  app.addHook("onClose", async () => {
    await Promise.all([downloadQueue.close(), editQueue.close()]);
    downloadConnection.disconnect();
    editConnection.disconnect();
  });
};

export default fp(queuesPluginImpl, { name: "queues", dependencies: ["redis"] });
