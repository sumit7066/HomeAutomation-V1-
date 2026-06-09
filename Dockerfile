FROM node:20-alpine AS builder
WORKDIR /app

# Install root deps (mostly for server)
COPY package.json .
RUN npm ci

# Install client deps and build
COPY client/package.json client/package.json
RUN cd client && npm ci
COPY client ./client
RUN cd client && npm run build

# Runtime stage
FROM node:20-alpine
WORKDIR /app
COPY package.json .
COPY server ./server
# Copy built client assets
COPY --from=builder /app/client/dist ./server/public
# Install production deps only for server
RUN npm ci --omit=dev
EXPOSE 3000
ENV NODE_ENV=production
CMD ["node", "server/server.js"]
