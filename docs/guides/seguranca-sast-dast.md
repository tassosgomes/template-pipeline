# Segurança no pipeline: SAST e DAST

## O ponto de partida: as ferramentas erram muito

No OWASP Benchmark, **CodeQL marcou 68,2% dos casos não-vulneráveis como positivos, e o Semgrep
74,8%** ([pesquisa §6.1](../research/2026-09-20-issueops-e-plataformas-no-github.md)).
A maior parte do que qualquer scanner aponta **não é vulnerabilidade real**.

Duas consequências, que explicam todo o desenho desta camada:

1. **Não existe gate de "zero achados".** O gate é por **severidade**.
2. **As ferramentas entram em modo observação.** Quebrar o build no dia 1 é o caminho mais curto
   para o time desativar o scan — e aí a segurança fica pior do que se não houvesse scan nenhum.

## O que roda, e quando

| Camada | Ferramenta | Quando | Reprova? |
|---|---|---|---|
| SAST genérico | Semgrep OSS + regras da plataforma | todo PR | conforme `security-mode` |
| Linter de segurança | gosec (go), bandit (python) | todo PR | conforme `security-mode` |
| Segredos | gitleaks (CLI) | todo PR | **sempre** |
| Dependências (SCA) | Trivy | todo PR | conforme `security-mode` |
| Imagem e IaC | Trivy | quando `build-container: true` | conforme `security-mode` |
| SAST profundo | CodeQL | agendado (`sec-codeql-scheduled.yml`) | conforme configuração |
| DAST | OWASP ZAP | PR (efêmero) e pós-deploy (`sec-dast.yml`) | conforme `security-mode` |

O workflow `sec-codeql.yml` é a implementação reusável; o caller
`sec-codeql-scheduled.yml` deste repositório o executa diariamente às 03:00 UTC e também pode
ser iniciado manualmente. Ele informa explicitamente `csharp`, `java`, `go`,
`javascript-typescript` e `python`, pois os fixtures ficam distribuídos em subdiretórios. O
detalhamento está no [guia de CodeQL agendado](codeql-scheduled.md).

### Cobertura medida dos rulesets OSS

Ao construir a plataforma medimos os rulesets `p/security-audit` + `p/owasp-top-ten` contra os
seis fixtures de `examples/`, cada um com uma vulnerabilidade real plantada. Resultado:

| Stack | Vulnerabilidade plantada | Detectada por |
|---|---|---|
| python | `eval()` sobre entrada | ruleset OSS |
| go | MD5 como hash | ruleset OSS |
| node | `require("child_process").exec` com concatenação | ruleset OSS |
| java | `Runtime.exec` com concatenação | **regra da plataforma** |
| dotnet | SQL concatenado | **regra da plataforma** |
| react-ts | `dangerouslySetInnerHTML` | **regra da plataforma** |

Ou seja: **os rulesets OSS cobrem bem Python, Go e JavaScript, e deixam lacunas em C#,
Java e TypeScript/React.** Por isso a plataforma carrega regras próprias em
`actions/sast/rules/platform.yml`, e por isso o CodeQL agendado importa mais para essas três
stacks — ele é forte justamente onde o Semgrep OSS é fraco.

Duas armadilhas que descobrimos medindo, e que valem para quem for escrever regra nova:

- A regra `detect-child-process` do ruleset OSS casa com o **`require` do CommonJS**, não com
  `import` ESM. O fixture node usa `.cjs` de propósito por causa disso.
- Em JSX, o pattern do atributo solto (`dangerouslySetInnerHTML={{__html: $X}}`) **não parseia**;
  é preciso casar o elemento: `<$EL ... dangerouslySetInnerHTML={$HTML} ... />`.

### Escrevendo uma regra própria

As regras da plataforma ficam em `actions/sast/rules/platform.yml`. Defina sempre
`metadata.security-severity` na escala CVSS — é esse campo que o gate lê para decidir se
reprova. Sem ele, o achado cai no nível derivado do `level` do SARIF.

```yaml
  - id: plataforma-minha-regra
    languages: [csharp]
    severity: ERROR
    message: 'O que está errado e como corrigir.'
    metadata:
      category: security
      cwe: 'CWE-89: ...'
      security-severity: '8.8'   # ≥9 crítico · 7–8,9 alto · 4–6,9 médio
      confidence: MEDIUM
    pattern: ...
```

Teste a regra contra um fixture antes de abrir PR — o job `sast-detecta-vulnerabilidade`
do self-test só valida que *alguma* coisa é detectada, não a sua regra específica.

**Segredo vazado é a única exceção**: roda sempre em `enforce`, com corte em `low`. Não há modo
observação para credencial no repositório — quando ela vaza, já vazou.

## Os controles

```yaml
with:
  security-mode: observe    # observe | enforce
  security-fail-on: high    # none | critical | high | medium | low
  publish-findings: true    # publica no code scanning
```

- `security-mode: observe` — reporta tudo no job summary e na aba Security, **nunca reprova**.
- `security-mode: enforce` — reprova quando houver achado no nível de `security-fail-on` ou acima.

A severidade vem de `security-severity` (escala CVSS) do SARIF, com a faixa do próprio code
scanning: `≥9,0` crítico · `7,0–8,9` alto · `4,0–6,9` médio · abaixo disso, baixo.
Quando a ferramenta não emite esse campo, caímos para o `level` do SARIF.

## Adoção: como sair de observe para enforce

1. **Semana 1–2 — medir.** Deixe `observe` e leia o job summary. O número de achados por PR é o
   dado que importa, não o total histórico.
