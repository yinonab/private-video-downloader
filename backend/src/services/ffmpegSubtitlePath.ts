/**
 * Build a `-vf` clause for FFmpeg `subtitles`/`ass` overlay from an absolute ASS path.
 */
export function ffmpegSubtitlesVFArgument(absPath: string): string {
  const posix = absPath.trim().replace(/\\/g, "/");
/** Drive letters need escaping for FFmpeg filter parser on Windows. */
  const driveSafe = posix.replace(/^([a-zA-Z]):/, (_, d: string) => `${d}\\:`);
  /** Avoid breaking filter parsers on stray quotes / brackets */
  if (/[',\[\]#]/.test(driveSafe)) {
    const q = driveSafe.replace(/'/g, "'\\''");
    return `subtitles='${q}'`;
  }
  return `subtitles=${driveSafe}`;
}
