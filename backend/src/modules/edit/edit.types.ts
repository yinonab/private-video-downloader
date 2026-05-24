/** Constant playback speed factor for the edited output (`1x` omitted from API). */
export type EditSpeedFactor = 0.5 | 1.25 | 1.5 | 2;

/** How non-original aspect ratio maps into the frame (ignored when aspect is original). Legacy `crop` ops imply `fill`. */
export type EditFormatMode = "fill" | "fit_blur";

/** Clockwise pixel rotation (applied after trim, before format Fill/Fit). Omit when no rotate op was sent. */
export type EditRotationDegrees = 90 | 180 | 270;

/** Accepted `captions` op for burnt-in captions V1 (OpenAI Whisper). */
export type CaptionsBurnInV1Resolved = {
  readonly mode: "auto";
  readonly language: "auto";
  readonly burnIn: true;
  readonly style: "default";
};

export type ResolvedEditPlan = {
  trim?: { startSec: number; endSec: number };
  aspectRatio: "original" | "9:16" | "1:1" | "16:9" | "4:5";
  formatMode?: EditFormatMode;
  /** When set; constant speed applies to entire output timeline. Omit for normal (1×) playback. */
  speedFactor?: EditSpeedFactor;
  /** Clockwise rotation of pixel data (not metadata). Omit when angular offset is 0° (no op). */
  rotationDegrees?: EditRotationDegrees;
  mute: boolean;
  compressPreset: "original" | "social" | "small";
  /** Last `captions` op wins — burn-in transcription after trim/rotate/format/speed timeline. Omit when unused. */
  captionsBurnInV1?: CaptionsBurnInV1Resolved;
};

export type EditQueuePayload = {
  editJobId: string;
  deviceId: string;
};
