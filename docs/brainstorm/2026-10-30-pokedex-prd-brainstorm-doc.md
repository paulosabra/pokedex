---
date: 2026-10-30
topic: pokedex-prd
---

# Pokédex — Product Requirements Document (PRD)

> **Stack:** Flutter · Dart · MVC · Provider · REST API (PokéAPI v2) · `http` · `logging` · `sqflite`
> **Tech Spec:** [docs/tech-spec/2026-10-30-pokedex-tech-spec.md](../tech-spec/2026-10-30-pokedex-tech-spec.md)
> **Design de referência:** [Figma — Pokédex (v1)](https://www.figma.com/design/UM7vkYG9fHjnh0xmBu8jdx/Pok%C3%A9dex--v1-?node-id=0-1) (lido via Figma MCP)
> **Contexto:** projeto de portfólio/estudo — o sucesso é medido por fidelidade ao design, clareza arquitetural, robustez a falhas e qualidade de testes.

---

## 1. What We're Building

Um app Flutter de Pokédex que lista os **151 Pokémon da 1ª geração** em um grid, permite **buscar por nome ou número**, **ordenar por número ou nome** e abrir uma **tela de detalhes** com tipos, peso, altura, habilidades, descrição e atributos base — navegando entre Pokémon vizinhos sem voltar à lista.

Os dados vêm da [PokéAPI](https://pokeapi.co) via `http`, com **cache em 2 níveis** (memória + SQLite), que permite abrir o app offline depois do primeiro carregamento. A arquitetura é **MVC com Provider**: Models e Repository isolam a API, Controllers (`ChangeNotifier`) guardam o estado de cada tela e Views apenas renderizam. Todos os estados que o Figma não desenhou (loading, erro, vazio, imagem indisponível) são especificados aqui, junto com uma estratégia de logging hierárquica baseada no pacote `logging`.

---

## 2. Why This Approach

Três arquiteturas foram consideradas:

| Abordagem | Veredito |
|---|---|
| **A — Controller por tela + Repository com cache** | ✅ **Escolhida.** Fronteiras claras (rede → domínio → UI) tornam cada camada testável e dão lugar natural para mapeamento de erros e logs. |
| B — Um `PokedexController` global | ❌ Vira *god object*; rebuilds do detalhe notificariam a lista; difícil testar. |
| C — A + camada de Services/UseCases | ❌ YAGNI: busca e ordenação sobre 151 itens são funções puras de poucas linhas. |

Outras escolhas de escopo e o porquê:

- **Gen 1 (151)** em vez de todos os ~1025: uma única chamada carrega o índice inteiro, então busca e ordenação são **locais e instantâneas**, sem paginação nem ambiguidade de "ordenar o que ainda não carregou".
- **Cache em memória + SQLite** (`sqflite`): o L1 elimina loading repetido nas setas ‹ › e o L2 evita refazer as chamadas a cada cold start. Dados da Gen 1 são imutáveis, então não há TTL (detalhes na Tech Spec §4).
- **Logging só em console**, com níveis por ambiente: demonstra o pacote `logging` sem acoplar a um serviço externo fora da stack.
- **UI em inglês**, fiel ao Figma; a descrição (flavor text) da PokéAPI não existe em pt-BR.

---

## 3. Key Decisions

| # | Decisão | Racional |
|---|---|---|
| D1 | Universo de dados = Pokémon #1–#151 | Índice completo em 1 request; busca/ordenação locais. |
| D2 | Arquitetura A (Controller por tela) | Ver §2. |
| D3 | Estado de tela modelado como `sealed class` (`Loading` / `Success` / `Failure`) | Exaustividade garantida pelo compilador no `switch` da View. |
| D4 | Cache em 2 níveis no Repository (memória → SQLite); **falhas nunca são cacheadas** em nenhum nível | Retry real após erro; sem estado envenenado; uso offline do que já foi carregado. |
| D5 | Imagem da lista derivada do id (`official-artwork/{id}.png`) | Evita 151 chamadas de detalhe só para a grade. |
| D6 | Logging: `logging` → `dart:developer`, `ALL` em debug / `WARNING` em release | Diagnóstico rico local, ruído zero em produção. |
| D7 | Navegação com `Navigator` 1.0 (`MaterialPageRoute`) | 2 telas; roteador declarativo seria excesso. |
| D8 | Idioma da UI: inglês; números formatados em locale `en` (ex.: `6.9 kg`) | Coerência com o idioma; desvio consciente do "6,9 kg" do Figma (ver §12). |
| D9 | Sem retry automático; retry **manual** via botão | Previsível, testável; 151 itens não justificam backoff. |
| D10 | Busca filtra a cada tecla, **sem debounce** | Filtro local sobre 151 itens é O(n) desprezível. |

---

## 4. Personas e Objetivos

| Persona | Objetivo | Métrica de sucesso |
|---|---|---|
| **Fã de Pokémon** (usuário final) | Encontrar rapidamente um Pokémon e ver seus dados | Chegar ao detalhe de um Pokémon conhecido em ≤ 3 interações |
| **Recrutador / revisor técnico** (público do portfólio) | Avaliar arquitetura, tratamento de erros e testes | Encontrar cada requisito deste PRD mapeado em código e teste |

### 4.1 Critérios de sucesso do projeto

- Telas visualmente fiéis ao Figma (tokens de cor, tipografia Poppins, espaçamentos, elevação).
- 100% dos estados da §8 implementados, incluindo os não desenhados.
- `flutter analyze` sem issues; cobertura de testes ≥ 80% em `lib/` (excluindo `main.dart`).
- Nenhuma exceção não tratada chega ao usuário sem log `SEVERE` correspondente.

---

## 5. Inventário de Design (extraído do Figma)

### 5.1 Telas e componentes

| Elemento | Node Figma | Descrição |
|---|---|---|
| **Pokédex List** | `1013:1576` / `1017:431` | Header vermelho (logo pokébola + "Pokédex"), Search Bar, Sort Button, grid 3 colunas de cards em container branco arredondado |
| **Sort card** | `1024:1979` | Overlay "Sort by:" com radio **Number** / **Name** |
| **Pokémon Details** | `1013:1574` / `1016:1461` | Fundo na cor do tipo primário, ← voltar, nome, `#001`, arte grande com ‹ › , chips de tipo, *About* (peso, altura, "Moves"), descrição, *Base Stats* |
| List Item (card) | `1014:1511` | 104×108, número `#004` no canto, imagem, nome sobre faixa cinza |
| Search Bar | `1013:1428` | Variantes `Typing=False` (placeholder "Search") e `Typing=True` (texto + ✕ limpar) |
| Sort Button | `1013:2613` | 32×32 circular; ícone `#` (tag) quando ordenado por número, `A` (text_format) quando por nome |
| Type Chips | `922:544` | 18 tipos + `Type=Unknown` |
| Silhouette | `1013:1356` | Ilustração placeholder de Pokémon |
| Ícones | `920:237` | arrow_back, chevron_left/right, close, search, sort, straighten, tag, text_format, weight, pokeball |

Fluxos de protótipo existentes: **"Pokédex – Sort by Number"** e **"Pokédex – Sort by Name"**.

### 5.2 Design tokens

**Identity:** Primary `#DC0A2D`

**Grayscale:** Dark `#212121` · Medium `#666666` · Light `#E0E0E0` · Background `#EFEFEF` · White `#FFFFFF`

**Pokémon Type:**

| Tipo | Hex | Tipo | Hex | Tipo | Hex |
|---|---|---|---|---|---|
| Bug | `#A7B723` | Fire | `#F57D31` | Ice | `#9AD6DF` |
| Dark | `#75574C` | Flying | `#A891EC` | Poison | `#A43E9E` |
| Dragon | `#7037FF` | Ghost | `#70559B` | Psychic | `#FB5584` |
| Electric | `#F9CF30` | Normal | `#AAA67F` | Rock | `#B69E31` |
| Fairy | `#E69EAC` | Grass | `#74CB48` | Steel | `#B7B9D0` |
| Fighting | `#C12239` | Ground | `#DEC16B` | Water | `#6493EB` |

**Tipografia (Poppins):**

| Estilo | Peso | Tamanho / altura de linha |
|---|---|---|
| Headline | Bold | 24 / 32 |
| Subtitle 1 / 2 / 3 | Bold | 14/16 · 12/16 · 10/16 |
| Body 1 / 2 / 3 | Regular | 14/16 · 12/16 · 10/16 |
| Caption | Regular | 8 / 12 |

**Elevação:** Drop Shadow 2dp e 6dp; Inner Shadow 2dp.

### 5.3 Lacunas do design (especificadas neste PRD)

Estados **não desenhados**: loading da lista, loading do detalhe, erro de rede/servidor, busca sem resultado, imagem indisponível, descrição indisponível. Splash e ícone do app também não existem.

> **Nota:** o mock da lista usa 9 Pokémon ilustrativos, incluindo **Aron (#304)**, que fica fora do recorte Gen 1 (D1). Os mocks são tratados como amostra visual, não como especificação de dados; o texto da descrição do Bulbasaur no Figma também não precisa coincidir com a entrada escolhida por RN-13.

---

## 6. Escopo

### 6.1 In scope (MVP)

- Lista de 151 Pokémon em grid; busca por nome/número; ordenação por número/nome.
- Tela de detalhes com navegação anterior/próximo.
- Cache em memória + SQLite (índice e detalhes já abertos disponíveis offline), estados de loading/erro/vazio, retry manual.
- Logging estruturado por camada.
- Testes unitários (models, repository, controllers, regras puras) e de widget (estados das telas).

### 6.2 Out of scope

Favoritos · filtro por tipo · cadeia de evolução · lista de golpes (moves) · cache de imagens em disco · sincronização/TTL de dados · i18n/pt-BR · dark mode · layout tablet dedicado · analytics · crash reporting remoto · Pokémon além do #151.

---

## 7. Requisitos Funcionais

### 7.1 Lista (Pokédex List)

| ID | Requisito |
|---|---|
| **RF-01** | Ao abrir o app, carregar o índice dos Pokémon #1–#151 e exibi-los em grid de **3 colunas** (baseline 360dp). |
| **RF-02** | Cada card exibe número formatado (`#001`), arte oficial e nome de exibição (§9.1). |
| **RF-03** | Ordem inicial: **por número, crescente**. |
| **RF-04** | Tocar em um card abre o detalhe daquele Pokémon. |
| **RF-05** | Enquanto a imagem do card carrega ou se falhar, exibir a **Silhouette**. |
| **RF-06** | Em telas mais largas, o número de colunas cresce mantendo cards de ~104dp (`SliverGridDelegateWithMaxCrossAxisExtent`). |

### 7.2 Busca

| ID | Requisito |
|---|---|
| **RF-07** | A Search Bar filtra o grid a cada alteração de texto (sem botão de submit). |
| **RF-08** | Ao conter texto, a Search Bar exibe o botão **✕**, que limpa a busca e restaura a lista completa. |
| **RF-09** | A busca suporta **nome** e **número** conforme as regras RN-04 a RN-07. |
| **RF-10** | O filtro respeita a ordenação ativa. |
| **RF-11** | Sem resultados → estado vazio (§8, E-05). |

### 7.3 Ordenação

| ID | Requisito |
|---|---|
| **RF-12** | Tocar no Sort Button abre o **Sort card** ancorado ao botão, com radio Number/Name refletindo a ordenação atual. |
| **RF-13** | Selecionar uma opção aplica a ordenação imediatamente e fecha o Sort card. Tocar fora fecha sem alterar. |
| **RF-14** | O ícone do Sort Button reflete a ordenação ativa: `#` (Number) ou `A` (Name). |
| **RF-15** | Ordenação e texto de busca **persistem durante a sessão** (inclusive ao voltar do detalhe). |

### 7.4 Detalhes (Pokémon Details)

| ID | Requisito |
|---|---|
| **RF-16** | Exibir header com ←, nome de exibição e número (`#001`), sobre fundo na **cor do tipo primário**. |
| **RF-17** | Exibir a arte oficial grande; enquanto carrega/se falhar, exibir Silhouette. |
| **RF-18** | Exibir chips de tipo (1 ou 2) na ordem do slot da API, com a cor de cada tipo. |
| **RF-19** | Seção **About**: peso (kg), altura (m) e habilidades (até 2), com ícones weight/straighten. |
| **RF-20** | Exibir a descrição (flavor text em inglês, normalizada — RN-13). |
| **RF-21** | Seção **Base Stats**: HP, ATK, DEF, SATK, SDEF, SPD com valor em 3 dígitos (`045`) e barra proporcional (RN-15). Rótulos e barras na cor do tipo primário. |
| **RF-22** | Setas **‹ ›** navegam para o Pokémon anterior/próximo **da lista visível no momento** (filtrada + ordenada) — RN-16. |
| **RF-23** | ← (ou gesto/botão voltar do sistema) retorna à lista preservando busca, ordenação e posição de scroll. |
| **RF-24** | Swipe horizontal na área da arte equivale às setas ‹ › (atalho de gesto, opcional/nice-to-have). |

### 7.5 Transversais

| ID | Requisito |
|---|---|
| **RF-25** | Todas as falhas de carregamento exibem mensagem amigável e botão **Try again** (§10). |
| **RF-26** | Toda requisição, falha e ação relevante gera log conforme §11. |
| **RF-27** | App travado em orientação **retrato**. |

---

## 8. Estados de Tela

| ID | Tela | Estado | Comportamento | Desenhado no Figma? |
|---|---|---|---|---|
| E-01 | Lista | Loading | Header e Search Bar visíveis (busca desabilitada); grid com 9 cards *skeleton* exibindo Silhouette | ❌ |
| E-02 | Lista | Success | Grid conforme RF-01..06 | ✅ |
| E-03 | Lista | Failure | No container branco: Silhouette, mensagem (§10.3) e botão **Try again** | ❌ |
| E-04 | Lista | Searching | Grid filtrado; ✕ visível | ✅ |
| E-05 | Lista | Empty search | Silhouette + "No Pokémon found for “{query}”" + ação **Clear search** | ❌ |
| E-06 | Detalhe | Loading | Header com nome/número já conhecidos (vindos da lista), fundo Medium Gray, Silhouette, indicador de progresso na área do card | ❌ |
| E-07 | Detalhe | Success | Conforme RF-16..22 | ✅ |
| E-08 | Detalhe | Failure | Header com ← funcional; mensagem + **Try again**; setas ‹ › continuam ativas | ❌ |
| E-09 | Detalhe | Partial (sem descrição) | Tudo exibido; no lugar da descrição: "Description unavailable." em Medium Gray | ❌ |
| E-10 | Ambos | Imagem indisponível | Silhouette no lugar da arte; sem mensagem ao usuário | ✅ (componente) |

---

## 9. Regras de Negócio

### 9.1 Identidade e exibição

- **RN-01 — Id a partir da URL.** O endpoint de lista retorna `{name, url}`; o id é o último segmento numérico de `url` (`.../pokemon/4/` → `4`). Entradas cujo id não puder ser extraído são descartadas com log `WARNING`.
- **RN-02 — Número formatado.** `#` + id com *zero-padding* de 3 dígitos (`4` → `#004`).
- **RN-03 — Nome de exibição.** Capitalizar a primeira letra do nome da API, com exceções mapeadas explicitamente: `nidoran-f` → `Nidoran♀`, `nidoran-m` → `Nidoran♂`, `mr-mime` → `Mr. Mime`, `farfetchd` → `Farfetch’d`.

### 9.2 Busca

- **RN-04 — Normalização.** A consulta é *trimmed*; comparações ignoram maiúsculas/minúsculas e acentos (`é` = `e`).
- **RN-05 — Modo número.** Se a consulta (sem `#` inicial e espaços) for composta só de dígitos, a busca é por número: casa quando o número com padding (`004`) **ou** sem padding (`4`) **começa com** os dígitos digitados. Ex.: `#004` → Charmander; `4` → #4, #40–#49; `#00` → #1–#99.
- **RN-06 — Modo nome.** Caso contrário, casa quando o nome de exibição normalizado **contém** a consulta normalizada. Ex.: `char` → Charmander, Charmeleon, Charizard.
- **RN-07 — Consulta vazia** (ou só `#`/espaços) → lista completa.

### 9.3 Ordenação

- **RN-08 — Number:** id crescente. **Name:** nome de exibição normalizado A→Z; empate desempatado por id.
- **RN-09 — Composição:** `visível = ordenar(filtrar(índice, busca), ordem)`. A ordenação não depende da busca e vice-versa.

### 9.4 Detalhe

- **RN-10 — Cor do tema:** cor do tipo de `slot = 1`. Tipo desconhecido (fora dos 18) → chip `Unknown` e cor Medium Gray `#666666`.
- **RN-11 — Peso e altura:** a API retorna hectogramas e decímetros → `kg = weight / 10`, `m = height / 10`, uma casa decimal, locale `en` (`6.9 kg`, `0.7 m`).
- **RN-12 — Habilidades:** até 2 itens de `abilities`, ordenados por `slot`, incluindo a oculta; nomes com hífen viram palavras capitalizadas (`solar-power` → `Solar Power`).
- **RN-13 — Descrição:** primeira entrada de `flavor_text_entries` com `language.name == "en"` vinda de `/pokemon-species/{id}`; substituir `\n`, `\f` e *soft hyphen* (`­`) por espaço e colapsar espaços múltiplos.
- **RN-14 — Degradação parcial:** detalhe = `/pokemon/{id}` **e** `/pokemon-species/{id}` em paralelo. Falha em `/pokemon` → estado Failure (E-08). Falha apenas em `/species` → estado Partial (E-09), log `WARNING`.
- **RN-15 — Barra de stat:** largura = `base_stat / 255` (máximo teórico), limitada a [0, 1]. Valor exibido com padding de 3 dígitos.
- **RN-16 — Vizinhos:** ao abrir o detalhe, o Controller recebe um *snapshot* da lista visível (ids ordenados) e o índice atual. ‹ fica **oculta** no primeiro item, › oculta no último. Busca/ordem alteradas depois não afetam o snapshot daquela abertura.
- **RN-17 — Respostas obsoletas:** se o usuário navegar (‹ ›) antes de uma resposta chegar, a resposta de um id que não é mais o atual é **descartada** (log `FINE`) — nunca sobrescreve a tela.

### 9.5 Cache

- **RN-18 — Escopo:** índice da lista e detalhes ficam em `Map` no Repository (L1) e em SQLite (L2), sem TTL. Núcleo (`/pokemon`) e descrição (`/species`) são cacheados separadamente.
- **RN-19 — Falhas não são cacheadas.** "Try again" sempre refaz a requisição.
- **RN-20 — Deduplicação:** requisições concorrentes ao mesmo id compartilham o mesmo `Future` em andamento.
- **RN-21 — Imagens:** cache padrão do `Image.network` (ImageCache do Flutter); nenhuma lógica adicional.

---

## 10. Tratamento de Erros

### 10.1 Taxonomia (Model)

As exceções técnicas são capturadas no `PokeApiClient`/`PokemonRepository` e convertidas em um tipo de domínio selado. **Controllers e Views nunca veem `SocketException`, `http.Response` ou `FormatException`.**

```dart
sealed class AppFailure { String get userMessage; }
final class NetworkFailure    extends AppFailure {} // sem conexão / DNS
final class TimeoutFailure    extends AppFailure {} // > 10s
final class NotFoundFailure   extends AppFailure {} // HTTP 404
final class RateLimitFailure  extends AppFailure {} // HTTP 429
final class ServerFailure     extends AppFailure {} // HTTP 5xx / outros não-2xx
final class ParsingFailure    extends AppFailure {} // JSON inválido / campo ausente
final class UnexpectedFailure extends AppFailure {} // qualquer outro
```

### 10.2 Mapeamento técnico → domínio → log

| Origem técnica | `AppFailure` | Nível de log |
|---|---|---|
| `SocketException`, `http.ClientException` | `NetworkFailure` | WARNING |
| `TimeoutException` (timeout 10s por request) | `TimeoutFailure` | WARNING |
| HTTP 404 | `NotFoundFailure` | WARNING |
| HTTP 429 | `RateLimitFailure` | WARNING |
| HTTP 5xx / outros não-2xx | `ServerFailure` | SEVERE |
| `FormatException`, `TypeError`, campo obrigatório ausente | `ParsingFailure` | SEVERE |
| Qualquer outro `Object` | `UnexpectedFailure` | SEVERE |

### 10.3 Mensagens ao usuário (inglês, fiel ao idioma da UI)

| Falha | Mensagem |
|---|---|
| Network | "No internet connection. Check your network and try again." |
| Timeout | "This is taking longer than usual. Please try again." |
| NotFound | "We couldn't find this Pokémon." |
| RateLimit | "Too many requests. Wait a moment and try again." |
| Server / Parsing / Unexpected | "Something went wrong on our side. Please try again." |

### 10.4 Regras de tratamento

- **ERR-01** — Falha no índice → E-03; busca e ordenação desabilitadas até sucesso.
- **ERR-02** — Falha no detalhe → E-08; ← e ‹ › continuam funcionais (o usuário pode tentar outro Pokémon).
- **ERR-03** — Falha só na descrição → E-09 (RN-14).
- **ERR-04** — Falha de imagem → Silhouette, log `FINE` (é esperado e não acionável).
- **ERR-05** — Campos opcionais ausentes não derrubam o parsing: sem `abilities` → seção mostra "—"; `stats` incompletos → stat ausente exibido como `000`. Campos **obrigatórios** (`id`, `name`, `types`) ausentes → `ParsingFailure`.
- **ERR-06** — Controllers não chamam `notifyListeners()` após `dispose()` (guarda `_disposed`); resposta tardia é descartada com log `FINE`.
- **ERR-07 — Rede de segurança global:** `FlutterError.onError` e `PlatformDispatcher.instance.onError` registram `SEVERE` com stack trace. Em release, `ErrorWidget.builder` exibe um bloco neutro em vez da tela vermelha.
- **ERR-08** — Nenhum `catch` vazio: todo `catch` converte em `AppFailure` **e** loga, ou relança.

---

## 11. Estratégia de Logging

### 11.1 Configuração

- Pacote `logging`, `hierarchicalLoggingEnabled = true`, configurado uma vez em `main()` antes de `runApp`.
- `Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL`.
- Um único listener em `Logger.root.onRecord` encaminha para `dart:developer.log(message, name: record.loggerName, level: record.level.value, error:, stackTrace:)` — integra com o DevTools e não usa `print`.

### 11.2 Hierarquia de loggers

| Logger | Camada | Responsabilidade |
|---|---|---|
| `pokedex.app` | Bootstrap | Startup, handlers globais de erro |
| `pokedex.api` | `PokeApiClient` | Requisições HTTP, status, duração |
| `pokedex.repository` | `PokemonRepository` | Cache hit/miss, mapeamento de falhas, parsing |
| `pokedex.storage` | `PokemonLocalStore` | Abertura do SQLite, erros de leitura/escrita, reset de schema |
| `pokedex.controller.list` | `PokedexController` | Transições de estado, mudança de ordenação |
| `pokedex.controller.detail` | `PokemonDetailController` | Transições, navegação ‹ ›, respostas descartadas |

Views **não** logam diretamente; ações de UI são logadas pelo Controller que as recebe.

### 11.3 Política de níveis

| Nível | Quando | Exemplos |
|---|---|---|
| `FINE` | Detalhe de fluxo útil só em debug | `GET /pokemon/4 → 200 (183ms)`, `cache hit id=4`, `stale response discarded id=5`, falha de imagem |
| `INFO` | Marcos de ciclo de vida e ações de usuário significativas | `app started`, `index loaded: 151 items in 412ms`, `sort changed: number → name`, `detail opened id=25` |
| `WARNING` | Falha recuperável / degradação | `NetworkFailure on GET /pokemon?limit=151`, `species unavailable id=4`, `retry requested` |
| `SEVERE` | Bug provável ou erro não tratado | `ParsingFailure` (com `error` + `stackTrace`), `ServerFailure 500`, erro global capturado |

### 11.4 Formato e conteúdo

- Mensagem curta e estável + pares chave=valor: `GET /pokemon/4 → 200 {ms=183, req=17}`.
- `req` = contador incremental por requisição, para correlacionar início/fim/falha nos logs do api e do repository.
- **Não** logar corpos de resposta inteiros; em `ParsingFailure`, incluir no máximo os primeiros 200 caracteres.
- **Não** logar cada tecla da busca (ruído); a busca não gera log — só mudanças de ordenação e aberturas de detalhe.
- O app não manipula PII nem segredos; ainda assim, nenhuma URL com query sensível ou header é logada.

### 11.5 Testabilidade

Testes anexam um listener a `Logger('pokedex')` e afirmam que caminhos de falha emitem o registro esperado (nível + logger + mensagem). Ex.: "dado um 500 em `/pokemon/4`, o repository emite `SEVERE` em `pokedex.repository`".

---

## 12. Casos de Uso

### UC-01 — Navegar pela Pokédex
- **Ator:** usuário · **Pré:** app aberto
- **Fluxo principal:** 1) app exibe E-01; 2) carrega o índice; 3) exibe o grid ordenado por número (E-02).
- **Alternativo 2a:** falha → E-03 → usuário toca **Try again** → volta ao passo 1.

