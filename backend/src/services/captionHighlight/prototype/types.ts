/** PoC-only types — not wired to production edit API yet. */

export type TextDirection = "auto" | "rtl" | "ltr";

export type BoxShape = "rectangle" | "rounded" | "pill";

export type CaptionPosition = "top" | "bottom" | "center";

export type CaptionToken = {
  readonly index: number;
  readonly text: string;
};

export type CaptionLineLayout = {
  readonly tokens: readonly CaptionToken[];
  /** Visual x of token left edge (LTR) or left edge in canvas coords (RTL: still left edge of glyph run). */
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
  readonly fontFamily: string;
  readonly fontSize: number;
  readonly fontWeight: number;
  readonly normalTextColor: string;
  readonly activeTextColor: string;
  readonly boxColor: string;
  readonly boxShape: BoxShape;
  readonly maxLines: number;
  readonly canvasWidth: number;
  readonly canvasHeight: number;
  readonly position: CaptionPosition;
  readonly maxLineWidthPx: number;
  readonly lineGapPx: number;
  readonly tokenGapPx: number;
  readonly boxPaddingXPx: number;
  readonly boxPaddingYPx: number;
};

export type RenderPlateResult = {
  readonly png: Buffer;
  readonly layout: CaptionLayoutResult;
  readonly activeTokenIndex: number;
  /** Structural check: active token drawn exactly once in layout model. */
  readonly activeTokenCount: number;
};
