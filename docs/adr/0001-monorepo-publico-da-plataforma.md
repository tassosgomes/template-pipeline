# ADR 0001 — Monorepo público para a plataforma

- **Status**: aceito
- **Data**: 2026-09-20
- **Contexto da decisão**: [pesquisa §7](../research/2026-09-20-issueops-e-plataformas-no-github.md#7-restrições-do-plano-github-free-verificadas-na-documentação)

## Contexto

A empresa está no plano **GitHub Free**. A documentação oficial confirma as seguintes restrições:

| Recurso | Free |
|---|---|
| Environments + required reviewers | só em repositório **público** |
| Code Scanning / upload de SARIF | grátis em **público**; em privado exige licença GitHub Code Security |
| Rulesets | exige Team ou Enterprise |
| Minutos de Actions | **ilimitados** em público; 2.000/mês em privado |

Precisamos decidir onde a biblioteca de workflows reusáveis vai morar e qual a visibilidade dela.

## Decisão

1. A plataforma vive em **um único repositório** (`tassosgomes/template-pipeline`), contendo
   composite actions, reusable workflows, fixtures e documentação.
2. Esse repositório é **público**.

## Justificativa

**Por que monorepo.** O time de plataforma é pequeno. Repositórios separados por função
(`platform-actions`, `platform-workflows`, ...) impõem versionamento cruzado e PRs coordenados
para qualquer mudança que atravesse camadas — custo alto sem benefício proporcional nesta escala.
Um repositório único mantém uma tag = um estado coerente da plataforma inteira.

**Por que público.** O conteúdo é exclusivamente YAML de pipeline, sem segredo, sem código
proprietário e sem dado de negócio. Tornando-o público, quatro problemas desaparecem de uma vez:

- consumo cross-repo funciona sem configuração de Actions access;
- minutos de Actions do *self-test* da plataforma passam a ser ilimitados;
- os environments do próprio repositório da plataforma funcionam;
- o CodeQL do próprio repositório roda de graça.

## Consequências

### Positivas
- Zero fricção de acesso para qualquer repositório consumidor da organização.
- Custo zero de minutos para o self-test, que roda 6 pipelines completas.

### Negativas e mitigações
- **Nossas convenções de pipeline ficam visíveis publicamente.** Mitigação: nenhum segredo,
  endpoint interno, nome de host ou identificador de conta pode entrar no YAML — tudo vem de
  `secrets` e `vars` do repositório consumidor. Isso é verificado pelo scan de segredos que a
  própria plataforma roda sobre si mesma no `_selftest.yml`.
- **Contribuição externa não solicitada (PRs de fork).** Mitigação: `pull_request_target` é
  proibido no repositório, e a configuração de Actions exige aprovação para workflows de
  colaborador de primeira viagem.

## Revisitar quando

A empresa migrar para **GitHub Team ou Enterprise**. Nesse momento:
- o repositório pode voltar a ser privado (Actions access resolve o consumo cross-repo);
- rulesets passam a permitir enforcement real, substituindo o workflow de auditoria;
- com licença Code Security, o fallback de SARIF do `upload-findings` deixa de ser acionado
  (mas o código continua correto — ele apenas passa a usar sempre o caminho nativo).
