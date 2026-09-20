/**
 * VULNERABILIDADE PLANTADA — NÃO CORRIJA.
 *
 * `dangerouslySetInnerHTML` alimentado por entrada não sanitizada é XSS.
 * O Semgrep reporta isto pelos rulesets p/security-audit e p/owasp-top-ten.
 *
 * É este achado que o self-test da plataforma usa para provar que o SAST está realmente
 * analisando o código e que o gate de severidade funciona. Remover isto faz o job
 * `sast-detecta-vulnerabilidade` do _selftest.yml falhar.
 */
export function ComentarioDoUsuario({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
