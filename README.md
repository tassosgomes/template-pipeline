# template-pipeline

Plataforma interna de entrega da empresa, construída sobre GitHub Actions.

Em vez de cada time copiar YAML de pipeline entre repositórios, cada serviço **referencia** um
workflow reusável daqui. Correções e melhorias chegam a todos os repositórios sem PR em cada um.

```yaml
# .github/workflows/ci.yml no repositório do serviço
jobs:
  ci:
    uses: tassosgomes/template-pipeline/.github/workflows/ci-node.yml@v1
    permissions:
      contents: read
      security-events: write
    with:
      version: '22'
      coverage-threshold: 70
```

## Estado atual

| Fase | Escopo | Estado |
|---|---|---|
| 0 | Pesquisa e decisões de arquitetura | ✅ concluída |
| 1 | Biblioteca de CI reusável + camada de segurança | ✅ concluída |
| 2 | IssueOps: onboarding self-service de serviços | ⏳ a fazer |
| 3 | CD: Vercel, Coolify, AWS, Azure, GCP, OCI | ⏳ a fazer |
| 4 | Catálogo de serviços e auditoria de conformidade | ⏳ a fazer |

## Stacks suportadas

`dotnet` · `java` · `go` · `node` · `python` · `react-ts`

**Os seis workflows expõem o contrato idêntico** — mesmos inputs, mesmos outputs, mesmos defaults
([ADR 0002](docs/adr/0002-contrato-dos-workflows-de-ci.md)). Trocar de stack não muda a forma de
configurar. Um verificador automatizado reprova qualquer divergência.

Cada pipeline faz: `setup → cache → lint → build → testes + cobertura → SAST, segredos e
dependências → empacotamento → [DAST efêmero] → resumo`.

## Documentação

### Comece por aqui
- **[Consumindo a plataforma](docs/guides/consumindo-a-plataforma.md)** — exemplo por stack,
  contrato completo, monorepo, armadilhas conhecidas
- **[Segurança: SAST e DAST](docs/guides/seguranca-sast-dast.md)** — como ler um achado, como
  suprimir com justificativa, como sair de `observe` para `enforce`

### Fundamentos
- **[Pesquisa: como times de DevOps constroem plataformas no GitHub](docs/research/2026-09-20-issueops-e-plataformas-no-github.md)**
  — IssueOps, golden paths, mecanismos de reuso, SAST/DAST e os limites do plano Free
- [ADR 0001 — Monorepo público da plataforma](docs/adr/0001-monorepo-publico-da-plataforma.md)
- [ADR 0002 — Contrato único dos workflows de CI](docs/adr/0002-contrato-dos-workflows-de-ci.md)
- [ADR 0003 — Como os workflows alcançam as composite actions](docs/adr/0003-resolucao-de-actions-locais-em-workflows-reusaveis.md)
- [Referência: actions de terceiros pinadas](docs/reference/actions-pinadas.md)

## Estrutura

```
.github/workflows/     # workflows reusáveis (precisam ficar na raiz desta pasta)
  ci-*.yml             #   pipelines por stack, contrato idêntico
  sec-sast.yml         #   segurança isolada, para quem já tem CI própria
  sec-codeql.yml       #   CodeQL agendado
  sec-dast.yml         #   DAST contra alvo já implantado
  _selftest.yml        #   suíte de regressão da plataforma
  _release.yml         #   publica versão e move a tag major
actions/               # composite actions (as peças)
  sast/rules/          #   regras Semgrep próprias, para lacunas medidas dos rulesets OSS
examples/              # um fixture por stack, com vulnerabilidade plantada
scripts/               # verificadores usados pelo self-test
docs/                  # pesquisa, ADRs, guias, referência
platform.schema.json   # schema do platform.yml dos repositórios consumidores
```

Reusable workflows **precisam** ficar na raiz de `.github/workflows/` — subdiretório não funciona.
Daí a convenção de prefixos (`ci-`, `sec-`, `_`) no lugar de pastas.

## Desenvolvendo a plataforma

```bash
./scripts/check-contract.sh   # os 6 ci-*.yml expõem o mesmo contrato?
./scripts/check-pins.sh       # toda action de terceiro pinada por SHA?
actionlint                    # semântica dos workflows
yamllint --strict -c .yamllint.yml .github/workflows actions
```

O `_selftest.yml` roda tudo isso **e** executa as seis pipelines de ponta a ponta contra os
fixtures de `examples/`, carregando as composite actions do commit em teste
([ADR 0003](docs/adr/0003-resolucao-de-actions-locais-em-workflows-reusaveis.md)).

### Os fixtures contêm vulnerabilidades plantadas de propósito

Cada projeto em `examples/` tem uma falha real e documentada — injeção de comando, `eval`, MD5,
SQL concatenado, XSS. **Não corrija.** É o que prova que o SAST está mesmo analisando o código:
o job `sast-detecta-vulnerabilidade` reprova se o scan retornar zero achados, e confirma que
`observe` não quebra o build enquanto `enforce` quebra.

Foi medindo contra esses fixtures que descobrimos que os rulesets OSS do Semgrep deixam lacunas
em **C#, Java e TypeScript/React** — daí as regras próprias em `actions/sast/rules/`.
Detalhes no [guia de segurança](docs/guides/seguranca-sast-dast.md).

### Publicando uma versão

```bash
git tag v1.2.3 && git push origin v1.2.3
```

O `_release.yml` exige **self-test verde naquele commit** e então move a tag `v1` para ele.
Quem referencia `@v1` recebe a versão automaticamente.

## Decisões que valem conhecer

- **Este repositório é público de propósito.** Contém só YAML, sem segredos. No plano Free, isso
  resolve de uma vez o consumo entre repositórios, os minutos de Actions e os environments
  ([ADR 0001](docs/adr/0001-monorepo-publico-da-plataforma.md)).
- **Segurança começa em modo observação.** Scanners de SAST marcam cerca de 70% dos casos
  não-vulneráveis como positivos; um gate de "zero achados" só ensina o time a desligar o scan.
  O gate é por severidade, e a adoção é gradual.
- **Segredo vazado sempre reprova.** É a única exceção ao modo observação.
- **Governança por auditoria, não por bloqueio.** Rulesets exigem plano Team; até lá, o desvio
  vira issue, não merge bloqueado. O golden path deve ser o caminho mais fácil, não o único.
