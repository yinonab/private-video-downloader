/** Safe proxy URL views for logs, diagnostics, and docs — never exposes credentials. */

export type RedactedProxyInfo = {
  configured: boolean;
  valid: boolean;
  scheme?: string;
  host?: string;
  port?: string;
  /** e.g. http://***:***@proxy.example.com:8080 or socks5://***:***@host:1080 */
  proxyUrlRedacted: string;
  providerLabel?: string;
};

export function parseProxyUrl(raw: string): URL | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  try {
    const u = new URL(trimmed);
    if (!u.hostname) return null;
    if (!["http:", "https:", "socks4:", "socks5:", "socks5h:"].includes(u.protocol)) return null;
    return u;
  } catch {
    return null;
  }
}

/** Redact userinfo from a proxy URL for safe display. */
export function redactProxyUrl(raw: string, providerLabel?: string): RedactedProxyInfo {
  const label = providerLabel?.trim() || undefined;
  if (!raw.trim()) {
    return { configured: false, valid: false, proxyUrlRedacted: "-", providerLabel: label };
  }

  const u = parseProxyUrl(raw);
  if (!u) {
    return { configured: true, valid: false, proxyUrlRedacted: "[INVALID_PROXY_URL]", providerLabel: label };
  }

  const scheme = u.protocol.replace(/:$/, "");
  const host = u.hostname;
  const port = u.port || undefined;
  const hasAuth = Boolean(u.username || u.password);
  const portSuffix = port ? `:${port}` : "";
  const redacted = hasAuth
    ? `${scheme}://***:***@${host}${portSuffix}`
    : `${scheme}://${host}${portSuffix}`;

  return {
    configured: true,
    valid: true,
    scheme,
    host,
    port,
    proxyUrlRedacted: redacted,
    providerLabel: label,
  };
}

/** Strip credentials from arbitrary text that may contain proxy URLs. */
export function redactProxyUrlsInText(text: string): string {
  return text.replace(/([a-z][a-z0-9+.-]*):\/\/([^@\s]+)@/gi, "$1://***:***@");
}
