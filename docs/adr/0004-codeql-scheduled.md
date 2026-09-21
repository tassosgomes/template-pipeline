# ADR 0004 — Caller agendado do CodeQL

- **Status**: aceito
- **Data**: 2026-09-20

## Contexto

`sec-codeql.yml` é um workflow reusável: ele define a análise, mas não possui um gatilho
`schedule` próprio. A documentação já descrevia o CodeQL como agendado, porém faltava um
caller executável neste repositório. Sem esse caller, a análise só poderia ser iniciada por
um repositório consumidor.

Este repositório reúne fixtures de todas as stacks suportadas e não tem um projeto raiz único
para o CodeQL construir automaticamente. A detecção por um único manifesto também não cobre
esse formato de monorepo de exemplos.

## Decisão

1. Adicionar `.github/workflows/sec-codeql-scheduled.yml` como caller local de
   `.github/workflows/sec-codeql.yml`.
2. Executá-lo diariamente às 03:00 UTC e disponibilizar `workflow_dispatch` para execução
   manual.
3. Informar explicitamente `csharp`, `java`, `go`, `javascript-typescript` e `python`.
   TypeScript e React são analisados pelo identificador `javascript-typescript` do CodeQL.
4. Usar `build-mode: none`, pois os fixtures estão distribuídos em subdiretórios e não há
   uma solução/projeto raiz único para `autobuild`.
5. Conceder somente `contents: read`, `actions: read` e `security-events: write`. A última
   permissão permite publicar os resultados no Code Scanning; as duas primeiras permitem
   checkout e execução do CodeQL no workflow.
6. Manter as actions de terceiros por SHA no workflow reusável. O caller usa o workflow local
   por caminho relativo, e portanto não introduz uma referência móvel de action.

## Consequências

- A plataforma passa a ter uma execução agendada real, além de um disparo manual para smoke
  test e investigação.
- O caller é específico deste repositório. Consumidores continuam chamando o workflow reusável
  diretamente e devem configurar suas próprias linguagens e permissões.
- O modo sem build favorece a cobertura dos fixtures distribuídos, mas pode produzir menos
  resultados em linguagens compiladas que dependam de resolução de build. Um projeto consumidor
  com uma solução única pode optar por `autobuild` ou `manual` ao chamar o reusable workflow.
- Workflows agendados do GitHub executam a partir do branch padrão; a análise manual é útil para
  validar uma revisão específica desse branch.
