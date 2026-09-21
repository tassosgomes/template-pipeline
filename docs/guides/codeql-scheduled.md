# CodeQL agendado

O repositório da plataforma executa o CodeQL pelo caller
`.github/workflows/sec-codeql-scheduled.yml`. Ele oferece dois gatilhos:

- execução diária às **03:00 UTC**;
- `workflow_dispatch` para execução manual.

O workflow reusável `.github/workflows/sec-codeql.yml` continua sendo a implementação da
análise. O caller não duplica essa lógica: apenas fornece o gatilho, as permissões e a
configuração específica deste monorepo de fixtures.

## Linguagens analisadas

As linguagens são informadas explicitamente porque a raiz contém vários projetos em
subdiretórios e não um manifesto único:

`csharp`, `java`, `go`, `javascript-typescript` e `python`.

O identificador `javascript-typescript` cobre os fixtures Node e React/TypeScript. O caller usa
`build-mode: none`, pois os fixtures não formam uma solução raiz única para `autobuild`. Um
repositório consumidor com um projeto compilável único pode escolher outro modo ao chamar
`sec-codeql.yml`.

## Permissões

O caller concede somente:

```yaml
permissions:
  contents: read
  actions: read
  security-events: write
```

`contents: read` permite o checkout, `actions: read` atende à execução do CodeQL em workflows,
e `security-events: write` publica os resultados no Code Scanning. Não são necessários tokens de
escrita em conteúdo, pacotes, issues ou deployments.

## Execução manual

Na aba **Actions**, selecione **Segurança · CodeQL (agendado)** e use **Run workflow**. A
execução manual analisa o branch padrão, assim como o agendamento. Para um consumidor, chame o
workflow reusável e informe a lista de linguagens apropriada ao próprio repositório:

```yaml
jobs:
  codeql:
    uses: tassosgomes/template-pipeline/.github/workflows/sec-codeql.yml@v1
    permissions:
      contents: read
      actions: read
      security-events: write
    with:
      languages: '["javascript-typescript"]'
```

O consumidor deve escolher `build-mode: autobuild` ou `manual` quando a linguagem e a estrutura
do projeto exigirem compilação antes da análise.