2. **Triagem.** Para cada achado recorrente: ou corrija, ou registre a supressão com justificativa
   (abaixo). O objetivo é chegar a **zero achados de severidade alta em aberto**.
3. **Subir o gate por degraus.** `enforce` + `security-fail-on: critical` primeiro. Quando estável,
   desça para `high`.
4. **`medium` e `low` normalmente ficam em observação permanente** — é onde mora quase todo o
   falso positivo.

## Supressão: onde e como

A supressão mora no **repositório do serviço** e passa por PR. A exceção vira decisão rastreável,
com autor e revisor, em vez de flag escondida no YAML da plataforma.

| Ferramenta | Arquivo | Formato |
|---|---|---|
| Semgrep | `.semgrepignore` | um caminho ou glob por linha |
| Semgrep (linha específica) | no próprio código | `// nosemgrep: <regra>` |
| Trivy | `.trivyignore` | um CVE por linha |
| gitleaks | `.gitleaksignore` | fingerprint do achado |
| ZAP | `.zap/rules.tsv` | `<id>\tIGNORE\t<motivo>` |

**Sempre com comentário explicando o porquê.** Supressão sem justificativa é dívida que ninguém
consegue reavaliar depois.

```
# .trivyignore
# CVE-2024-XXXXX: só explorável via a API de parsing de XML, que não usamos.
# Reavaliar quando subirmos para a 3.x. — @fulano, 2026-09-20
CVE-2024-XXXXX
```

## Onde os achados aparecem

Depende do plano e da visibilidade do repositório:

| Cenário | Onde os achados aparecem |
|---|---|
| Repositório público | Aba **Security → Code scanning** |
| Privado **com** licença GitHub Code Security | Aba **Security → Code scanning** |
| Privado no plano **Free** | **Artifact SARIF + tabela no job summary** |

### O check do code scanning é separado do nosso gate

Atenção a uma distinção que surpreende: `security-mode: observe` controla **o nosso gate**, mas
publicar um SARIF faz o **próprio code scanning** criar um check no PR, que fica vermelho quando
a análise introduz alertas novos. Ou seja, em modo observação o build não reprova, mas o PR pode
mostrar um check vermelho vindo do code scanning — não do pipeline.

Durante a calibração, se isso incomodar, use `publish-findings: false`: os achados vão para
artifact e job summary, o gate continua sendo aplicado, e nenhum check é criado. Ligue de volta
quando a baseline estiver limpa.

É exatamente por isso que o self-test da plataforma roda com `publish-findings: false`: os
fixtures têm vulnerabilidades plantadas e permanentes, e publicá-las encheria a aba Security da
plataforma de alerta intencional, escondendo achado real.

### Onde os achados aparecem quando publicados

O terceiro caso abaixo é o esperado hoje, **não é falha**. O composite `upload-findings` tenta publicar
no code scanning e, quando o repositório não o tem, degrada automaticamente. O gate de severidade
é aplicado igual nos três cenários. Quando a empresa migrar de plano, os achados passam a aparecer
na aba Security **sem mudar uma linha do YAML do serviço**.

## DAST

DAST precisa de **aplicação rodando** — por isso ele não é um scan de código comum.

### No PR (efêmero)

```yaml
with:
  build-container: true    # obrigatório
  run-dast: true
  dast-port: 8080
  dast-health-path: /health
```

A plataforma sobe a imagem recém-construída, espera o healthcheck e roda o **ZAP baseline**
(passivo, 2 a 5 minutos) contra `localhost`. Se a aplicação não responder ao healthcheck no prazo,
o job falha **mostrando os últimos 100 logs do container** — quase sempre o problema está ali.

Com spec OpenAPI, passe `dast-openapi-spec` e a plataforma troca o baseline pelo `zap-api-scan`,
que é dirigido pela spec e cobre muito mais.

### Pós-deploy

```yaml
jobs:
  dast:
    uses: tassosgomes/template-pipeline/.github/workflows/sec-dast.yml@v1
    permissions: { contents: read, security-events: write }
    with:
      target-url: https://staging.exemplo.com
      scan-type: baseline
      environment: staging
```

### ⚠️ Full scan é tráfego de ataque real

`scan-type: full` faz varredura **ativa**: injeta payloads de verdade. Leva de 30 minutos a horas
e pode sobrecarregar o alvo.

- **Só em agendamento noturno**, nunca no caminho do PR.
- **Só contra ambiente não-produtivo.** A plataforma **bloqueia** automaticamente um full scan
  cujo alvo ou `environment` pareça produção; passar por cima exige `allow-production: true`
  explícito, que fica registrado no YAML e no histórico do PR.

## Perguntas frequentes

**Um achado apareceu e eu acho que é falso positivo.**
Provavelmente é — veja o número lá no topo. Confirme lendo a regra, e então suprima **com
justificativa**. Não desligue o scanner inteiro por causa de uma regra.

**O build ficou mais lento.**
O job de segurança roda **em paralelo** com build e testes, então ele só entra no caminho crítico
se for o mais demorado. Se estiver, o primeiro suspeito é o SCA em árvore de dependências grande:
`run-dependency-scan: false` no PR e chame `sec-sast.yml` em agendamento.

**Preciso rodar só a segurança, sem a CI da plataforma.**
Use `sec-sast.yml` diretamente — ele é um workflow reusável autônomo.

**Por que a CLI do gitleaks e não a action oficial?**
A action exige license key para repositórios de organização desde a v2. A CLI continua MIT.
Ver [referência de pins](../reference/actions-pinadas.md).