### UC-02 — Buscar por nome
- **Pré:** E-02 · **Fluxo:** 1) usuário digita `char`; 2) grid mostra Charmander, Charmeleon, Charizard (RN-06); 3) usuário toca ✕ → lista completa.
- **Alternativo 2a:** sem resultados → E-05 → **Clear search** restaura a lista.

### UC-03 — Buscar por número
- **Pré:** E-02 · **Fluxo:** 1) usuário digita `#004`; 2) grid mostra apenas Charmander (RN-05).

### UC-04 — Ordenar
- **Pré:** E-02 · **Fluxo:** 1) toca o Sort Button; 2) Sort card abre com "Number" marcado; 3) seleciona "Name"; 4) card fecha, grid reordena A→Z, ícone vira `A`.
- **Alternativo 3a:** toca fora → card fecha sem alterar.

### UC-05 — Ver detalhes
- **Pré:** grid visível · **Fluxo:** 1) toca em Bulbasaur; 2) E-06 com nome/número já preenchidos; 3) E-07 com fundo Grass, chips Grass/Poison, 6.9 kg, 0.7 m, abilities, descrição e stats.
- **Alternativo 3a:** falha em `/pokemon` → E-08. **3b:** falha só em `/species` → E-09.
- **Alternativo 1a:** detalhe já em cache → E-07 direto, sem loading.

