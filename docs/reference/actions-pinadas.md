# Actions de terceiros pinadas

> Gerado a partir dos arquivos do repositório. Verificado por `scripts/check-pins.sh`,
> que roda no self-test e reprova qualquer referência não pinada por SHA.

Tags são móveis: quem comprometer o repositório de uma action reescreve `v4` e passa a
executar código arbitrário em todo pipeline que a referencia (pesquisa §5.2). Por isso
toda action de terceiro é fixada pelo SHA completo do commit, com a tag no comentário ao lado.

| Action | Versão | SHA |
|---|---|---|
| `actions/cache` | v6.1.0 | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` |
| `actions/checkout` | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-dotnet` | v6.0.0 | `a98b56852c35b8e3190ac28c8c2271da59106c68` |
| `actions/setup-go` | v7.0.0 | `b7ad1dad31e06c5925ef5d2fc7ad053ef454303e` |
| `actions/setup-java` | v6.0.1 | `de7274f081f381c8f8158605e0321c36c376e2e6` |
| `actions/setup-node` | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` |
| `actions/setup-python` | v7.0.0 | `5fda3b95a4ea91299a34e894583c3862153e4b97` |
| `actions/upload-artifact` | v7.0.1 | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| `anchore/sbom-action` | v0.24.2 | `3ad7283483fc7af8ff2b4ea19663c2d5ca935e26` |
| `aquasecurity/trivy-action` | v0.36.0 | `ed142fd0673e97e23eac54620cfb913e5ce36c25` |
| `astral-sh/setup-uv` | v10.1.0 | `bec219d24cd3e171d82865faccec33120bb574f4` |
| `docker/build-push-action` | v7.4.0 | `c3c9e263c25d99ce0380d002d59b67737d91b0dc` |
| `docker/login-action` | v4.6.0 | `dbcb813823bdd20940b903addbd779551569679f` |
| `docker/setup-buildx-action` | v4.4.1 | `f87e5991a6d7451dcb8d9637bfbc97413f497069` |
| `github/codeql-action/analyze` | v4 | `1c5b675653bb5c22dbe9b12b556ec555138e09fd` |
| `github/codeql-action/autobuild` | v4 | `1c5b675653bb5c22dbe9b12b556ec555138e09fd` |
| `github/codeql-action/init` | v4 | `1c5b675653bb5c22dbe9b12b556ec555138e09fd` |
| `github/codeql-action/upload-sarif` | v4 | `1c5b675653bb5c22dbe9b12b556ec555138e09fd` |
| `SonarSource/sonarqube-scan-action` | v8.1.0 | `7006c4492b2e0ee0f816d36501671557c97f5995` |
| `golangci/golangci-lint-action` | v9.3.0 | `ba0d7d2ec06a0ea1cb5fa41b2e4a3ab91d21278a` |
| `zaproxy/action-api-scan` | v0.10.0 | `5158fe4d9d8fcc75ea204db81317cce7f9e5453d` |
| `zaproxy/action-baseline` | v0.15.0 | `de8ad967d3548d44ef623df22cf95c3b0baf8b25` |
| `zaproxy/action-full-scan` | v0.13.0 | `3c58388149901b9a03b7718852c5ba889646c27c` |

## Ferramentas executadas por versão (não são actions)

| Ferramenta | Versão | Como é obtida |
|---|---|---|
| Semgrep | `1.177.0` | imagem `semgrep/semgrep`, em `actions/sast` |
| gitleaks (CLI) | `8.30.1` | binário do release, com checksum conferido, em `actions/secret-scan` |
| gosec | `v2.29.0` | `go install`, em `actions/sast` |
| bandit | `1.9.4` | `pip install`, em `actions/sast` |
| actionlint | `1.7.12` | binário do release, em `_selftest.yml` |
| dotnet-sonarscanner | latest (`dotnet tool update`) | instalado em `$RUNNER_TEMP`, em `actions/sonar-scan` |
| Scanner for .NET (JDK) | `21` (Temurin) | via `actions/setup-java` pinado, em `actions/sonar-scan` |

### Por que a CLI do gitleaks, e não a action

A action `gitleaks/gitleaks-action` deixou de ser MIT na v2 e **exige license key para
repositórios de organização** (contas pessoais seguem gratuitas). Como a empresa vai operar
em uma organização, a plataforma usa a CLI oficial, que continua MIT.

## Como atualizar um pin

```bash
# Descobrir o SHA da tag desejada
gh api repos/<owner>/<repo>/commits/<tag> --jq .sha
```

Troque o SHA **e** o comentário da tag, rode `./scripts/check-pins.sh` e abra PR.
O self-test valida a mudança antes do merge.
