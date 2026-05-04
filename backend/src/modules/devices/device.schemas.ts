import { z } from "zod";

export const registerDeviceSchema = z.object({
  deviceId: z.string().min(1).max(128),
  deviceName: z.string().max(200).optional(),
  platform: z.enum(["android", "ios", "web"]).optional(),
  /** Required when REQUIRE_INVITE_CODE=true (new devices, or token rotation when true). */
  inviteCode: z.string().max(64).optional(),
});

export type RegisterDeviceInput = z.infer<typeof registerDeviceSchema>;
