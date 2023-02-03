FROM node:16-bullseye as deps
RUN apt-get update && apt-get install -y curl gzip
WORKDIR /app

COPY package.json ./
COPY prisma/ prisma/
RUN yarn install

RUN curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz && \
    gunzip elm.gz && \
    chmod +x elm

FROM node:16-bullseye as builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/elm /usr/local/bin/elm
COPY --from=deps /home /home
COPY . .
COPY .env-example .env.production
RUN npx prisma generate --schema=./prisma/maxreport.prisma
RUN npx prisma generate --schema=./prisma/exam.prisma
RUN yarn build

FROM node:16-bullseye as runner
WORKDIR /app

ENV NODE_ENV=production

# RUN addgroup -g 1001 -S nodejs
# RUN adduser -S nextjs -u 1001

COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# USER nextjs

EXPOSE 3000
ENV PORT 3000

CMD ["node", "server.js"]
