# apps/web/Dockerfile

# 1) Build stage
FROM node:20-alpine AS builder
WORKDIR /app

# --- Git metadata (build-time) ---
ARG GIT_COMMIT=local-dev
ARG GIT_BRANCH=local-dev
ENV GIT_COMMIT=$GIT_COMMIT
ENV GIT_BRANCH=$GIT_BRANCH

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# 2) Runtime stage
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# --- Git metadata (runtime, for safety/debugging) ---
ARG GIT_COMMIT=local-dev
ARG GIT_BRANCH=local-dev
ENV GIT_COMMIT=$GIT_COMMIT
ENV GIT_BRANCH=$GIT_BRANCH

# Copy only required output
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000

# Launch Next.js standalone server
CMD ["node", "server.js"]