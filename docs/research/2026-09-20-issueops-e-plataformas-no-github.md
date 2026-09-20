# Como times de DevOps constroem plataformas internas no GitHub

> Pesquisa conduzida em 2026-09-20 para fundamentar a plataforma de entrega da empresa.
> Stacks-alvo: dotnet, java, go, node, python, react+typescript.
> Alvos de deploy: Vercel, Coolify e, a seguir, AWS, Azure, GCP e Oracle (OCI).

## Sumário executivo

1. Times que já vivem no GitHub **não sobem um Backstage no dia 1**. Usam as primitivas nativas
   (Issues, Actions, Environments, Rulesets) como control plane da plataforma. A fricção de adoção
   é praticamente zero.
2. **IssueOps** é o padrão consolidado de self-service: formulário de issue como interface,
   Actions como executor, timeline da issue como trilha de auditoria.
3. O reuso se organiza em **três mecanismos distintos** — composite actions, reusable workflows e
   starter workflows — e confundi-los é o erro estrutural mais comum.
4. O princípio que se repete em todas as fontes: **o golden path deve ser o caminho mais fácil,
   não o único caminho**.
5. **SAST e DAST não são a mesma classe de problema**: SAST lê código parado e cabe em qualquer
   job de CI; DAST precisa de uma aplicação de pé e, portanto, vive em job efêmero ou pós-deploy.
6. O plano **GitHub Free** impõe restrições concretas que moldam a arquitetura inteira
   (ver seção 6). A mais cara delas: code scanning em repositório privado exige licença paga.

---

## 1. O padrão dominante: o próprio GitHub como plataforma (IDP)

A abordagem descrita nas fontes de platform engineering organiza a plataforma em quatro camadas,
todas sobre primitivas nativas:

| Camada | Primitiva GitHub | Papel |
|---|---|---|
| Self-service | Issue Forms + Actions (**IssueOps**) | Provisionar repositório, ambiente, acesso, deploy |
| Golden path | Repositórios template + starter workflows | Ponto de partida opinativo por stack |
| Reuso | Composite actions + reusable workflows | DRY do YAML; a "estrada pavimentada" |
| Governança | Rulesets, environments, required checks | Guardrails sem depender da memória do dev |

O argumento central a favor dessa abordagem é o custo de adoção: o desenvolvedor já está
autenticado no GitHub, já sabe abrir issue e PR e já entende o que é um workflow. Projetos de
Backstage, em contraste, costumam ser citados com ciclos de implantação de 6 a 12 meses antes de
entregarem valor.

### Implicação para nós

Começamos pela camada de **reuso** (biblioteca de CI), porque é ela que sustenta as outras duas:
o IssueOps da Fase 2 só precisa decidir *qual workflow referenciar*, e a governança da Fase 4 só
precisa verificar *se o repositório referencia a plataforma*.

---

## 2. IssueOps: como funciona de verdade

IssueOps é a prática de usar Issues e Pull Requests como **interface** de automação. O modelo
mental correto — e que aparece explicitamente na documentação oficial — é o de uma
**máquina de estados finitos**:

- a **issue** é o objeto que muda de estado;
- os **labels** são os estados (`pending`, `validated`, `awaiting-approval`, `denied`);
- os **comentários** são as transições (`.approve`, `.deny`);
- os **workflows** são as ações executadas em cada transição.

### Fluxo canônico

```
 dev abre issue (Issue Form)
        │
        ▼
 [issues: opened/edited] ──► parse do corpo → JSON ──► validação
        │                                                │
        │ inválido ◄─────────────────────────────────────┘
        │   └─► comenta o erro + label `invalid`   (dev corrige e reabre o ciclo)
        ▼ válido
   label `awaiting-approval`
        │
        ▼
 [issue_comment: .approve] ──► checa autorização ──► executa ──► comenta resultado ──► fecha
```

Dois detalhes que costumam ser subestimados:

- **A validação precisa rodar de novo a cada `edited`.** Se o workflow só escuta `opened`, o
  usuário edita a issue depois de aprovada e o conteúdo executado não é o conteúdo revisado.
- **Autorização é responsabilidade do workflow.** O evento traz
  `github.event.comment.user.login`; conferir membership do time é passo explícito, não implícito.

### Issue Forms

