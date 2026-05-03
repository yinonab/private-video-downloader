import { Queue } from "bullmq";
import { FastifyPluginAsync } from "fastify";

export const DOWNLOAD_QUEUE_NAME = "download";

declare module "fastify" {
  interface FastifyInstance {
    downloadQueue: Queue;
  }
}

const queuesPlugin: FastifyPluginAsync = async (app) => {
  const connection = app.redis.duplicate({ maxRetriesPerRequest: null });
  const downloadQueue = new Queue(DOWNLOAD_QUEUE_NAME, { connection });
  app.decorate("downloadQueue", downloadQueue);
  app.addHook("onClose", async () => {
    await downloadQueue.close();
    connection.disconnect();
  });
};

export default queuesPlugin;
