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
  readonly text: string;
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
};

export type CaptionLayoutResult = {
  readonly tokens: readonly CaptionToken[];
  readonly lines: readonly CaptionLineLayout[];
  readonly direction: "rtl" | "ltr";
  readonly blockWidth: number;
  readonly blockHeight: number;
  readonly blockLeft: number;
  readonly blockTop: number;
};

export type RenderPlateInput = {
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
  readonly tokenGapPx: number;
  readonly boxPaddingXPx: number;
  readonly boxPaddingYPx: number;
  readonly offsetY?: number;
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
};

export type { CaptionsTextColor };
