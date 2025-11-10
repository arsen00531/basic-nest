FROM node:24.11.0-alpine AS builder

ENV NODE_ENV build

WORKDIR /app/backend

COPY package*.json ./
COPY yarn.lock ./

RUN yarn install

COPY --chown=node:node . .
RUN yarn build

# ---

FROM node:24.11.0-alpine

ENV NODE_ENV production

WORKDIR /app/backend

COPY --from=builder --chown=node:node /app/backend/package*.json ./
COPY --from=builder --chown=node:node /app/backend/node_modules/ ./node_modules/
COPY --from=builder --chown=node:node /app/backend/dist/ ./dist/

CMD ["node", "dist/src/main"]
