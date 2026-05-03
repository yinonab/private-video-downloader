import { z } from "zod";

export const registerDeviceSchema = z.object({
  deviceId: z.string().min(1).max(128),
  deviceName: z.string().max(200).optional(),
  platform: z.enum(["android", "ios", "web"]).optional(),
  inviteCode: z.string().min(1).max(64),
});

export type RegisterDeviceInput = z.infer<typeof registerDeviceSchema>;
