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

RUN python3 -m pip install --break-system-packages --no-cache-dir -U yt-dlp yt-dlp-ejs

RUN yt-dlp --version \
    && python3 -m pip show yt-dlp yt-dlp-ejs >/dev/null

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
