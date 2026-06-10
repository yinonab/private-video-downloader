/** Constant playback speed factor for video edits (`1x` omitted from API). */
export type EditSpeedFactor = 0.5 | 1.25 | 1.5 | 2;

/** Constant playback speed factor for audio-only edits (`1x` may be sent explicitly). */
export type AudioEditSpeedFactor = 0.75 | 1 | 1.25 | 1.5 | 2;

export type AudioEditQuality = "standard" | "high" | "best";

export type EditMediaKind = "video" | "audio";

/** How non-original aspect ratio maps into the frame (ignored when aspect is original). Legacy `crop` ops imply `fill`. */
export type EditFormatMode = "fill" | "fit_blur";

/** Clockwise pixel rotation (applied after trim, before format Fill/Fit). Omit when no rotate op was sent. */
export type EditRotationDegrees = 90 | 180 | 270;

/** API `captions.style` — legacy + V3.2 creator styles. `default` aliases to `clean`. */
export type CaptionsStyleApi =
  | "default"
  | "clean"
  | "bold"
  | "dark_box"
  | "clean_pro"
  | "bold_social"
  | "yellow_headline"
  | "dark_bubble"
  | "highlight_box";

/** Normalized caption preset for ASS generation. */
export type CaptionsStyleResolved =
  | "clean"
  | "bold"
  | "dark_box"
  | "clean_pro"
  | "bold_social"
  | "yellow_headline"
  | "dark_bubble"
  | "highlight_box";

export type CaptionsFontSize =
  | "extra_small"
  | "small"
  | "medium"
  | "large"
  | "x_large"
  | "xx_large";

export type CaptionsPosition = "top" | "bottom";

export type CaptionsColor = "white" | "yellow" | "purple" | "mint" | "pink";

/** V3.4B — text/box colors for word-highlight overlay (includes black). */
export type CaptionsTextColor = CaptionsColor | "black";

export type CaptionsBoxShape = "rectangle" | "rounded" | "pill";

export type CaptionsFontFamily =
  | "default"
  | "heebo"
  | "rubik"
  | "assistant"
  | "noto_sans_hebrew";

export type CaptionsWordHighlight = "none" | "color" | "box";

/** Text stroke/outline width preset (ASS + canvas). */
export type CaptionsOutlineWidth = "thin" | "medium" | "thick";

/** Optional word-level cue timing. */
export type CaptionCueWordResolved = {
  readonly startSec: number;
  readonly endSec: number;
  readonly text: string;
};

/** Canonical cue for captions burn-in (after normalization). Never logged as full payload. */
export type CaptionCueSegmentResolved = {
  readonly startSec: number;
  readonly endSec: number;
  readonly text: string;
  readonly words?: readonly CaptionCueWordResolved[];
};

/** Last `captions` op wins — burn-in after trim/rotate/format/speed timeline. */
export type CaptionsBurnInV1Resolved = {
  readonly mode: "auto" | "segments";
  readonly language: "auto";
  readonly burnIn: true;
  readonly style: CaptionsStyleResolved;
  readonly fontSize: CaptionsFontSize;
  readonly fontFamily: CaptionsFontFamily;
  readonly position: CaptionsPosition;
  readonly color: CaptionsColor;
  readonly wordHighlight: CaptionsWordHighlight;
  /** V3.4B overlay — optional; defaults from `color` / highlight mode. */
  readonly normalTextColor?: CaptionsTextColor;
  readonly activeTextColor?: CaptionsTextColor;
  readonly boxColor?: CaptionsTextColor;
  readonly boxShape?: CaptionsBoxShape;
  /** Optional letter stroke/outline (static ASS + highlight canvas). */
  readonly outlineEnabled?: boolean;
  readonly outlineColor?: CaptionsTextColor;
  readonly outlineWidth?: CaptionsOutlineWidth;
  /** Horizontal offset in ASS script pixels (~PlayRes width); clamped −240…240 server-side. */
  readonly offsetX: number;
  /** Vertical offset in ASS script pixels; clamped −180…180. Positive moves down after anchor math. */
  readonly offsetY: number;
  /**
   * Populated only for `mode: "segments"`. May be empty after skipping blank text cues — results in export without overlays.
   * Timestamps align with intermediate edit timeline post trim/speed.
   */
  readonly segments?: readonly CaptionCueSegmentResolved[];
};

export type ResolvedEditPlan = {
  trim?: { startSec: number; endSec: number };
  aspectRatio: "original" | "9:16" | "1:1" | "16:9" | "4:5";
  formatMode?: EditFormatMode;
  /** Video timeline speed. Omit for normal (1×) playback. */
  speedFactor?: EditSpeedFactor;
  /** Audio-only timeline speed (includes 1× when client sends explicit factor). */
  audioSpeedFactor?: AudioEditSpeedFactor;
  /** MP3 export bitrate preset for audio-only pipeline. Defaults to `high` when omitted. */
  audioQuality?: AudioEditQuality;
  /** Clockwise rotation of pixel data (not metadata). Omit when angular offset is 0° (no op). */
  rotationDegrees?: EditRotationDegrees;
  mute: boolean;
  compressPreset: "original" | "social" | "small";
  /** Omit when unused. */
  captionsBurnInV1?: CaptionsBurnInV1Resolved;
};

export type EditQueuePayload = {
  editJobId: string;
  deviceId: string;
};
