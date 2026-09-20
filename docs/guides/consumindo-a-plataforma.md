# Consumindo a plataforma

Cada repositório de serviço tem **um** workflow que chama a pipeline da plataforma.
Não copie YAML de pipeline entre repositórios: referencie.

## Início rápido

Crie `.github/workflows/ci.yml` no repositório do serviço:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  ci:
    uses: tassosgomes/template-pipeline/.github/workflows/ci-node.yml@v1
    permissions:
      contents: read
      security-events: write   # ver a matriz de permissões abaixo
    with:
      version: '22'
      coverage-threshold: 70
```

Troque `ci-node.yml` pelo arquivo da sua stack. **O contrato é idêntico nos seis** (ADR 0002):
os mesmos inputs, os mesmos outputs, os mesmos defaults.

## Permissões: conceda o que você usa

Os workflows da plataforma **não declaram permissões** — cada job recebe exatamente o que o
seu job chamador conceder. Isso é deliberado: em workflow reusável, o que é declarado vira
*exigência* sobre quem chama, e pedir mais do que o chamador concedeu **faz o run falhar na
largada**, sem criar job algum e sem log útil.

| Permissão | Quando é necessária |
|---|---|
| `contents: read` | sempre |
| `security-events: write` | quando `publish-findings: true` (o default) |
| `packages: write` | quando `build-container: true` |
| `packages: read` | quando `run-dast: true` |

Mínimo absoluto, para um repositório que só quer build e testes:

```yaml
    permissions:
      contents: read
    with:
      publish-findings: false
```

### Se o run falhar instantaneamente, sem nenhum job

É quase sempre permissão. A mensagem do GitHub é pouco específica, e o run aparece como
`startup_failure` com zero jobs. Confira a matriz acima antes de procurar qualquer outra causa.

## Um exemplo por stack

```yaml
# .NET
uses: tassosgomes/template-pipeline/.github/workflows/ci-dotnet.yml@v1
with: { version: '8.0.x', coverage-threshold: 70 }

# Java (Maven ou Gradle — detectado automaticamente)
uses: tassosgomes/template-pipeline/.github/workflows/ci-java.yml@v1
with: { version: '21', coverage-threshold: 70 }

# Go
uses: tassosgomes/template-pipeline/.github/workflows/ci-go.yml@v1
with: { version: '1.23', coverage-threshold: 70 }

# Node
uses: tassosgomes/template-pipeline/.github/workflows/ci-node.yml@v1
with: { version: '22', coverage-threshold: 70 }

# Python (pip, uv ou poetry — detectado automaticamente)
uses: tassosgomes/template-pipeline/.github/workflows/ci-python.yml@v1
with: { version: '3.12', coverage-threshold: 70 }

# React + TypeScript (node + tsc --noEmit + relatório de bundle)
uses: tassosgomes/template-pipeline/.github/workflows/ci-react-ts.yml@v1
with: { version: '22', coverage-threshold: 70 }
```

## O contrato

### Inputs

| Input | Tipo | Default | O que faz |
|---|---|---|---|
| `working-directory` | string | `.` | Diretório do projeto (útil em monorepo) |
| `version` | string | *(por stack)* | Versão da linguagem. Vazio usa o default da plataforma |
| `runs-on` | string | `ubuntu-latest` | Runner |
| `platform-ref` | string | `v1` | Versão da plataforma a carregar (ADR 0003) |
| `run-lint` | boolean | `true` | |
| `run-tests` | boolean | `true` | |
| `coverage-threshold` | number | `0` | Cobertura mínima. `0` desliga o gate |
| `lint-args` / `test-args` / `build-args` | string | `''` | Argumentos extras para a ferramenta nativa |
| `build-container` | boolean | `false` | Constrói e publica imagem no GHCR |
| `image-name` | string | *(nome do repo)* | Nome da imagem |
| `upload-artifact` | boolean | `true` | |
| `run-sast` | boolean | `true` | |
| `run-secret-scan` | boolean | `true` | |
| `run-dependency-scan` | boolean | `true` | |
| `security-fail-on` | string | `high` | `none` \| `critical` \| `high` \| `medium` \| `low` |
| `security-mode` | string | `observe` | `observe` (só reporta) \| `enforce` (reprova) |
| `publish-findings` | boolean | `true` | Publica os achados no code scanning. `false` entrega só artifact + job summary |
| `run-dast` | boolean | `false` | DAST efêmero no PR. Exige `build-container: true` |
| `dast-port` | number | `8080` | |
| `dast-health-path` | string | `/health` | |
| `dast-openapi-spec` | string | `''` | Preenchido, troca o baseline pelo api-scan |

### Outputs

| Output | Para que serve |
|---|---|
| `version` | Versão do artefato (tag, ou SHA curto fora de tag) |
| `artifact-name` | Nome do artifact publicado |
| `image-digest` | Digest imutável da imagem. **É o que o CD consome** |
| `coverage` | Cobertura apurada, em percentual |
| `findings` | JSON com a contagem de achados de segurança por severidade |

## Cobertura: o que cada stack precisa

O gate de cobertura só funciona se a ferramenta emitir o relatório que a plataforma lê.
Sem ele, o passo emite um aviso e segue — não reprova.

| Stack | Arquivo lido | Como habilitar |
|---|---|---|
| dotnet | `TestResults/**/coverage.cobertura.xml` | pacote `coverlet.collector` no projeto de testes |
| java | `**/jacoco/jacoco.csv` | plugin `jacoco-maven-plugin` com o goal `report` |
| go | `coverage.out` | automático |
| node / react-ts | `coverage/coverage-summary.json` | reporter `json-summary` no jest/vitest |
| python | `coverage.json` | `pytest-cov` (a plataforma já passa `--cov-report=json`) |

## Monorepo

Um job por serviço, cada um com seu `working-directory`:

```yaml
jobs:
  api:
    uses: tassosgomes/template-pipeline/.github/workflows/ci-go.yml@v1
    with: { working-directory: services/api }

  web:
    uses: tassosgomes/template-pipeline/.github/workflows/ci-react-ts.yml@v1
    with: { working-directory: apps/web }
```

## Fixar uma versão específica da plataforma

`@v1` é uma tag móvel: correções chegam sozinhas. Um serviço que precisa de reprodutibilidade
total pode fixar o SHA da plataforma:

```yaml
uses: tassosgomes/template-pipeline/.github/workflows/ci-go.yml@v1
with:
  platform-ref: 3f2a1b9c...   # SHA exato das composite actions
```

## Armadilhas conhecidas

- **`security-events: write` é obrigatório** para os achados aparecerem na aba Security.
  Sem essa permissão a plataforma **não quebra**: ela degrada para artifact + job summary
  (ver [ADR 0001](../adr/0001-monorepo-publico-da-plataforma.md) e o guia de segurança).
- **Repositório privado no plano Free não tem aba Security.** O fallback acima é o caminho
  normal nesse cenário, não uma falha.
- **Lockfile ausente** faz o build deixar de ser reprodutível. A plataforma avisa, mas não
  reprova. Versione `package-lock.json`, `go.sum`, `poetry.lock` ou equivalente.
- **`build-container: true` exige `Dockerfile`** no `working-directory`.
