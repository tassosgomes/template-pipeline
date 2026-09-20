# ADR 0003 — Como os workflows reusáveis alcançam as composite actions da plataforma

- **Status**: aceito
- **Data**: 2026-09-20

## Contexto

Os workflows `ci-*.yml` vivem no repositório da plataforma, mas **executam no contexto do
repositório consumidor**. Isso cria um problema concreto de resolução de caminho:

> Quando o repositório A chama um workflow reusável do repositório B, um passo
> `uses: ./actions/sast` dentro desse workflow é procurado **no workspace de A**, não no de B.

Como o workspace de A contém o código do serviço — e não as actions da plataforma — a referência
simplesmente não resolve. Este é um ponto de dor conhecido e recorrente de quem mantém workflows
compartilhados.

Três alternativas foram consideradas:

| Alternativa | Problema |
|---|---|
| `uses: ./actions/sast` | Não resolve quando chamado de outro repositório |
| `uses: tassosgomes/template-pipeline/actions/sast@v1` | Resolve, mas o self-test passaria a testar sempre a **última versão publicada**, nunca o commit do PR — a suíte deixaria de proteger contra regressão |
| Sintaxe self-repository `$/` | Não encontrada na documentação oficial; não construímos a plataforma sobre sintaxe não documentada |

## Decisão

Todo workflow reusável **faz checkout do repositório da plataforma em `.platform/`** e referencia
as composite actions por esse caminho:

```yaml
- uses: actions/checkout@<sha>          # código do serviço (repositório consumidor)

- uses: actions/checkout@<sha>          # a plataforma, em um subdiretório
  with:
    repository: tassosgomes/template-pipeline
    ref: ${{ inputs.platform-ref }}
    path: .platform

- uses: ./.platform/actions/sast        # agora resolve: os arquivos estão no workspace
```

Todo workflow reusável expõe o input **`platform-ref`**, com default `v1`.

## Justificativa

O caminho `./.platform/actions/sast` é **estático** — e `uses` não aceita expressões. Mas o
`ref` do `actions/checkout` é um input comum, que **aceita expressão**. É exatamente essa
assimetria que a decisão explora:

- o **consumidor** não informa nada e recebe `v1`, a versão estável da plataforma;
- o **self-test** passa `platform-ref: ${{ github.sha }}` e testa o commit exato do PR,
  incluindo mudanças nas composite actions.

Resolve simultaneamente a resolução de caminho e o problema de testabilidade, sem depender de
sintaxe não documentada.

## Consequências

- **Custo**: um checkout adicional por job (repositório pequeno, só YAML — da ordem de segundos).
- **O consumidor pode fixar a plataforma**: `platform-ref` aceita tag, branch ou SHA, então um
  serviço sensível pode fixar um SHA exato da plataforma.
- **`.platform/` precisa ser ignorado** pelos scans, senão o SAST analisa a própria plataforma
  junto com o serviço. Os workflows passam `working-directory` explicitamente para evitar isso.
- **Bootstrap**: a tag `v1` precisa existir para que o default funcione. Ela é criada no primeiro
  release da plataforma.
