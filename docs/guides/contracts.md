# Contratos públicos

O template separa dois gates:

- `openapi-lint.yml` executa Spectral com o ruleset versionado em `rulesets/openapi.yaml`.
- `contract-compatibility.yml` compara operações OpenAPI e o snapshot textual da API pública. Remoções são bloqueadas até que a versão do contrato avance o major.

Exemplo de chamada:

```yaml
jobs:
  openapi:
    uses: tassosgomes/template-pipeline/.github/workflows/openapi-lint.yml@v1
    with:
      spec-glob: 'docs/openapi*.yaml'

  compatibility:
    needs: openapi
    uses: tassosgomes/template-pipeline/.github/workflows/contract-compatibility.yml@v1
    with:
      openapi-base: docs/openapi.base.yaml
      openapi-head: docs/openapi.yaml
      contract-base: contracts/public-api.base.txt
      contract-head: contracts/public-api.txt
      base-version: 1.4.0
      head-version: 1.5.0
```

Para bibliotecas .NET, prefira passar `contracts-base-package` e `contracts-head-package`: a action
instala a versão exata do `Microsoft.DotNet.ApiCompat.Tool` e compara os dois `.nupkg`. O snapshot
textual continua disponível para contratos produzidos por outras linguagens ou para um self-test
sem pacote publicado.

O snapshot de contratos é uma interface de revisão, não um dump de tipos internos. O projeto
consumidor deve regenerá-lo no mesmo passo em que publica o pacote de contratos. Uma remoção
permitida por major ainda exige revisão humana e nota de migração.

## Pacote NuGet Contracts

Uma tag `contracts/v1.2.3` executa `publish-nuget.yml`. O workflow aceita apenas o projeto
`Contracts.csproj`, rejeita `ProjectReference` e valida o `.nupkg` antes de publicar no GitHub
Packages. A permissão de publicação é limitada a `packages: write`; o consumidor usa
`packages: read`.

Para restore local, use um token de leitura com escopo de packages e não o registre no arquivo:

```bash
dotnet nuget add source \
  "https://nuget.pkg.github.com/OWNER/index.json" \
  --name github \
  --username OWNER \
  --password "$GITHUB_TOKEN" \
  --store-password-in-clear-text
dotnet add src/MyService/MyService.csproj package TemplatePipeline.Contracts --version 1.2.3
```

Em CI, prefira um `nuget.config` temporário e `GITHUB_TOKEN`/token de ambiente. O fixture em
`examples/contracts/consumer` usa somente `PackageReference`, nunca `ProjectReference`. Ao
revogar/rotacionar, crie o novo token, valide restore em dev, atualize os Environments e só então
revogue o antigo.
