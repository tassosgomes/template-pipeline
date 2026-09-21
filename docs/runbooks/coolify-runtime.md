# Runbook de runtime no Coolify

Este runbook descreve o mínimo reproduzível para um ambiente dev. Ele não contém hosts,
UUIDs, dumps ou credenciais reais. Valores concretos ficam em `vars` e `secrets` do Environment
correspondente.

## Princípios

- Cada serviço possui banco, usuário de runtime e usuário de migration próprios.
- O usuário de runtime não possui `CREATE`, `ALTER`, `DROP`, `UPDATE` ou `DELETE` fora do que o
  domínio exigir explicitamente. A role de auditoria é somente leitura e não possui `UPDATE` nem
  `DELETE`.
- Migrations rodam no job `migrate` do CD, antes do rollout. A aplicação não chama `Migrate()` no
  boot.
- Imagens são referenciadas por digest. `latest` não é uma identidade de release.
- Cada mudança de rede, volume ou serviço persistente precisa de backup e teste de restauração
  antes da promoção.

## Componentes

| Componente | Configuração mínima | Validação |
|---|---|---|
| PostgreSQL | banco/role por serviço; role de migration separada; retenção e backup definidos | conexão de runtime, conexão de migration e tentativa negada de DDL/auditoria |
| RabbitMQ | quorum queues, DLX/DLQ, TTL/retenção e política de redrive documentados | publicar, consumir, rejeitar e confirmar mensagem na DLQ |
| Valkey | namespace por serviço/ambiente, TTL explícito e política de persistência | health, leitura/escrita, expiração e comportamento após restart |
| OTLP Collector | entrada OTLP para traces, métricas e logs; backend e retenção por ambiente | evento de cada sinal chega ao backend correto sem cruzar ambientes |

As tags das imagens devem ser as mesmas usadas no Compose local e nos Testcontainers do serviço.
Fixe versões explícitas; atualizações são mudanças revisáveis do runbook.

## Checklist de provisionamento

1. Criar os Environments `dev`, `staging` e `prod`; configurar reviewers em staging/prod.
2. Criar o projeto/aplicação Coolify do serviço e registrar seu UUID em uma variável de
   Environment, nunca no repositório.
3. Criar volume persistente para PostgreSQL, RabbitMQ, Valkey e o backend OTLP conforme a política
   de backup do ambiente.
4. Criar roles e bancos PostgreSQL por serviço. Testar que um serviço não acessa o banco de outro.
5. Configurar quorum, DLX, DLQ, TTL e redrive no RabbitMQ; registrar limites de retenção.
6. Configurar Valkey com autenticação, TTL e política de persistência compatível com cache/sessão.
7. Configurar o Collector com isolamento por ambiente e destino de retenção aprovado.
8. Definir health/readiness checks e portas internas; não usar endpoints privados no YAML público.
9. Executar o checklist de backup e restaurar em um ambiente descartável.
10. Executar uma promoção dev pelo CD, conferir traces/métricas/logs e guardar o resumo da execução.

## Segredos e rotação

Use secrets de Environment para `COOLIFY_TOKEN`, credenciais de banco e tokens do collector.
O token Coolify deve ter somente a permissão `deploy` quando o webhook for suficiente. O CD deve
receber os valores como variáveis de ambiente, nunca como argumentos visíveis, summary ou artifact.

Para rotacionar: criar o valor novo, validar em dev, promover para staging, revogar o antigo e
repetir a validação. Não revogue um token enquanto houver deploy ativo que dependa dele.

## Backup e restauração

O dono do serviço deve registrar frequência, retenção, criptografia, localização e RPO/RTO de cada
volume. Um backup só é considerado válido depois de uma restauração periódica em ambiente isolado,
com health/readiness e consulta de dados verificados.

## Falha e rollback

Falha de migration interrompe o rollout. Rollback de aplicação redeploya o digest anterior, mas
não desfaz schema: correções de schema são migrations de avanço. Se uma migration falhar, preserve
logs e estado do banco, corrija a migration/credencial e reexecute com o mesmo artefato aprovado.

## Evidências mínimas

- checklist de provisionamento preenchido;
- teste de isolamento PostgreSQL e da role de auditoria;
- prova de quorum/DLX/DLQ e retenção RabbitMQ;
- prova de TTL/restart do Valkey;
- trace, métrica e log OTLP por ambiente;
- restauração de backup em ambiente descartável;
- resumo do CD contendo serviço, ambiente, digest, migration e resultado do health check, sem
  segredos.
