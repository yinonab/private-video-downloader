export type ResolvedEditPlan = {
  trim?: { startSec: number; endSec: number };
  aspectRatio: "original" | "9:16" | "1:1" | "16:9" | "4:5";
  mute: boolean;
  compressPreset: "original" | "social" | "small";
};

export type EditQueuePayload = {
  editJobId: string;
  deviceId: string;
};
