# Manifesto `platform.yml`

O manifesto é a fonte declarativa dos serviços consumidos pela plataforma. O schema fica em
[`platform.schema.json`](../../platform.schema.json). A validação semântica adicional pode ser
executada com `scripts/check-platform-manifest.sh platform.yml`.

## Serviço único

O formato original continua válido:

```yaml
nome: identity
time: platform
stack: dotnet
deploy:
  plataforma: coolify
  ambientes: [dev, staging]
```

## Monorepo

Use `servicos` quando vários apps compartilharem o repositório. Cada serviço precisa de nome,
caminho relativo e stack:

```yaml
defaults:
  time: platform
  deploy:
    plataforma: coolify
    ambientes: [dev, staging]
servicos:
  - nome: identity
    path: src/identity
    stack: dotnet
  - nome: web
    path: apps/web
    stack: react-ts
```

`time`, `criticidade`, `deploy`, `seguranca` e `contato` podem ser definidos em `defaults` e
sobrescritos no serviço. A precedência é:

`serviço > defaults do manifesto > default do schema`.

O campo canônico de ownership é `time`. Não use `owner` como alias: isso evita dois nomes para a
mesma responsabilidade e mantém o contrato em português consistente com o manifesto original.

## Regras semânticas

- nomes seguem kebab-case e são únicos;
- paths são relativos, normalizados e não podem repetir ou conter outro path de serviço;
- stacks aceitas são `dotnet`, `java`, `go`, `node`, `python` e `react-ts`;
- um serviço precisa obter um `time` efetivo de si próprio ou de `defaults.time`;
- o validador semântico complementa o JSON Schema porque unicidade e sobreposição entre itens não
  são expressáveis de forma portátil em JSON Schema.

Os fixtures em `examples/platform/` cobrem o formato antigo, um monorepo de dez apps e falhas de
nome, path e stack.
