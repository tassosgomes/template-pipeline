# Publicando contratos

Este guia define como gerar, versionar, validar e disponibilizar contratos públicos de uma
aplicação. Ele cobre:

- OpenAPI, para APIs HTTP;
- AsyncAPI, para eventos e mensagens;
- ODCS, para contratos de dados.

O contrato é versionado no repositório do serviço. A plataforma valida o arquivo e verifica sua
compatibilidade; um portal ou catálogo futuro apenas o descobre e o apresenta.

## Regra principal

O arquivo publicado precisa existir no branch padrão do repositório e passar por Pull Request.
Não publique o contrato somente em `build/`, `dist/`, `bin/` ou em um artefato temporário: esses
diretórios não são uma fonte estável para consumidores nem para um catálogo.

Quando o contrato é gerado pela aplicação, o processo deve ser:

1. gerar o contrato a partir do código ou da definição declarativa;
2. gravar o resultado no diretório `contracts/`;
3. revisar o diff do contrato junto com o código;
4. executar lint e compatibilidade;
5. fazer merge do contrato versionado no mesmo Pull Request da alteração.

O contrato gerado não deve ser editado manualmente depois da geração. Se uma correção manual for
necessária, corrija a origem e gere o arquivo novamente.

## Estrutura canônica

Para um repositório de serviço único, use:

```text
platform.yml
contracts/
  openapi/
    public.yaml
  asyncapi/
    events.yaml
  odcs/
    orders.yaml
  compatibility/
    openapi.base.yaml
    public-api.base.txt
```

Os nomes podem ser mais específicos quando o serviço possui mais de um contrato:

```text
contracts/openapi/orders-public.yaml
contracts/asyncapi/orders-events.yaml
contracts/odcs/orders-data.yaml
```

O diretório `contracts/` é o local recomendado para arquivos que representam a interface pública.
Documentação explicativa, exemplos de uso e guias podem continuar em `docs/`.

### Monorepos

Em um monorepo, cada serviço mantém seus contratos dentro do próprio `path` declarado no
manifesto:

```text
services/orders/
  contracts/
    openapi/public.yaml
    asyncapi/events.yaml
    odcs/orders.yaml
services/web/
  contracts/
    openapi/public.yaml
```

Isso mantém o contrato junto do serviço responsável e evita colisões de nomes. Um contrato
compartilhado por vários serviços deve ter um owner explícito e, preferencialmente, ser tratado
como um artefato próprio, com seu próprio diretório e ciclo de versão.

## Tipos de contrato

### OpenAPI

Use OpenAPI para descrever APIs HTTP síncronas. O documento deve conter a versão da API em
`info.version` e informar os servidores ou a URL base correta.

Exemplo mínimo de organização:

```text
contracts/openapi/public.yaml
contracts/compatibility/openapi.base.yaml
```

O workflow atual de lint pode ser chamado assim:

```yaml
jobs:
  openapi:
    uses: tassosgomes/template-pipeline/.github/workflows/openapi-lint.yml@v1
    with:
      spec-glob: 'contracts/openapi/**/*.yaml'
```

Para verificar breaking changes, passe o contrato da versão anterior e o contrato atual:

```yaml
jobs:
  compatibility:
    needs: openapi
    uses: tassosgomes/template-pipeline/.github/workflows/contract-compatibility.yml@v1
    with:
      openapi-base: contracts/compatibility/openapi.base.yaml
      openapi-head: contracts/openapi/public.yaml
      base-version: 1.4.0
      head-version: 1.5.0
```

### AsyncAPI

Use AsyncAPI para eventos, tópicos, filas e outros contratos assíncronos. O documento deve
conter a versão em `info.version`, descrever os canais e informar os servidores ou brokers
relevantes.

A organização recomendada é:

```text
contracts/asyncapi/events.yaml
```

O lint e o gate de compatibilidade de AsyncAPI serão adicionados à plataforma antes do uso
obrigatório desse formato. Até lá, o repositório do serviço deve validar o documento com a
ferramenta escolhida pelo time e registrar o comando no workflow do serviço.

Não reutilize automaticamente a comparação de OpenAPI para AsyncAPI: a compatibilidade precisa
considerar canais, operações, mensagens, payloads e mudanças no sentido produtor/consumidor.

### ODCS

