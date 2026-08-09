FROM node:22-bookworm

# Node 22+ is required for yt-dlp YouTube n/sig challenge solving (external JS via yt-dlp-ejs).
# yt-dlp 2026.07+ marks Node < 22 as unsupported → n-challenge fails → only storyboard formats.
# Official image provides `node` under /usr/local/bin; some tooling probes /usr/bin/node first.
RUN if [ -x /usr/local/bin/node ] && [ ! -e /usr/bin/node ]; then ln -sf /usr/local/bin/node /usr/bin/node; fi

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ffmpeg \
    curl \
    ca-certificates \
    fontconfig \
    fonts-noto-core \
    fonts-noto-extra \
    && rm -rf /var/lib/apt/lists/*

# Caption burn-in fonts (OFL — google/fonts variable TTFs). Not exposed to users; libass/fontconfig only.
RUN mkdir -p /usr/share/fonts/truetype/linkclip \
    && curl -fsSL -o /usr/share/fonts/truetype/linkclip/Heebo-Variable.ttf \
      "https://raw.githubusercontent.com/google/fonts/main/ofl/heebo/Heebo%5Bwght%5D.ttf" \
    && curl -fsSL -o /usr/share/fonts/truetype/linkclip/Rubik-Variable.ttf \
      "https://raw.githubusercontent.com/google/fonts/main/ofl/rubik/Rubik%5Bwght%5D.ttf" \
    && curl -fsSL -o /usr/share/fonts/truetype/linkclip/Assistant-Variable.ttf \
      "https://raw.githubusercontent.com/google/fonts/main/ofl/assistant/Assistant%5Bwght%5D.ttf" \
    && fc-cache -f

RUN ffmpeg -version && ffprobe -version

# Browser impersonation for extractors (e.g. TikTok): curl_cffi via the yt-dlp extra.
# Bare `pip install curl_cffi` alone does not enable usable targets.
# Enables impersonation clients; does not by itself eliminate all TikTok rehydration failures.
RUN python3 -m pip install --break-system-packages --no-cache-dir -U \
      "yt-dlp[default,curl-cffi]" \
      yt-dlp-ejs \
      bgutil-ytdlp-pot-provider

# Fail the image build if impersonation is still unavailable (TikTok reliability).
RUN YT_VER="$(yt-dlp --version | tr -d '\r')" \
    && echo "yt-dlp version=${YT_VER}" \
    && python3 -m pip show yt-dlp yt-dlp-ejs bgutil-ytdlp-pot-provider curl_cffi >/dev/null \
    && python3 -c "import curl_cffi; import yt_dlp_ejs; print('curl_cffi', getattr(curl_cffi,'__version__','?'))" \
    && yt-dlp --list-impersonate-targets 2>&1 | tee /tmp/impersonate-targets.txt \
    && AVAILABLE="$(grep -E 'curl_cffi[[:space:]]*$' /tmp/impersonate-targets.txt | grep -cv 'unavailable' || true)" \
    && test "${AVAILABLE}" -ge 1 \
    && rm -f /tmp/impersonate-targets.txt

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
COPY tsconfig.json ./
COPY src ./src
COPY scripts ./scripts

RUN npx prisma generate
RUN npm run build

ENV NODE_ENV=production

CMD ["npm", "run", "start"]
