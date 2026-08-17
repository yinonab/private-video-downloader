import type {
  CaptionsBoxShape,
  CaptionsBurnInV1Resolved,
  CaptionsPosition,
  CaptionsTextColor,
  CaptionsWordHighlight,
} from "../../modules/edit/edit.types";

export type TextDirection = "auto" | "rtl" | "ltr";

export type BoxShape = CaptionsBoxShape;

export type CaptionToken = {
  readonly index: number;
  /** Full display run (word + attached punctuation) — use for measure/layout/draw. */
  readonly text: string;
  readonly fullText: string;
  /** Word letters/digits without attached punctuation. */
  readonly coreText: string;
  readonly leadingPunctuation?: string;
  readonly trailingPunctuation?: string;
  readonly isWord: boolean;
};

export type CaptionLineLayout = {
  readonly tokens: readonly CaptionToken[];
  readonly boxes: readonly {
    readonly tokenIndex: number;
    readonly x: number;
    readonly y: number;
    readonly width: number;
    readonly height: number;
  }[];
  readonly y: number;
  readonly lineHeight: number;
  /** Shared alphabetic ascent (line top → baseline). Used for text draw only. */
  readonly ascent: number;
  /** Absolute alphabetic baseline Y for every token on this line. */
  readonly baselineY: number;
};

export type CaptionLayoutResult = {
  readonly tokens: readonly CaptionToken[];
  readonly lines: readonly CaptionLineLayout[];
  readonly direction: "rtl" | "ltr";
  readonly blockWidth: number;
  readonly blockHeight: number;
  readonly blockLeft: number;
  readonly blockTop: number;
  /** Inter-token gap actually used (ceil of measured U+0020 advance). */
  readonly tokenGapPx: number;
};

export type RenderPlateInput = {
  /**
   * Forced logical lines from the shared line-break SoT.
   * Layout must not re-wrap; pixel measure is placement/overflow only.
   */
  readonly lines: readonly string[];
  /** Flat text for direction / tokenization identity (`lines` joined with spaces). */
  readonly text: string;
  readonly activeWordIndex: number;
  readonly direction: TextDirection;
  readonly fontFamily: CaptionsBurnInV1Resolved["fontFamily"];
  readonly fontSize: number;
  readonly fontWeight: number;
  readonly normalTextColor: string;
  readonly activeTextColor: string;
  readonly boxColor: string;
  readonly boxShape: BoxShape;
  readonly drawBox: boolean;
  readonly maxLines: number;
  readonly canvasWidth: number;
  readonly canvasHeight: number;
  readonly position: CaptionsPosition;
  readonly maxLineWidthPx: number;
  readonly lineGapPx: number;
  /**
   * Legacy / unused by layout: inter-token gap is derived from measured font-space
   * advance inside `layoutCaptionBlock` (see `measureCaptionTokenGapPx`).
   */
  readonly tokenGapPx: number;
  readonly boxPaddingXPx: number;
  readonly boxPaddingYPx: number;
  readonly offsetY?: number;
  readonly outlineEnabled?: boolean;
  readonly outlineColorCss?: string;
  readonly outlineWidthPx?: number;
};

export type RenderPlateResult = {
  readonly png: Buffer;
  readonly layout: CaptionLayoutResult;
  readonly activeTokenIndex: number;
  readonly activeTokenCount: number;
};

export type TimedPlate = {
  readonly startSec: number;
  readonly endSec: number;
  readonly platePath: string;
  readonly activeWordIndex: number;
};

export type HighlightBurnPlan = {
  readonly plates: readonly TimedPlate[];
  readonly plateCount: number;
  readonly wordCount: number;
  readonly usedFallbackTiming: boolean;
  readonly canvasWidth: number;
  readonly canvasHeight: number;
};

export type ResolvedHighlightStyle = {
  readonly normalCss: string;
  readonly activeCss: string;
  readonly boxCss: string;
  readonly boxShape: BoxShape;
  readonly drawBox: boolean;
  readonly wordHighlight: CaptionsWordHighlight;
  /** Resolved enum colors (safe for logs). */
  readonly normalColor: CaptionsTextColor;
  readonly activeColor: CaptionsTextColor;
  readonly boxColor: CaptionsTextColor;
  readonly outlineEnabled: boolean;
  readonly outlineCss: string;
  readonly outlineWidthPx: (fontSize: number) => number;
};

export type { CaptionsTextColor };
