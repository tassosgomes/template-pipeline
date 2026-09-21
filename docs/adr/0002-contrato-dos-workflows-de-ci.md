# ADR 0002 — Contrato único para os workflows de CI

- **Status**: aceito
- **Data**: 2026-09-20

## Contexto

A plataforma precisa suportar seis stacks: dotnet, java, go, node, python e react+typescript.
A tentação natural é escrever seis pipelines independentes, cada uma com os inputs que fazem
sentido para sua linguagem.

## Decisão

Os seis reusable workflows `ci-*.yml` expõem **exatamente a mesma interface** — mesmos nomes de
input, mesmos defaults, mesmos outputs. Diferenças de linguagem ficam **contidas dentro** do
workflow, nunca vazam para o contrato.

O que varia entre stacks é apenas o valor do input `version` e as ferramentas internas. O
contrato também separa o diretório do projeto do contexto Docker (`docker-context`/`dockerfile`),
expõe `test-configuration` para cenários como ArchitectureTests e identifica explicitamente o
serviço quando a pipeline roda em um monorepo (`service-name`).

## Justificativa

1. **Viabiliza o IssueOps da Fase 2.** O workflow de provisionamento não precisa conhecer as
   particularidades de cada linguagem: ele escolhe o arquivo `ci-<stack>.yml` e preenche sempre os
   mesmos campos. Sem o contrato único, o IssueOps precisaria de um gerador por stack.
2. **Viabiliza o CD da Fase 3.** O CD consome `image-digest` e `version` como outputs. Se cada
   stack nomeasse seus outputs à sua maneira, haveria um workflow de deploy por linguagem.
3. **Reduz o custo cognitivo para o time de produto.** Quem trabalha em dois serviços de stacks
   diferentes configura os dois da mesma forma.
4. **Torna o self-test possível.** Um único job parametrizado valida as seis pipelines.

## Consequências

### Negativa aceita conscientemente
O contrato é **o menor denominador comum expressivo**. Uma necessidade muito específica de uma
stack (ex.: perfis do Maven, workspaces do pnpm) não cabe como input dedicado — senão o contrato
incha e vira união de seis contratos.

**Mitigação**: o input `extra-args` por estágio, repassado à ferramenta nativa. A stack ganha
expressividade sem poluir o contrato das outras.

### Regra de evolução
Adicionar input ao contrato exige adicioná-lo **aos seis workflows**, ainda que como no-op em
alguns. Divergência de contrato é tratada como bug, e o `_selftest.yml` verifica isso
automaticamente comparando os blocos `workflow_call` dos seis arquivos.

Os outputs de imagem seguem a mesma regra: `image-digest` é a identidade imutável consumida pelo
CD; `image-ref` e `service` servem para rastreabilidade e não substituem o digest.