### UC-06 — Navegar entre vizinhos
- **Pré:** E-07 de Bulbasaur, lista por número · **Fluxo:** 1) ‹ oculta (primeiro item); 2) toca ›; 3) abre Ivysaur (#002).
- **Variante:** com busca `char` ativa, › a partir de Charmander leva a Charmeleon (snapshot da lista visível — RN-16).
- **Exceção:** toques rápidos em › › › → apenas a resposta do último id é aplicada (RN-17).

### UC-07 — Voltar à lista
- **Fluxo:** toca ← → lista com a mesma busca, ordenação e posição de scroll (RF-23).

### UC-08 — Recuperar de falha de rede
- **Pré:** sem conexão · **Fluxo:** 1) E-03 com mensagem de rede; 2) usuário reativa a conexão; 3) toca **Try again**; 4) E-01 → E-02. A falha anterior não ficou no cache (RN-19).

---

## 13. Arquitetura (MVC + Provider)

### 13.1 Camadas e responsabilidades

```
View (Widgets)  ──lê/escuta──▶  Controller (ChangeNotifier)  ──chama──▶  Model
                                                                          ├─ PokemonRepository (cache, mapeamento de falhas)
                                                                          ├─ PokeApiClient (http, timeout, status)
                                                                          └─ Entidades (PokemonSummary, PokemonDetail, PokemonType, PokemonStat)
```

