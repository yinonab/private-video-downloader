import { FastifyPluginAsync } from "fastify";
import fp from "fastify-plugin";
import Redis from "ioredis";
import { config } from "../config";

declare module "fastify" {
  interface FastifyInstance {
    redis: Redis;
  }
}

const redisPluginImpl: FastifyPluginAsync = async (app) => {
  const redis = new Redis(config.REDIS_URL, { maxRetriesPerRequest: null });
  app.decorate("redis", redis);
  app.addHook("onClose", async () => {
    redis.disconnect();
  });
};

export default fp(redisPluginImpl, { name: "redis" });
