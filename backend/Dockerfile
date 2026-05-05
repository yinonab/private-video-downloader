FROM node:20-bookworm

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ffmpeg \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN ffmpeg -version && ffprobe -version

RUN python3 -m pip install --break-system-packages -U yt-dlp
RUN yt-dlp --version

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
