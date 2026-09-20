# Imagem do fixture node, usada pelo self-test para exercitar o DAST efêmero.
FROM node:22-alpine

WORKDIR /app

# Sem dependências de runtime: copiamos apenas o manifesto e o servidor.
COPY package.json ./
COPY server.mjs ./
COPY src ./src

EXPOSE 8080
USER node

CMD ["node", "server.mjs"]
