// VULNERABILIDADE PLANTADA — NÃO CORRIJA.
//
// Concatenar entrada do usuário dentro de `child_process.exec` é command injection.
// O Semgrep reporta pela regra javascript.lang.security.detect-child-process, que faz
// parte do ruleset p/security-audit.
//
// É este achado que o self-test da plataforma usa para provar que o SAST está realmente
// analisando o código e que o gate de severidade funciona. Remover isto faz o job
// `sast-detecta-vulnerabilidade` do _selftest.yml falhar.
//
// Nota: o arquivo é .cjs de propósito. A regra do Semgrep casa com o `require` do
// CommonJS; a forma ESM (`import { exec } from "node:child_process"`) NÃO é detectada
// por esse ruleset — verificado ao construir a plataforma.
const cp = require("child_process");

function listarArquivos(diretorioDoUsuario, cb) {
  return cp.exec("ls " + diretorioDoUsuario, cb);
}

module.exports = { listarArquivos };
