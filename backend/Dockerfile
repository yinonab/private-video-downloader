FROM node:20-bookworm

# Node is required for yt-dlp YouTube n/sig challenge solving (external JS via yt-dlp-ejs).
# Official image provides `node` under /usr/local/bin; some tooling probes /usr/bin/node first.
RUN if [ -x /usr/local/bin/node ] && [ ! -e /usr/bin/node ]; then ln -sf /usr/local/bin/node /usr/bin/node; fi

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN ffmpeg -version && ffprobe -version

# Bare `pip install yt-dlp` installs almost no deps (pyproject has dependencies=[]).
# `default` installs yt-dlp-ejs (bundled challenge solver scripts) + requests/websockets/etc.
# `curl-cffi` adds TLS impersonation support when wheels exist for the platform (recommended for YouTube).
RUN python3 -m pip install --break-system-packages --no-cache-dir -U "yt-dlp[default,curl-cffi]" \
    && yt-dlp --version \
    && python3 -m pip show yt-dlp-ejs \
    && node --version \
    && command -v node

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
COPY tsconfig.json ./
COPY src ./src

RUN npx prisma generate
RUN npm run build

ENV NODE_ENV=production

CMD ["npm", "run", "start"]