| Camada | Pode depender de | Não pode |
|---|---|---|
| View | Controller (via `context.watch/select`), tema | Repository, `http`, `AppFailure` técnico |
| Controller | Repository, entidades, `AppFailure` | `BuildContext`, widgets, `http` |
| Repository | ApiClient, entidades | Flutter (é Dart puro) |
| ApiClient | `http.Client` injetado | Entidades de UI |

### 13.2 Estrutura de pastas proposta

> Substituída pela estrutura da Tech Spec §2.3, que inclui a camada `data/local/`.

```
lib/
  main.dart                      # logging + error handlers + runApp
  app.dart                       # MaterialApp, tema, MultiProvider
  core/
    logging/app_logging.dart
    errors/app_failure.dart
    theme/ (app_colors.dart, type_colors.dart, app_text_styles.dart, app_theme.dart)
  models/
    pokemon_summary.dart  pokemon_detail.dart  pokemon_type.dart  pokemon_stat.dart
    data/ (poke_api_client.dart, pokemon_repository.dart)
    rules/ (pokedex_query.dart)  # busca + ordenação puras (RN-04..09)
  controllers/
    pokedex_controller.dart  pokemon_detail_controller.dart
  views/
    pokedex/ (pokedex_page.dart, widgets/…)
    detail/  (pokemon_detail_page.dart, widgets/…)
    shared/  (silhouette_image.dart, type_chip.dart, error_view.dart)
```

