/** Constant playback speed factor for the edited output (`1x` omitted from API). */
export type EditSpeedFactor = 0.5 | 1.25 | 1.5 | 2;

/** How non-original aspect ratio maps into the frame (ignored when aspect is original). Legacy `crop` ops imply `fill`. */
export type EditFormatMode = "fill" | "fit_blur";

export type ResolvedEditPlan = {
  trim?: { startSec: number; endSec: number };
  aspectRatio: "original" | "9:16" | "1:1" | "16:9" | "4:5";
  formatMode?: EditFormatMode;
  /** When set; constant speed applies to entire output timeline. Omit for normal (1×) playback. */
  speedFactor?: EditSpeedFactor;
  mute: boolean;
  compressPreset: "original" | "social" | "small";
};

export type EditQueuePayload = {
  editJobId: string;
  deviceId: string;
};
