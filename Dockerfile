# syntax=docker/dockerfile:1.6

# ---- 第 1 阶段：安装依赖 ----
FROM --platform=$TARGETPLATFORM node:18-bullseye-slim AS deps

ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH

RUN corepack enable && corepack prepare pnpm@8 --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml ./

# 避免 armv7 OOM
ENV NODE_OPTIONS="--max_old_space_size=2048"

RUN pnpm install --frozen-lockfile

# ---- 第 2 阶段：构建项目 ----
FROM --platform=$TARGETPLATFORM node:18-bullseye-slim AS builder

ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
ENV DOCKER_ENV=true

RUN corepack enable && corepack prepare pnpm@8 --activate

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN pnpm run build

# ---- 第 3 阶段：运行时镜像 ----
FROM --platform=$TARGETPLATFORM node:18-bullseye-slim AS runner

RUN groupadd -g 1001 nodejs \
 && useradd -u 1001 -g nodejs -s /bin/bash nextjs

WORKDIR /app

ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000
ENV DOCKER_ENV=true

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/scripts ./scripts
COPY --from=builder --chown=nextjs:nodejs /app/start.js ./start.js
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

CMD ["node", "start.js"]