### 13.3 Injeção com Provider

- Raiz: `Provider<PokemonRepository>` (singleton com `http.Client` injetado) e `ChangeNotifierProvider<PokedexController>`.
- Detalhe: `ChangeNotifierProvider<PokemonDetailController>` **escopado à rota**, criado com `(repository, idsSnapshot, initialIndex)` e descartado ao sair.
- Testes substituem `http.Client` por `MockClient` (`package:http/testing.dart`), sem pacotes de mock adicionais.

### 13.4 Endpoints

| Uso | Endpoint |
|---|---|
| Índice | `GET https://pokeapi.co/api/v2/pokemon?limit=151&offset=0` |
| Detalhe | `GET https://pokeapi.co/api/v2/pokemon/{id}` |
| Descrição | `GET https://pokeapi.co/api/v2/pokemon-species/{id}` |
| Arte | `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/{id}.png` |

---

## 14. Requisitos Não Funcionais

| ID | Requisito |
|---|---|
| RNF-01 | Plataformas: Android e iOS, Flutter stable; baseline de layout 360×640dp. |
| RNF-02 | Índice exibido em ≤ 2s numa conexão 4G típica; abertura de detalhe em cache < 100ms. |
| RNF-03 | Scroll do grid a 60fps em dispositivo intermediário (imagens com `cacheWidth` adequado). |
| RNF-04 | Acessibilidade: cards com `Semantics(label: "Bulbasaur, number 001")`; botões com tooltip/label; alvos de toque ≥ 48dp (o Sort Button de 32dp ganha área de toque expandida); respeita escala de fonte até 1.3×. |
| RNF-05 | Contraste: **13 dos 18** tipos ficam abaixo de 4.5:1 com texto branco. O texto sobre cor de tipo usa a cor de maior contraste (White ou Dark `#212121`), e os rótulos de stat usam a cor do tipo escurecida (Tech Spec §8.2). |
| RNF-06 | Qualidade: `flutter analyze` limpo (`flutter_lints`); cobertura ≥ 80%. |
| RNF-07 | Dependências de runtime limitadas a: `provider`, `http`, `logging`, `sqflite`, `path` (+ fonte Poppins como asset). |

