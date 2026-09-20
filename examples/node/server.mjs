// Servidor mínimo que serve de alvo ao DAST no self-test da plataforma.
//
// Ele responde /health (o que o ephemeral-app espera) e serve uma página SEM os
// headers de segurança usuais (CSP, X-Content-Type-Options, X-Frame-Options).
// Essa ausência é deliberada: é o achado que o ZAP baseline precisa reportar para
// provar que o DAST está mesmo analisando a aplicação.
import { createServer } from "node:http";

const port = Number(process.env.PORT ?? 8080);

createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end("<!doctype html><html lang=\"pt-BR\"><head><title>Fixture</title></head><body><h1>Alvo do DAST</h1></body></html>");
}).listen(port, () => {
  console.log(`fixture ouvindo em http://0.0.0.0:${port}`);
});