Use ODCS para contratos de dados entre produtores e consumidores. O arquivo deve seguir a versão
do padrão adotada pela empresa. O baseline inicial da plataforma é ODCS `v3.0.1`.

Exemplo de localização:

```text
contracts/odcs/orders.yaml
```

O documento deve conter, no mínimo, os campos definidos pelo padrão, incluindo:

```yaml
apiVersion: v3.0.1
kind: DataContract
id: 53581432-6c55-4ba2-a65f-72344a91553a
version: 1.0.0
status: active
```

`apiVersion` identifica a versão do padrão ODCS. `version` identifica a versão do contrato de
dados; são conceitos diferentes e não devem ser confundidos.

Além da validação estrutural pelo JSON Schema oficial, a plataforma deverá aplicar regras
semânticas próprias, especialmente para schema, owner, classificação, qualidade, SLA e
informações de acesso. O JSON Schema é uma base de validação, não substitui a revisão do conteúdo
do contrato.

## Geração dos arquivos

O contrato deve ser produzido de forma determinística. O repositório precisa documentar o comando
de geração, por exemplo:

```bash
make contracts
```

ou:

```bash
npm run generate:contracts
```

O comando deve:

- gerar somente os arquivos pertencentes ao serviço;
- produzir saída estável, sem timestamps ou caminhos locais desnecessários;
- falhar quando não conseguir gerar o contrato;
- permitir que o resultado seja comparado no Pull Request;
- não incluir segredos, tokens ou dados reais de clientes.

Quando possível, o CI deve executar a geração e falhar se houver diferença entre o arquivo gerado
e o arquivo versionado. Assim evitamos que a aplicação e o contrato publicado evoluam de forma
independente.

## Versionamento e compatibilidade

Cada contrato possui duas versões relevantes:

1. a versão do formato do documento, como `apiVersion: v3.0.1` no ODCS;
2. a versão do contrato publicado, como `1.5.0`.

Como regra de compatibilidade:

- `MAJOR`: remoção ou alteração incompatível;
- `MINOR`: adição compatível;
- `PATCH`: correção sem alteração do contrato consumível.

Uma breaking change não deve ser escondida por uma atualização de arquivo. Ela exige:

- aumento de major;
- revisão explícita no Pull Request;
- nota de migração para os consumidores;
- atualização do baseline ou do artefato de comparação.

Os baselines em `contracts/compatibility/` são arquivos de revisão. Eles não devem ser
substituídos para silenciar um erro de compatibilidade; devem mudar somente quando a nova versão
for deliberadamente aceita.

## Checklist do Pull Request

Antes de solicitar revisão, confirme:

- [ ] o contrato está dentro de `contracts/`;
- [ ] o arquivo é gerado ou atualizado pelo comando documentado;
- [ ] a versão do contrato foi atualizada quando necessário;
- [ ] o owner e os consumidores foram revisados;
- [ ] não há segredos nem dados reais nos exemplos;
- [ ] o lint do formato passou;
- [ ] a compatibilidade com a versão anterior foi verificada;
- [ ] uma breaking change possui bump de major e nota de migração;
- [ ] em monorepo, o arquivo está dentro do diretório do serviço correto;
- [ ] links e referências externas continuam acessíveis.

## Catálogo e portal

Quando o portal de contratos estiver disponível, ele deverá ler os arquivos versionados neste
guia. O contrato não será copiado para outro repositório nem publicado diretamente a partir de um
diretório temporário.

O descritor do catálogo poderá apontar para os arquivos, por exemplo:

```yaml
kind: API
metadata:
  name: orders-data-v1
spec:
  type: odcs
  lifecycle: production
  owner: group:orders
  definition:
    $text: ./contracts/odcs/orders.yaml
```

Esse descritor só deve ser disponibilizado depois que o contrato passar pelos gates do CI. A
integração com o Backstage, autenticação e renderização de ODCS pertencem ao projeto do portal e
não alteram a localização ou a fonte de verdade definida neste manual.

## O que a plataforma oferece hoje

Atualmente estão disponíveis:

- lint de OpenAPI com o ruleset versionado da plataforma;
- comparação de compatibilidade de OpenAPI;
- comparação de snapshots de contratos públicos;
- compatibilidade de pacotes .NET via `ApiCompat`.

Os gates específicos de AsyncAPI e ODCS fazem parte da evolução deste manual e devem ser
adicionados antes de tornar esses formatos obrigatórios nos repositórios consumidores.