Os formulários (`.github/ISSUE_TEMPLATE/*.yml`) entregam de graça o que normalmente se constrói
à mão: campos obrigatórios, dropdowns, checkboxes e validação na submissão. O corpo resultante é
Markdown estruturado e previsível — é isso que torna o parsing confiável.

### Toolkit de mercado

A organização [`issue-ops`](https://github.com/issue-ops), mantida por engenheiros da GitHub,
publica as peças prontas:

| Action | Função |
|---|---|
| `issue-ops/parser` | Converte a resposta do issue form em JSON confiável |
| `issue-ops/validator` | Valida o JSON contra um schema |
| `issue-ops/labeler` | Gerencia os labels que representam o estado |

### Casos de uso mais citados

Provisionamento de repositório, pedido de acesso ou membership de time, criação de ambiente,
solicitação de deploy com aprovação, e triagem/roteamento de bugs.

### Limite importante: alcance do `GITHUB_TOKEN`

O token padrão do workflow **não** consegue criar repositórios nem gerenciar times da organização.
Para isso, o padrão recomendado é um **GitHub App de organização** instalado no repositório de
IssueOps, trocando o app token em runtime. Usar um PAT pessoal para isso é o antipadrão clássico:
o acesso morre junto com a saída da pessoa da empresa.

---

## 3. Deploy: os dois modelos em uso

### 3.1 Branch/tag + aprovação no Environment (convencional)

Merge na `main` dispara staging automaticamente; uma tag ou release dispara produção atrás de
*required reviewers* configurados no GitHub Environment. É o modelo mais simples de auditar e o
mais fácil de explicar para auditoria externa.

**É o modelo escolhido pela nossa equipe.**

### 3.2 IssueOps no PR (`github/branch-deploy`)

A própria GitHub usa: comentar `.deploy` em um PR implanta *o branch do PR* antes do merge. A
action oferece:

- `.deploy noop` — dry run
- `.deploy to <environment>` — escolha de ambiente
- `.deploy main` — rollback para o branch estável
- `.lock` / `.unlock` — trava de deploy para evitar colisão entre times

A filosofia por trás é "deploy antes do merge": se o branch quebra produção, a `main` nunca chegou
a ser contaminada. Fica **registrado como alternativa futura** para o fluxo de produção.

---

## 4. Os três mecanismos de reuso

Confundir os três é o erro estrutural mais comum em plataformas de GitHub Actions.

| Mecanismo | Quando usar | Limite que importa |
|---|---|---|
| **Composite action** | Bloco pequeno e reaproveitável: setup de toolchain, cache, um scan | Não define `jobs`; roda *dentro* de um job |
| **Reusable workflow** (`workflow_call`) | O golden path: pipeline inteiro, com jobs, matrizes e `permissions` | **Precisa estar na raiz de `.github/workflows/` — subdiretório não funciona** |
| **Starter workflow** (template) | Bootstrap de repositório novo; é *copiado*, não referenciado | Vive no repositório especial `.github` da organização |

A restrição de subdiretório é o que determina a convenção de nomes da nossa plataforma
(`ci-*`, `sec-*`, `cd-*`, `_*`): como não podemos organizar em pastas, organizamos por prefixo.

A recomendação para escala organizacional é usar **os três juntos**: composite actions como peças,
reusable workflows como a estrada pavimentada, starter workflows como o onboarding.

---

## 5. Segurança de pipeline: o consenso atual

### 5.1 Permissões

`permissions: {contents: read}` no topo de todo workflow, elevando **por job** apenas onde
necessário. Workflow sem bloco `permissions` herda o default do repositório — historicamente
read/write em tudo, o que maximiza o raio de dano de qualquer comprometimento.

### 5.2 SHA pinning

Actions de terceiros devem ser fixadas pelo **SHA completo do commit**, não por tag. Tags são
móveis: um atacante que comprometa o repositório da action reescreve `v4` e todo mundo que
referencia `@v4` passa a executar o código dele. Desde agosto de 2025 a política de Actions do
GitHub suporta *exigir* SHA pinning.

Actions internas podem usar tag major móvel (`@v1`). **`@main` nunca** — nem para action interna.

### 5.3 `pull_request_target`

O evento roda no contexto do branch base, **com acesso aos secrets**, mesmo para PR vindo de fork
("pwn request"). Para PR de fork o padrão seguro é de dois estágios: estágio 1 roda no código não
confiável sem secrets e sem permissão de escrita; estágio 2 roda só após ação de um mantenedor.

### 5.4 OIDC no lugar de credencial estática

Para toda nuvem, o GitHub atua como Identity Provider e emite um JWT assinado por execução; a
nuvem valida e troca por credencial temporária (tipicamente 1 hora). Não há segredo de longa
duração armazenado.

- **AWS** — IAM OIDC provider + role assumível
- **Azure** — federated credential em uma App Registration
- **GCP** — Workload Identity Pool
- **OCI** — Workload Identity Federation: troca o JWT por um UPST (User Principal Session Token);
  a aplicação cliente precisa estar registrada no domínio OCI IAM e listada no atributo
  `oauthClients` da Identity Propagation Trust policy

Requer `permissions: {id-token: write}`. A trust policy deve ser restrita ao máximo — no mínimo
por `repo:ORG/REPO:environment:prod`, nunca apenas por `repo:ORG/*`.

---

## 6. SAST e DAST: onde cada um encaixa

A distinção que define a arquitetura:

- **SAST** lê **código parado** → cabe em qualquer job de CI, roda em todo PR.
- **DAST** ataca uma **aplicação rodando** → precisa de um alvo de pé, logo **não cabe no CI puro**.

### 6.1 SAST — camadas complementares, não uma ferramenta só

| Camada | Ferramenta | Quando | Racional |
|---|---|---|---|
| SAST genérico | **Semgrep OSS** | todo PR | ~35 linguagens (cobre nossas 6), segundos a minutos, saída SARIF, regra custom em YAML |
| SAST profundo | **CodeQL** | agendado (noturno) | Precisão melhor, mas construir o banco leva de minutos a 30+ min — caro demais para PR |
| Linter de segurança | `gosec`, `bandit`/`ruff S`, `eslint-plugin-security`, `find-sec-bugs`, analisadores .NET | todo PR | Custo zero, específico da stack, poucos falsos positivos |
| Segredos | **gitleaks** | todo PR | Segredo vazado é o achado de maior severidade real |
| SCA (dependências) | **trivy fs**, **osv-scanner**, `dependency-review-action` | todo PR | CVE em dependência é o vetor mais explorado |
| IaC e container | **trivy config** + **trivy image** | quando há Dockerfile/IaC | Misconfiguração de imagem e de infra |

#### O dado que muda o desenho do gate

No OWASP Benchmark, **CodeQL obtém F1 de 74,4% e Semgrep 69,4%** — CodeQL é mais preciso. Mas o
número que realmente importa é outro: **CodeQL marcou 68,2% dos casos não-vulneráveis como
positivos, e Semgrep 74,8%.**

Ou seja: a maior parte do que qualquer um dos dois aponta **não é vulnerabilidade real**.

A consequência prática é direta — **um gate do tipo "zero findings" é inviável**. O gate tem de
ser por **severidade** e por **achado novo em relação a uma baseline**. Plataforma que quebra o
build por achado de severidade baixa ensina o time a desativar o scan, e aí a segurança fica pior
do que se não houvesse scan nenhum.

Vale registrar também que a **Community Edition do SonarQube não tem taint analysis**, ou seja,
não encontra injeção — a maioria das regras dela mira qualidade de código, não segurança. Por isso
não entrou como ferramenta de SAST na nossa plataforma.

#### Medição própria (feita ao construir a plataforma)

Os rulesets `p/security-audit` + `p/owasp-top-ten` foram medidos contra seis projetos com
vulnerabilidade real plantada, um por stack. **Detectaram python, go e node; não detectaram
java, dotnet nem react-ts.** A conclusão prática: o Semgrep OSS cobre bem as linguagens
dinâmicas e Go, e é fraco em C#, Java e TypeScript/React — exatamente onde o CodeQL é forte.
A plataforma fecha essas lacunas com regras próprias e mantém o CodeQL agendado.

#### Nota de licenciamento (verificada)

A action `gitleaks/gitleaks-action`, **a partir da v2, deixou de ser MIT e exige license key para
repositórios de organização** (contas pessoais seguem gratuitas). Como a empresa vai operar em uma
organização, nossa plataforma usa a **CLI oficial do gitleaks (MIT)** diretamente, evitando a
dependência de licença.

### 6.2 DAST — dois momentos

1. **Efêmero no CI** (opcional, só para aplicação containerizada): o job sobe a imagem recém
   construída, aguarda o healthcheck e roda **ZAP baseline** contra `localhost`. É um scan
   **passivo**, de 2 a 5 minutos — cabe no PR.
2. **Pós-deploy** (o principal): após o deploy em `dev`/`staging`, **ZAP baseline** a cada deploy;
   **`zap-api-scan`** quando existe spec OpenAPI; **ZAP full scan** (ativo, de 30 minutos a horas)
   apenas em agendamento noturno.

**Nuclei** aparece nas comparações como complemento: por ser baseado em templates, roda em
segundos a minutos, o que o torna adequado para verificação contínua pós-deploy. A recomendação
consolidada é: *na dúvida, ZAP; para APIs e operação contínua, Nuclei.*

#### Regra inegociável

**Full scan é tráfego de ataque real.** As fontes alertam que ele pode sobrecarregar o ambiente
alvo. Nunca contra produção sem autorização explícita e janela combinada; por padrão, restrito a
ambientes não-produtivos.

### 6.3 Supressão e rollout

- **Supressão versionada**: `.semgrepignore`, `.zap/rules.tsv`, `.trivyignore` moram no repositório
  do serviço e passam por PR. A exceção vira decisão rastreável, não flag escondida no YAML da
  plataforma.
- **Rollout em dois tempos**: as ferramentas entram em **modo observação** (resultado só no job
  summary, build não quebra) para medir o ruído real com o código da empresa; depois de calibrada
  a baseline, viram gate bloqueante.

---

## 7. Restrições do plano GitHub Free (verificadas na documentação)

Estas restrições moldam a arquitetura inteira e foram confirmadas na documentação oficial:

| Recurso | Situação no Free |
|---|---|
| Environments + required reviewers / wait timer | ❌ **só em repositório público**. Se um repo público virar privado, as protection rules passam a ser **ignoradas** |
| Code Scanning / CodeQL / upload de SARIF para a aba Security | ✅ grátis em repo **público**; ❌ em repo **privado exige licença GitHub Code Security** |
| Rulesets (de repositório e de organização) | ❌ exige **Team** ou **Enterprise** |
| Required workflows via ruleset org-wide | ❌ exige **Enterprise Cloud** |
| Minutos de Actions | ✅ **ilimitados em repositório público**; 2.000/mês em privado |
| Reusable workflows entre repositórios | ✅ trivial se o repositório de origem for **público** |

### Consequências diretas

1. **O repositório da plataforma deve ser público.** Ele contém apenas YAML, sem segredo algum.
   Sendo público, resolve de uma vez: acesso entre repositórios, minutos ilimitados e environments.
   → registrado no [ADR 0001](../adr/0001-monorepo-publico-da-plataforma.md).

2. **Governança por auditoria, não por bloqueio.** Sem rulesets, não há como *exigir* que um
   repositório use a plataforma. O substituto é um workflow agendado que varre os repositórios e
   **abre issue** quando encontra desvio. Isso, aliás, está alinhado com o princípio do golden
   path: o caminho mais fácil, não o único.

3. **O upload de SARIF precisa degradar graciosamente.** Repositório de serviço privado no Free
   não tem aba Security. A plataforma resolve com um composite action `upload-findings` que tenta
   `github/codeql-action/upload-sarif` e, na ausência de code scanning, cai para artifact SARIF +
   tabela no job summary, aplicando o mesmo gate de severidade. Quando a empresa migrar para
   Team/Enterprise + Code Security, os achados passam a aparecer na aba Security **sem mudar uma
   linha do YAML do serviço**.

---

## 8. Decisões tomadas a partir desta pesquisa

| # | Decisão | Fundamento |
|---|---|---|
| 1 | Monorepo público da plataforma neste repositório | §7 — acesso entre repos, minutos, environments |
| 2 | Começar pela biblioteca de CI reusável | §1 — é a camada que sustenta IssueOps e CD |
| 3 | Contrato de inputs/outputs **idêntico** entre as 6 stacks | §2 — torna o IssueOps da Fase 2 trivial |
| 4 | Deploy por branch/tag + aprovação no Environment | §3.1 — mais simples de auditar |
| 5 | SAST em camadas, gate por severidade, rollout `observe` → `enforce` | §6.1 — taxa de falso positivo de ~70% |
| 6 | DAST efêmero no PR + DAST pós-deploy; full scan só agendado | §6.2 — DAST precisa de alvo rodando |
| 7 | CLI do gitleaks em vez da action | §6.1 — licença exigida para organizações |
| 8 | SHA pinning para toda action de terceiro | §5.2 — supply chain |
| 9 | OIDC para toda nuvem, trust policy por environment | §5.4 |
| 10 | Governança por workflow de auditoria que abre issue | §7 — rulesets indisponíveis no Free |

---

## Fontes

### IssueOps e platform engineering
- [IssueOps: Automate CI/CD (and more!) with GitHub Issues and Actions — GitHub Blog](https://github.blog/engineering/issueops-automate-ci-cd-and-more-with-github-issues-and-actions/)
- [IssueOps Docs — introdução e setup](https://issue-ops.github.io/docs/introduction)
- [issue-ops/parser](https://github.com/issue-ops/parser) · [issue-ops/labeler](https://github.com/issue-ops/labeler)
- [Enabling branch deployments through IssueOps — GitHub Blog](https://github.blog/engineering/engineering-principles/enabling-branch-deployments-through-issueops-with-github-actions/) · [github/branch-deploy](https://github.com/github/branch-deploy)
- [Platform Engineering with GitHub: Build an IDP with Copilot, IssueOps, and Golden-Path Repos](https://htek.dev/articles/platform-engineering-github-internal-developer-platform)
- [What is a golden path for software development? — Red Hat](https://www.redhat.com/en/topics/platform-engineering/golden-paths)

### Reuso e escala
- [Custom GitHub Actions vs Reusable Workflows: Two Layers of Reuse](https://iamjaekim.github.io/custom-actions-vs-reusable-workflows/)
- [Org-Level Reusable GitHub Actions Workflows](https://sph.sh/en/posts/github-actions-platform-scale/)

### Segurança de pipeline
- [Secure use reference — GitHub Docs](https://docs.github.com/en/actions/reference/security/secure-use)
- [Hardening GitHub Actions: Lessons from Recent Attacks — Wiz](https://www.wiz.io/blog/github-actions-security-guide)
- [GitHub Actions policy now supports blocking and SHA pinning actions — GitHub Changelog](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/)

### SAST
- [Semgrep vs CodeQL (2026): Fast Scans vs Deeper Analysis — Konvu](https://konvu.com/compare/semgrep-vs-codeql)
- [Static Code Analysis Tools Comparison (2026) — Rafter](https://rafter.so/blog/static-code-analysis-tools-comparison)
- [Best SAST Tools in 2026 — Safeguard](https://safeguard.sh/resources/blog/best-sast-tools-2026)

### DAST
- [Free & Open-Source DAST Tools Compared (2026) — AppSec Santa](https://appsecsanta.com/dast-tools/free-dast-tools)
- [Comparing Open-Source DAST Tools: ZAP, Nuclei, Wapiti, Nikto](https://codenote.net/en/posts/dast-oss-tools-comparison-devsecops-pipeline/)
- [OWASP ZAP API Security Testing in CI: 2026 Guide — QASkills](https://qaskills.sh/blog/owasp-zap-api-security-testing-guide-2026)
- [OWASP ZAP vs Nuclei vs Nikto (2026) — Pi Stack](https://www.pistack.xyz/posts/owasp-zap-vs-nuclei-vs-nikto-self-hosted-dast-scanning-guide-2026/)

### Plataforma GitHub (limites e recursos)
- [Managing environments for deployment — GitHub Docs](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
- [About rulesets — GitHub Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [About code scanning — GitHub Docs](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning)

### Nuvem e deploy
- [Configuring OpenID Connect in cloud providers — GitHub Docs](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-cloud-providers)
- [GitHub Actions & OCI: A Guide to Secure OIDC Token Exchange — Oracle A-Team](https://www.ateam-oracle.com/github-actions-oci-a-guide-to-secure-oidc-token-exchange)
- [How can I use GitHub Actions with Vercel? — Vercel](https://vercel.com/kb/guide/how-can-i-use-github-actions-with-vercel)
- [GitHub Actions — Coolify Docs](https://coolify.io/docs/applications/sources/github/actions)
