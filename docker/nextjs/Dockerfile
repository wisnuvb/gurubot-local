FROM node:24-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY artifacts/nextjs/ ./

# npm install tanpa package.json akan mem-prune node_modules standalone (next hilang).
# package.json wajib disalin oleh copy-nextjs-artifact.sh dari .next/standalone/.
RUN test -f package.json || (echo "ERROR: package.json hilang — jalankan copy-nextjs-artifact.sh ulang" && exit 1)

ENV NPM_CONFIG_IGNORE_SCRIPTS=1

# Prisma: pakai engine Linux dari artifact jika ada; jangan rm @prisma/client (npm bisa mem-prune next).
RUN if [ -f prisma/schema.prisma ]; then \
  if [ -f node_modules/.prisma/client/libquery_engine-debian-openssl-3.0.x.so.node ]; then \
    echo "Prisma debian engine OK — skip regenerate"; \
  else \
    npm install prisma@5.22.0 --no-save --legacy-peer-deps --ignore-scripts && \
    npx prisma generate --schema=prisma/schema.prisma && \
    test -f node_modules/.prisma/client/libquery_engine-debian-openssl-3.0.x.so.node \
      || (echo "ERROR: engine Linux Prisma tidak ada — artifact tidak lengkap; minta bundle dari maintainer" && exit 1); \
    test -f node_modules/next/package.json \
      || (echo "ERROR: next hilang setelah prisma install" && exit 1); \
  fi; \
  fi

# Standalone dari Mac hanya bawa @img/sharp-darwin-* — install ulang untuk Linux container.
RUN rm -rf node_modules/@img/sharp-darwin-* node_modules/@img/sharp-libvips-darwin-* \
  && npm install sharp@0.34.5 --no-save --legacy-peer-deps --os=linux --cpu=arm64 2>/dev/null \
  || npm install sharp@0.34.5 --no-save --legacy-peer-deps --os=linux --cpu=x64 2>/dev/null \
  || npm install sharp@0.34.5 --no-save --legacy-peer-deps \
  && test -f node_modules/next/package.json || (echo "ERROR: next hilang setelah sharp install" && exit 1)

ENV NODE_ENV=production
ENV PORT=2050
ENV HOSTNAME=0.0.0.0
ENV SENTRY_DSN=""
ENV OTEL_SDK_DISABLED=true

EXPOSE 2050

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -sf http://127.0.0.1:2050/api/health || exit 1

CMD ["node", "server.js"]
