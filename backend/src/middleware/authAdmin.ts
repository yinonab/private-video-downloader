import { FastifyRequest } from "fastify";
import { config } from "../config";
import { AppError, codes } from "../types/errors";

export async function authAdmin(request: FastifyRequest): Promise<void> {
  const auth = request.headers.authorization;
  if (!auth?.startsWith("Bearer ")) {
    throw new AppError(codes.UNAUTHORIZED, "Missing admin token", 401);
  }
  const raw = auth.slice("Bearer ".length).trim();
  if (raw !== config.ADMIN_TOKEN) {
    throw new AppError(codes.UNAUTHORIZED, "Invalid admin token", 401);
  }
}
