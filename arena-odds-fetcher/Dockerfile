# Minimal image — zero runtime npm dependencies, so no install step is needed.
FROM node:20-alpine

WORKDIR /app

# Copy source. (No `npm install` required: the service uses only Node built-ins.
# Playwright is an optional dev-only dependency for the discovery tool.)
COPY package.json ./
COPY src ./src
COPY snapshots ./snapshots

ENV NODE_ENV=production \
    PORT=8080 \
    HOST=0.0.0.0 \
    REFRESH_SECONDS=120 \
    LOG_LEVEL=info

EXPOSE 8080

# Run as the built-in non-root user.
USER node

# Container-level health check hits the readiness endpoint.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+ (process.env.PORT||8080) +'/health').then(r=>r.json()).then(j=>process.exit(j.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/server.js"]
