# CD por digest no Coolify

O workflow `cd-coolify.yml` é chamado pelo repositório do serviço depois que o CI publica uma
imagem. Ele só aceita referências completas `repository@sha256:<64 hex>`, atualiza a aplicação
Docker Image no Coolify para o digest correspondente, dispara o deploy e aguarda o
`deployment_uuid` terminar.

```yaml
name: CD

on:
  workflow_dispatch:
    inputs:
      image-ref:
        required: true
        type: string

jobs:
  deploy:
    uses: tassosgomes/template-pipeline/.github/workflows/cd-coolify.yml@v1
    permissions:
      contents: read
    with:
      environment: staging
      service-name: identity
      version: 1.2.3
      image-ref: ${{ inputs.image-ref }}
      application-uuid: ${{ vars.COOLIFY_APPLICATION_UUID }}
      coolify-api-url: ${{ vars.COOLIFY_API_URL }}
      health-url: ${{ vars.SERVICE_HEALTH_URL }}
      migration-command: ./scripts/migrate.sh
      platform-ref: v1
    secrets:
      coolify-token: ${{ secrets.COOLIFY_TOKEN }}
      database-url: ${{ secrets.DATABASE_URL }}
```

Em um caller ligado ao CI, declare `needs: ci` e monte `image-ref` como
`${{ needs.ci.outputs.image-ref }}@${{ needs.ci.outputs.image-digest }}`; passe também
`${{ needs.ci.outputs.version }}` e `${{ needs.ci.outputs.service-name }}`. Se o workflow for
disparado manualmente, use a referência completa fornecida pelo release aprovado; não reconstrua a
imagem nem troque o digest por `latest`.

Configure `COOLIFY_TOKEN`, `DATABASE_URL` e o UUID como secrets/variables do Environment
`development`, `staging` ou `production`. Configure required reviewers para staging/production;
o job de migração e o job de deploy referenciam o Environment, portanto a aprovação ocorre antes
de qualquer alteração no runtime. O token precisa somente das permissões de deploy necessárias.

Migrations são forward-only: antes do comando, o workflow executa
`check-migrations-immutable.sh`, que rejeita alteração/remoção de migrations históricas e permite
apenas o snapshot. O comando recebe `DATABASE_URL` por variável de ambiente, nunca por argumento
visível. Em rollback, informe `rollback-image-ref`; a imagem anterior é promovida por digest e
migrations são deliberadamente puladas — schema não é desfeito.

O webhook é opcional. Quando informado, ele é usado apenas para disparar o deploy depois do PATCH
da aplicação; a atualização do digest continua sendo feita pela API. Sem webhook, o workflow usa
`POST /api/v1/deploy` e consulta `GET /api/v1/deployments/{uuid}` até `finished`/`success` ou falha.