---

## 15. Estratégia de Testes (resumo)

| Alvo | Tipo | Casos-chave |
|---|---|---|
| `pokedex_query` (busca/ordenação) | Unit | RN-04..09, incluindo `#00`, `4`, acentos, empates |
| Entidades / parsing | Unit | Fixtures reais (Bulbasaur, Charmander, Mr. Mime); campos opcionais ausentes; RN-11..13 |
| `PokeApiClient` | Unit (`MockClient`) | 200, 404, 429, 500, timeout, socket error → `AppFailure` correto |
| `PokemonRepository` | Unit | Cache hit, falha não cacheada, dedupe de `Future`, degradação parcial, logs emitidos |
| Controllers | Unit | Transições de estado, RN-16/17 (vizinhos e respostas obsoletas), sem notify pós-dispose |
| Views | Widget | Cada estado E-01..E-10 renderiza o esperado; Sort card; ✕ limpa busca |

---

## 16. Open Questions

> **Resolvidas em 2026-10-30:** foram adotadas as recomendações abaixo; as decisões estão na Tech Spec §12.

1. **Rótulo "Moves" vs. habilidades.** O Figma rotula como *Moves*, mas exibe *Chlorophyll / Overgrow*, que são **abilities**. Recomendação: renomear para **"Abilities"** (corretude > fidelidade literal). Confirmar.
2. **Cor do tipo `Unknown`.** O Style Guide não define hex; proposta: Medium Gray `#666666`.
3. **Contraste dos chips claros** (RNF-05): manter texto branco como no Figma ou escurecer?
4. **Separador decimal.** O Figma mostra `6,9 kg`; com UI em inglês, adotamos `6.9 kg` (D8). Confirmar.
5. **Poppins:** empacotar como asset (offline, determinístico em testes) ou `google_fonts` (adiciona dependência e rede)? Recomendação: asset.
6. **Swipe no detalhe (RF-24):** manter como nice-to-have ou cortar do MVP?
7. **Splash e ícone do app** não existem no design — usar a pokébola sobre Primary `#DC0A2D`?
