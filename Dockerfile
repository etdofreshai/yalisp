FROM node:24-alpine

WORKDIR /app

COPY package.json package-lock.json tsconfig.base.json ./
COPY apps/web/package.json apps/web/package.json
COPY packages/site-content/package.json packages/site-content/package.json
RUN npm ci

COPY apps ./apps
COPY packages ./packages

EXPOSE 5173

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:5173/ || exit 1

CMD ["npm", "run", "dev", "--workspace", "@yalisp/web", "--", "--port", "5173", "--strictPort"]

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
