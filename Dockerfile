FROM node:20-alpine

WORKDIR /app

COPY package.json ./
COPY server.mjs ./

EXPOSE 8787

CMD ["node", "server.mjs"]
