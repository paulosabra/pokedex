---
date: 2026-10-30
topic: pokedex-tech-spec
source: docs/brainstorm/2026-10-30-pokedex-prd-brainstorm-doc.md
---

# Pokédex — Tech Spec (Especificação Técnica)

> **Entrada:** [PRD](../brainstorm/2026-10-30-pokedex-prd-brainstorm-doc.md). Esta spec define **como** construir o que o PRD define; IDs `RF-`, `RN-`, `E-`, `ERR-`, `RNF-` referem-se a ele.
> **Saída:** base para o plano de implementação. Nenhum código-fonte aqui — apenas **assinaturas** (contratos) e regras.
> **Stack:** Flutter stable · Dart 3 · MVC · Provider · `http` · `logging` · `sqflite` + `path`

---

## 1. Decisões técnicas

Complementam D1–D10 do PRD. `TS-` = decisão desta spec.

| # | Decisão | Racional | Alternativa rejeitada |
|---|---|---|---|
| TS-01 | **Cache em 2 níveis:** L1 memória (`Map` + `Future` em andamento) → L2 SQLite (`sqflite`) → rede | Abertura instantânea e uso offline após o 1º carregamento; L1 mantém RN-20 (dedupe) | Só memória (refaz rede a cada cold start); Drift (codegen + deps para 4 tabelas) |
| TS-02 | L2 guarda **entidades mapeadas** (JSON compacto) com `payload_version`, não respostas cruas | Resposta crua de `/pokemon` tem ~300 KB (moves); entidade < 2 KB. Mudança de entidade = bump de versão, sem migração | Tabelas normalizadas (types/stats/abilities) — complexidade sem consulta que a justifique |
| TS-03 | **Sem TTL.** Dados Gen 1 são imutáveis; invalidação só por `payload_version` ou `user_version` do schema | Regra de expiração trivial e determinística | TTL/stale-while-revalidate — revalida dados que não mudam |
| TS-04 | O L2 é **best-effort**: falha de storage nunca vira erro de tela | O banco é cache, não fonte de verdade; rede continua sendo o caminho de sucesso | Propagar `StorageFailure` ao usuário |
| TS-05 | `/pokemon/{id}` e `/pokemon-species/{id}` têm **entradas de cache independentes** | Falha só em species (E-09) não é cacheada; reabrir o detalhe tenta só a species (RN-14 + RN-19) | Cachear o detalhe composto — envenenaria a descrição ausente |
| TS-06 | Repository retorna `Result<T>` selado (`Ok` / `Err(AppFailure)`), nunca lança | Contrato "Controllers não veem exceções técnicas" vira garantia do compilador | `throw AppFailure` — não exaustivo, fácil de esquecer `catch` |
| TS-07 | `PokemonRepository` e `PokemonLocalStore` são **interfaces** (`abstract interface class`) | Fakes com `Completer` tornam RN-17 (respostas obsoletas) testável de forma determinística | Classe concreta + `MockClient` só — não controla a ordem de chegada |
| TS-08 | E-09 (Partial) = `DetailLoaded` com `description == null`, **não** um 4º estado | Mantém a união de 3 estados (D3); é variação de renderização, não de fluxo | `DetailPartial` — duplica toda a renderização de sucesso |
| TS-09 | Snapshot de vizinhos (RN-16) é `List<PokemonSummary>`, não só ids | E-06 precisa de nome/número do vizinho antes do fetch | Lista de ids + lookup no índice — acopla o detail controller ao list controller |
| TS-10 | Cor de primeiro plano sobre cor de tipo é **calculada** (maior contraste entre White e Dark `#212121`); rótulos de stat usam a cor do tipo **escurecida** até ≥ 4.5:1 sobre branco | 13 de 18 tipos falham 4.5:1 com texto branco (ver §8.2); regra única e testável | Lista manual de "tipos claros" — já estava errada no PRD (4 vs 13) |
| TS-11 | Normalização de busca também remove pontuação (`.`, `’`, `'`, `♀`, `♂`, `-`) | `mr mime` → Mr. Mime, `farfetchd` → Farfetch’d; extensão conservadora de RN-04 | Só case/acentos — usuários não digitam `’` |
| TS-12 | JSON > 64 KB é decodificado em `Isolate.run` | `/pokemon/{id}` ≈ 300 KB; decodificar na main isolate arrisca jank na transição (RNF-03) | Sempre na main isolate; sempre em isolate (overhead em respostas pequenas) |
| TS-13 | Sort card via `MenuAnchor` com filhos customizados | Ancoragem, foco, tap-fora e acessibilidade nativos (RF-12, RF-13) | `OverlayPortal` manual; `PopupMenuButton` (não estiliza o header vermelho) |
| TS-14 | Poppins como **asset** (`pubspec.yaml`), não `google_fonts` | Offline, determinístico em golden/widget tests, zero dependência extra | `google_fonts` — rede em runtime |

---

## 2. Arquitetura

### 2.1 Camadas

```
┌─────────────────────────────── View (Widgets) ───────────────────────────────┐
│ PokedexPage · PokemonDetailPage · shared/ (PokemonArtwork, TypeChip, ...)    │
└──────────────── context.watch / context.select / context.read ───────────────┘
                                     │
┌──────────────────────────── Controller (ChangeNotifier) ─────────────────────┐
│ PokedexController (app-scoped)        PokemonDetailController (route-scoped) │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ Result<T>
┌───────────────────────────────── Model (Dart puro*) ─────────────────────────┐
│ PokemonRepository ◀── CachedPokemonRepository                                │
│        ├── L1: Map + in-flight Futures                                       │
│        ├── L2: PokemonLocalStore ◀── SqflitePokemonLocalStore (*plugin)      │
│        └── Remote: PokeApiClient ── http.Client                              │
│ Entities · Rules (pokedex_query, pokemon_format, text_normalizer)            │
└──────────────────────────────────────────────────────────────────────────────┘
```

\* `SqflitePokemonLocalStore` é o único arquivo de `models/` que importa um plugin Flutter; o `CachedPokemonRepository` depende apenas da interface e permanece Dart puro.

### 2.2 Regras de dependência (verificadas por teste — §10)

| Camada | Pode importar | Não pode importar |
|---|---|---|
| `views/` | `controllers/`, `models/entities/`, `models/rules/`, `core/theme/`, Flutter | `models/data/`, `http`, `sqflite`, `core/errors/` subtipos técnicos |
| `controllers/` | `models/` (exceto `data/remote/` e `data/local/`), `core/errors/`, `package:flutter/foundation.dart` | `package:flutter/widgets.dart`, `material.dart`, `http`, `sqflite` |
| `models/data/cached_pokemon_repository.dart` | interfaces, entidades, regras, `logging` | `package:flutter/*`, `sqflite` |
| `models/data/remote/` | `http`, `logging`, `core/errors/` | `sqflite`, entidades de UI |
| `models/data/local/` | `sqflite`, `path`, entidades, `logging` | `http` |
| `core/` | Dart, Flutter (só `theme/`) | `controllers/`, `views/` |

### 2.3 Estrutura de pastas

```
lib/
  main.dart                         # bootstrap: logging, error handlers, orientação, composição, runApp
  app.dart                          # PokedexApp: MaterialApp, tema, MultiProvider
  core/
    errors/   app_failure.dart  result.dart
    logging/  app_logging.dart  loggers.dart
    theme/    app_colors.dart  type_colors.dart  contrast.dart  app_text_styles.dart  app_theme.dart
  models/
    entities/ pokemon_summary.dart  pokemon_detail.dart  pokemon_type.dart  pokemon_stat.dart  sort_order.dart
    rules/    pokedex_query.dart  pokemon_format.dart  text_normalizer.dart
    data/
      pokemon_repository.dart              # interface
      cached_pokemon_repository.dart       # L1 + L2 + remote
      remote/ poke_api_client.dart  pokemon_mappers.dart  endpoints.dart
      local/  pokemon_local_store.dart  sqflite_pokemon_local_store.dart  local_schema.dart  entity_codec.dart
  controllers/
    pokedex_controller.dart  pokedex_state.dart
    pokemon_detail_controller.dart  pokemon_detail_state.dart
  views/
    pokedex/ pokedex_page.dart  widgets/ (pokedex_header, search_bar, sort_button, sort_menu, pokemon_card, pokedex_grid, empty_search_view)
    detail/  pokemon_detail_page.dart  widgets/ (detail_header, artwork_pager, about_section, base_stats_section, stat_bar)
    shared/  pokemon_artwork.dart  silhouette.dart  type_chip.dart  failure_view.dart
assets/
  fonts/ Poppins-Regular.ttf  Poppins-Bold.ttf
  images/ pokeball.svg|png  silhouette.png
test/   (espelha lib/) + fixtures/ (bulbasaur.json, bulbasaur_species.json, charmander.json, mr_mime.json, index_151.json)
```

### 2.4 Composição (composition root)

Ordem em `main()`:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `configureLogging()` (§9) e handlers globais (ERR-07).
3. `SystemChrome.setPreferredOrientations([portraitUp])` (RF-27).
4. Construir grafo: `http.Client` → `PokeApiClient` → `SqflitePokemonLocalStore` (abertura **lazy**, não bloqueia o 1º frame) → `CachedPokemonRepository`.
5. `runApp(PokedexApp(repository: repository))`.

`PokedexApp` expõe:

| Provider | Escopo | Criação |
|---|---|---|
| `Provider<PokemonRepository>.value` | App | Instância do passo 4 |
| `ChangeNotifierProvider<PokedexController>` | App | `PokedexController(repository)..load()` |
| `ChangeNotifierProvider<PokemonDetailController>` | Rota de detalhe | Na `MaterialPageRoute` criada por `PokemonDetailPage.route(...)`; descartado com a rota |

Testes de widget montam `PokedexApp` (ou a página isolada) com um `FakePokemonRepository` — nenhum `http` ou `sqflite` real.

---

## 3. Gerenciamento de estado

### 3.1 Princípios

- **Provider + `ChangeNotifier`**, um controller por tela (D2).
- Estado assíncrono de tela = **`sealed class`** com 3 variantes (D3); a View faz `switch` exaustivo.
- Estado de sessão que sobrevive às variantes (busca, ordenação) fica **fora** da união, como campos do controller.
- States são imutáveis (`final class`, campos `final`, listas `List.unmodifiable`). Sem `equatable` (RNF-07): rebuild é disparado por `notifyListeners`, não por igualdade.
- Views leem com `context.select` no menor recorte possível (ex.: o Sort Button seleciona só `sortOrder`).
- Toda chamada a `notifyListeners()` passa por `_notify()`, que é no-op após `dispose()` (ERR-06).

### 3.2 Lista — `PokedexController`

```dart
sealed class PokedexState { const PokedexState(); }
final class PokedexLoading extends PokedexState { const PokedexLoading(); }
final class PokedexLoaded extends PokedexState {
  const PokedexLoaded({required this.visible, required this.total});
  final List<PokemonSummary> visible;   // = ordenar(filtrar(índice, query), sort) — RN-09
  final int total;                      // tamanho do índice
}
final class PokedexError extends PokedexState {
  const PokedexError(this.failure);
  final AppFailure failure;
}

class PokedexController extends ChangeNotifier {
  PokedexController(PokemonRepository repository);

  PokedexState get state;
  String get query;                 // texto cru digitado (RF-15)
  SortOrder get sortOrder;          // inicial: SortOrder.number (RF-03)
  bool get isInteractive;           // true só em PokedexLoaded (ERR-01)

  Future<void> load();              // no-op se já estiver carregando
  Future<void> retry();             // log WARNING "retry requested" + load()
  void updateQuery(String raw);     // recalcula visible; não loga (§11.4 PRD)
  void clearQuery();
  void changeSort(SortOrder order); // no-op se igual; log INFO "sort changed: a → b"
}
```

**Máquina de estados**

| De | Evento | Para |
|---|---|---|
| — | `load()` | `PokedexLoading` |
| `PokedexLoading` | `Ok(index)` | `PokedexLoaded` (visible recalculado com query/sort atuais) |
| `PokedexLoading` | `Err(f)` | `PokedexError(f)` |
| `PokedexError` | `retry()` | `PokedexLoading` |
| `PokedexLoaded` | `updateQuery` / `clearQuery` / `changeSort` | `PokedexLoaded` (novo `visible`) |

Derivações da View (sem estado extra): E-04 = `PokedexLoaded` ∧ `query` não vazia; E-05 = `PokedexLoaded` ∧ `visible.isEmpty`.

O índice completo fica privado no controller; `visible` é recalculado **só** quando índice, query ou sort mudam (memoização implícita — o state já é o resultado).

### 3.3 Detalhe — `PokemonDetailController`

```dart
sealed class PokemonDetailState { const PokemonDetailState(); }
final class DetailLoading extends PokemonDetailState {
  const DetailLoading(this.summary);       // E-06: header com nome/número já conhecidos
  final PokemonSummary summary;
}
final class DetailLoaded extends PokemonDetailState {
  const DetailLoaded(this.detail);         // detail.description == null → E-09
  final PokemonDetail detail;
}
final class DetailError extends PokemonDetailState {
  const DetailError(this.summary, this.failure);   // E-08
  final PokemonSummary summary;
  final AppFailure failure;
}

class PokemonDetailController extends ChangeNotifier {
  PokemonDetailController({
    required PokemonRepository repository,
    required List<PokemonSummary> snapshot,   // cópia imutável da lista visível (RN-16, TS-09)
    required int initialIndex,                // assert: 0 <= initialIndex < snapshot.length
  });

  PokemonDetailState get state;
  PokemonSummary get current;
  bool get hasPrevious;            // false no 1º item → ‹ oculta
  bool get hasNext;                // false no último → › oculta

  Future<void> load();             // carrega `current`
  Future<void> retry();
  void showPrevious();             // muda índice + load(); log INFO "detail navigated id=a → b"
  void showNext();
}
```

**Regras**

- **Atalho de cache (UC-05 1a):** `load()` consulta `repository.peekDetail(id)` primeiro; se houver detalhe completo em L1, emite `DetailLoaded` direto, sem passar por `DetailLoading`.
- **Respostas obsoletas (RN-17):** cada `load()` captura `final requestedId = current.id`. Ao receber o `Result`, aplica somente se `!_disposed && requestedId == current.id`; caso contrário descarta com log `FINE` "stale response discarded id=X". (Comparar por id e não por contador é suficiente: o snapshot não tem ids repetidos e o dedupe do repository torna "voltar ao mesmo id" seguro.)
- **Navegação durante erro (ERR-02):** `showPrevious/showNext` funcionam em qualquer estado.
- **Cor do tema:** derivada pela View — `DetailLoaded` → cor do tipo slot 1 (RN-10); `DetailLoading`/`DetailError` → Medium Gray `#666666`.

### 3.4 Busca e scroll entre rotas (RF-15, RF-23)

- O `TextEditingController` pertence ao `State` da `PokedexPage`, inicializado com `controller.query`; `onChanged` → `updateQuery`. O ✕ e o "Clear search" chamam `clearQuery()` e limpam o `TextEditingController`.
- O detalhe é aberto com `Navigator.push`; a `PokedexPage` permanece montada sob a rota, então `ScrollController`, texto e foco são preservados sem código adicional. O grid usa `PageStorageKey('pokedex-grid')` como redundância.
- Ao abrir o detalhe: `PokemonDetailPage.route(snapshot: state.visible, initialIndex: i)`, lendo o repository com `context.read<PokemonRepository>()`.

---

## 4. Estratégia de dados local (cache em 2 níveis)

### 4.1 Visão geral

```
fetchX(id)
  ├─ L1 hit (Map)                → Ok(valor)                          [FINE cache hit l1]
  ├─ Future em andamento p/ id   → mesmo Future (RN-20)               [FINE dedupe]
  ├─ L2 hit (SQLite, versão ok)  → popula L1 → Ok(valor)              [FINE cache hit l2]
  └─ Rede
       ├─ Ok  → popula L1 → grava L2 (não aguardada) → Ok(valor)      [FINE cache miss]
       └─ Err → nada é gravado em L1 nem L2 (RN-19) → Err(f)
```

| Dado | Chave | L1 | L2 (tabela) | Rede |
|---|---|---|---|---|
| Índice (151) | — | `List<PokemonSummary>?` | `pokemon_index` + `cache_meta` | `/pokemon?limit=151` |
| Núcleo do detalhe | id | `Map<int, PokemonDetail>` (sem descrição) | `pokemon_detail` | `/pokemon/{id}` |
| Descrição | id | `Map<int, String>` | `pokemon_description` | `/pokemon-species/{id}` |

`fetchDetail(id)` resolve **núcleo** e **descrição** em paralelo, cada um pelo seu próprio fluxo L1→L2→rede (TS-05):

| Núcleo | Descrição | Resultado |
|---|---|---|
| Ok | Ok | `Ok(detail.withDescription(text))` |
| Ok | Err | `Ok(detail)` com `description == null` + log WARNING "species unavailable id=X" (E-09) |
| Err | qualquer | `Err(failure do núcleo)` (E-08) |

### 4.2 Schema SQLite (versão 1)

Arquivo `pokedex_cache.db` em `getDatabasesPath()`. `PRAGMA user_version = 1`.

| Tabela | Colunas | Observações |
|---|---|---|
| `pokemon_index` | `id INTEGER PRIMARY KEY`, `name TEXT NOT NULL` | Nome cru da API; display name é derivado (RN-03) |
| `pokemon_detail` | `id INTEGER PRIMARY KEY`, `payload TEXT NOT NULL`, `payload_version INTEGER NOT NULL`, `fetched_at INTEGER NOT NULL` | `payload` = JSON da entidade via `EntityCodec` (TS-02); `fetched_at` em ms epoch, só diagnóstico |
| `pokemon_description` | `id INTEGER PRIMARY KEY`, `text TEXT NOT NULL`, `fetched_at INTEGER NOT NULL` | Texto já normalizado (RN-13). Só sucesso é gravado |
| `cache_meta` | `key TEXT PRIMARY KEY`, `value TEXT NOT NULL` | Chaves: `index_count`, `index_fetched_at` |

### 4.3 Regras do L2

- **LS-01 — Atomicidade do índice.** `writeIndex` roda em uma transação: `DELETE` + inserção em `batch` + `cache_meta.index_count`. `readIndex` só retorna valor se `COUNT(*) == index_count`; senão é miss (protege contra índice parcial após crash).
- **LS-02 — Versão de payload.** `readDetail` com `payload_version != EntityCodec.currentVersion` → miss + `DELETE` da linha + log FINE.
- **LS-03 — Payload corrompido.** Erro de decodificação do `payload` → miss + `DELETE` da linha + log WARNING.
- **LS-04 — Migração de schema.** `onUpgrade` e `onDowngrade` fazem `DROP` + `CREATE` de todas as tabelas (é cache; perder dados é aceitável). Log INFO "cache schema reset vA → vB".
- **LS-05 — Best-effort (TS-04).** Toda operação do `SqflitePokemonLocalStore` captura `DatabaseException`/`Object`, loga WARNING em `pokedex.storage` e degrada: leitura → `null`; escrita → completa normalmente. **A interface nunca lança.**
- **LS-06 — Abertura lazy.** O banco é aberto no 1º acesso (memoizado em um `Future<Database>`). Falha ao abrir → loga SEVERE uma vez e o store passa a operar como no-op pelo resto da sessão (o app funciona só com L1 + rede).
- **LS-07 — Escrita não bloqueia resposta.** Após sucesso de rede, o repository retorna o valor sem aguardar a escrita no L2 (`unawaited`, seguro por LS-05).
- **LS-08 — Sem invalidação por tempo** (TS-03). "Try again" só ocorre após falha, que nunca está no cache — RN-19 se mantém.

### 4.4 Comportamento offline resultante

| Situação | Lista | Detalhe | Imagens |
|---|---|---|---|
| 1º uso sem rede | E-03 | — | — |
| Já carregou o índice antes | E-02 a partir do L2 | Só os já abertos; outros → E-08 (NetworkFailure) | Silhouette (E-10) — `ImageCache` é só memória |
| Detalhe aberto antes com species falha | — | E-09 do L2 + nova tentativa de species | idem |

Persistir imagens em disco fica **fora do escopo** (exigiria `cached_network_image`/`flutter_cache_manager`); a Silhouette já cobre o caso.

---

## 5. Contratos e interfaces

Assinaturas apenas; corpos são responsabilidade do plano/implementação.

### 5.1 Core

```dart
// core/errors/result.dart
sealed class Result<T> { const Result(); }
final class Ok<T> extends Result<T> { const Ok(this.value); final T value; }
final class Err<T> extends Result<T> { const Err(this.failure); final AppFailure failure; }

// core/errors/app_failure.dart — taxonomia do PRD §10.1, inalterada
sealed class AppFailure {
  const AppFailure({this.cause, this.stackTrace});
  final Object? cause;            // só para log; nunca exibido
  final StackTrace? stackTrace;
  String get userMessage;         // textos do PRD §10.3
}
final class NetworkFailure extends AppFailure { ... }
final class TimeoutFailure extends AppFailure { ... }
final class NotFoundFailure extends AppFailure { ... }
final class RateLimitFailure extends AppFailure { ... }
final class ServerFailure extends AppFailure { final int statusCode; ... }
final class ParsingFailure extends AppFailure { ... }
final class UnexpectedFailure extends AppFailure { ... }
```

### 5.2 Entidades

```dart
final class PokemonSummary {
  const PokemonSummary({required this.id, required this.name});
  final int id;                   // 1..151
  final String name;              // nome cru da API (ex.: "mr-mime")
  String get displayName;         // RN-03 (delegado a PokemonFormat)
  String get number;              // RN-02 → "#122"
  Uri get artworkUrl;             // D5
}

enum PokemonType { bug, dark, dragon, electric, fairy, fighting, fire, flying, ghost,
                   normal, grass, ground, ice, poison, psychic, rock, steel, water, unknown;
  static PokemonType fromApi(String name);   // desconhecido → unknown (RN-10)
}

enum StatKind { hp, attack, defense, specialAttack, specialDefense, speed;
  String get label;                          // HP, ATK, DEF, SATK, SDEF, SPD
  static StatKind? fromApi(String name);     // "special-attack" → specialAttack; outros → null (ignorados)
}

final class PokemonDetail {
  const PokemonDetail({ required this.id, required this.name, required this.types,
    required this.weightHg, required this.heightDm, required this.abilities,
    required this.stats, this.description });
  final int id;
  final String name;
  final List<PokemonType> types;          // 1..2, ordem de slot (RF-18); vazio → ParsingFailure
  final int? weightHg;                    // null → "—"
  final int? heightDm;
  final List<String> abilities;           // nomes crus, ≤ 2, ordenados por slot (RN-12)
  final Map<StatKind, int> stats;         // ausente → 0 na exibição (ERR-05)
  final String? description;              // null → E-09
  PokemonType get primaryType;            // types.first
  PokemonSummary get summary;
  PokemonDetail withDescription(String? description);
}

enum SortOrder { number, name }
```

### 5.3 Regras puras (`models/rules/`)

```dart
abstract final class TextNormalizer {
  static String normalize(String input);   // trim, lowercase, remove diacríticos, remove pontuação (TS-11), colapsa espaços
}

abstract final class PokedexQuery {
  static List<PokemonSummary> visible(List<PokemonSummary> all,
      {required String query, required SortOrder sort});   // RN-04..09
  static bool matches(PokemonSummary p, String query);       // RN-05/06/07
}

abstract final class PokemonFormat {
  static String number(int id);                 // RN-02
  static String displayName(String apiName);    // RN-03 (mapa de exceções)
  static String weightKg(int? hg);              // RN-11 → "6.9 kg" | "—"
  static String heightM(int? dm);               // RN-11 → "0.7 m" | "—"
  static String abilityName(String apiName);    // RN-12 → "Solar Power"
  static String statValue(int value);           // RN-15 → "045"
  static double statFraction(int value);        // RN-15 → clamp(value / 255, 0, 1)
  static String flavorText(String raw);         // RN-13
}
```

### 5.4 Remoto

```dart
typedef JsonMap = Map<String, Object?>;

class PokeApiClient {
  PokeApiClient({required http.Client httpClient,
                 Uri? baseUrl,                                  // default https://pokeapi.co/api/v2/
                 Duration timeout = const Duration(seconds: 10)});
  Future<Result<JsonMap>> fetchIndex();                         // /pokemon?limit=151&offset=0
  Future<Result<JsonMap>> fetchPokemon(int id);                 // /pokemon/{id}
  Future<Result<JsonMap>> fetchSpecies(int id);                 // /pokemon-species/{id}
}
```

- Mapeia transporte e status → `AppFailure` conforme PRD §10.2; JSON inválido → `ParsingFailure`.
- Decodificação > 64 KB em `Isolate.run` (TS-12).
- Contador `req` incremental por instância; loga início (FINE) e fim com `ms`/status (FINE ou WARNING/SEVERE).

```dart
abstract final class PokemonMappers {     // lança FormatException/TypeError; o repository converte em ParsingFailure
  static List<PokemonSummary> index(JsonMap json);        // RN-01: descarta entradas sem id (WARNING)
  static PokemonDetail detail(JsonMap json);              // ERR-05: id, name, types obrigatórios
  static String? description(JsonMap speciesJson);        // RN-13: 1ª entrada "en"; nenhuma → null
}
```

### 5.5 Local

```dart
abstract interface class PokemonLocalStore {   // nunca lança (LS-05)
  Future<List<PokemonSummary>?> readIndex();
  Future<void> writeIndex(List<PokemonSummary> index);
  Future<PokemonDetail?> readDetail(int id);            // sem descrição
  Future<void> writeDetail(PokemonDetail detail);       // ignora detail.description
  Future<String?> readDescription(int id);
  Future<void> writeDescription(int id, String text);
  Future<void> clear();                                 // uso em testes/diagnóstico
}

final class SqflitePokemonLocalStore implements PokemonLocalStore {
  SqflitePokemonLocalStore({DatabaseFactory? factory, String? path});  // injetáveis para testes (ffi + in-memory)
}

abstract final class EntityCodec {
  static const int currentVersion = 1;
  static String encodeDetail(PokemonDetail detail);
  static PokemonDetail decodeDetail(String payload);    // lança em payload inválido → LS-03
}
```

### 5.6 Repository

```dart
abstract interface class PokemonRepository {
  Future<Result<List<PokemonSummary>>> fetchIndex();
  Future<Result<PokemonDetail>> fetchDetail(int id);   // tabela da §4.1
  PokemonDetail? peekDetail(int id);                   // síncrono, só L1; só retorna se núcleo E descrição estão em L1
}

final class CachedPokemonRepository implements PokemonRepository {
  CachedPokemonRepository({required PokeApiClient api, required PokemonLocalStore store});
}
```

Garantias do contrato:

1. Nunca lança; todo erro chega como `Err(AppFailure)`.
2. `Err` nunca é cacheado em nenhum nível (RN-19).
3. Chamadas concorrentes à mesma chave compartilham um único `Future` (RN-20), removido do mapa ao completar (com sucesso ou erro).
4. Mappers são executados dentro de `try/catch` que converte em `ParsingFailure` com log SEVERE contendo ≤ 200 caracteres do corpo (PRD §11.4).

### 5.7 Views — contratos públicos relevantes

```dart
class PokemonDetailPage extends StatelessWidget {
  static Route<void> route({required PokemonRepository repository,
                            required List<PokemonSummary> snapshot,
                            required int initialIndex});
}

class PokemonArtwork extends StatelessWidget {         // RF-05, RF-17, E-10, ERR-04
  const PokemonArtwork({required this.url, required this.size, this.semanticLabel});
}

class TypeChip extends StatelessWidget { const TypeChip(this.type); }

class FailureView extends StatelessWidget {            // E-03, E-08
  const FailureView({required this.failure, required this.onRetry});
}
```

---

## 6. Navegação

- `Navigator` 1.0 (D7): `MaterialApp(home: PokedexPage())` e `Navigator.push(PokemonDetailPage.route(...))`.
- `PopScope` não é necessário: voltar do sistema e ← fazem o mesmo `pop` (RF-23).
- ‹ › não empilham rotas; trocam o `current` do mesmo controller.
- RF-24 (swipe) — **nice-to-have**: `GestureDetector.onHorizontalDragEnd` na área da arte, com limiar de velocidade, chamando os mesmos `showPrevious/showNext`. Pode ser cortado sem afetar o resto.

---

## 7. Erros e rede de segurança

As regras ERR-01..08 do PRD valem integralmente. Acréscimos:

- **ERR-09 — Falhas de storage** são absorvidas pelo `SqflitePokemonLocalStore` (LS-05): logadas e degradadas, nunca convertidas em `AppFailure`. Isso é a forma sancionada de "não relançar" para a ERR-08.
- **ERR-10 — Log de falha de imagem** (ERR-04) é a única exceção à regra "Views não logam" (PRD §11.2): `PokemonArtwork` usa o logger `pokedex.view.image` em nível FINE no `errorBuilder`, porque não há controller envolvido no ciclo de vida da imagem.

---

## 8. Tema e acessibilidade

### 8.1 Tema

- `AppColors` (identity + grayscale), `TypeColors.of(PokemonType)` (Unknown = `#666666`), `AppTextStyles` (escala Poppins do PRD §5.2) e `AppTheme.light()` montando `ThemeData` com `ColorScheme.fromSeed` sobrescrito pelos tokens.
- Elevações 2dp/6dp via `BoxShadow` constantes; inner shadow do Search Bar via `DecoratedBox` dedicado.
- Imagens do grid com `cacheWidth` = largura lógica × `devicePixelRatio` (RNF-03).

### 8.2 Contraste (TS-10, resolve RNF-05)

Contraste medido (WCAG 2.1) das cores de tipo:

| Texto branco ≥ 4.5:1 | Texto branco < 4.5:1 (usar Dark `#212121`) |
|---|---|
| Dark 6.51 · Dragon 5.71 · Fighting 5.91 · Ghost 6.07 · Poison 5.58 · Unknown 5.74 | Bug 2.22 · Electric 1.50 · Fairy 2.13 · Fire 2.67 · Flying 2.65 · Normal 2.48 · Grass 2.02 · Ground 1.76 · Ice 1.61 · Psychic 3.12 · Rock 2.65 · Steel 1.93 · Water 3.04 |

Contratos em `core/theme/contrast.dart`:

```dart
abstract final class Contrast {
  static double ratio(Color a, Color b);                    // WCAG 2.1
  static Color onColor(Color background);                   // White ou Dark #212121, o de maior contraste
  static Color readableOn(Color foreground, Color background, {double min = 4.5});  // escurece em HSL até atingir `min`
}
```

| Uso | Regra |
|---|---|
| Texto do `TypeChip` | `onColor(typeColor)` |
| Nome, número e ← no header do detalhe | `onColor(typeColor)` |
| Rótulos HP/ATK/… e títulos "About"/"Base Stats" | `readableOn(typeColor, white)` |
| Barra de stat (objeto gráfico) | cor do tipo original (fidelidade; não é texto) |

Teste obrigatório: para os 19 tipos, todo par texto/fundo gerado atinge ≥ 4.5:1.

### 8.3 Semântica

Conforme RNF-04: `Semantics(label: "Bulbasaur, number 001", button: true)` no card; tooltips "Sort", "Clear search", "Back", "Previous Pokémon", "Next Pokémon"; Sort Button 32dp visual dentro de alvo 48dp; layout validado com `textScaler` 1.3.

---

## 9. Logging

Configuração e política de níveis do PRD §11 sem alterações. Hierarquia final:

| Logger | Dono |
|---|---|
| `pokedex.app` | bootstrap, handlers globais |
| `pokedex.api` | `PokeApiClient` |
| `pokedex.repository` | `CachedPokemonRepository` (hit/miss L1/L2, dedupe, mapeamento de falhas) |
| `pokedex.storage` | `SqflitePokemonLocalStore` (abertura com duração e versão — INFO; erros — WARNING; reset de schema — INFO) |
| `pokedex.controller.list` / `pokedex.controller.detail` | controllers |
| `pokedex.view.image` | `PokemonArtwork` (ERR-10) |

Nomes centralizados em `core/logging/loggers.dart` (constantes), para que testes anexem listeners sem strings soltas.

---

## 10. Estratégia de testes

| Alvo | Tipo | Ferramenta | Casos obrigatórios |
|---|---|---|---|
| `TextNormalizer`, `PokedexQuery` | Unit | `test` | RN-04..09, `#00`, `4`, `mr mime`, `farfetchd`, acentos, empate de nome |
| `PokemonFormat` | Unit | `test` | RN-02, RN-03 (4 exceções), RN-11..13, RN-15 limites (0, 255, >255) |
| `PokemonMappers` | Unit | fixtures JSON reais | Bulbasaur, Charmander, Mr. Mime; campos opcionais ausentes; obrigatórios ausentes → lança |
| `PokeApiClient` | Unit | `MockClient` (`http/testing.dart`) | 200, 404, 429, 500, 418, timeout, `SocketException`, JSON inválido; logs com `req` |
| `SqflitePokemonLocalStore` | Unit | `sqflite_common_ffi` + `inMemoryDatabasePath` | round-trip; LS-01 índice parcial; LS-02 versão; LS-03 corrupção; LS-04 upgrade; LS-05 nunca lança |
| `CachedPokemonRepository` | Unit | `MockClient` + `FakePokemonLocalStore` | L1/L2/rede; Err não cacheado; dedupe; tabela núcleo×descrição; species re-tentada após falha; `peekDetail` |
| Controllers | Unit | `FakePokemonRepository` (`Completer`) | máquinas de estado §3; RN-16; RN-17 (respostas fora de ordem); notify pós-dispose; logs |
| Views | Widget | `flutter_test` + fakes | E-01..E-10; Sort card abre/seleciona/fecha por tap-fora; ✕ limpa; ‹ › ocultas nas pontas; textScaler 1.3 |
| Contraste | Unit | `test` | §8.2 para os 19 tipos |
| Arquitetura | Unit | leitura de `lib/**` | regras de import da §2.2 (comentários removidos antes do scan) |

Logs são afirmados anexando listener a `Logger('pokedex')` (PRD §11.5). Meta: `flutter analyze` limpo, cobertura ≥ 80% em `lib/` excluindo `main.dart`.

---

## 11. Dependências

| Pacote | Tipo | Motivo |
|---|---|---|
| `provider` | runtime | DI + estado (D2) |
| `http` | runtime | PokéAPI |
| `logging` | runtime | §9 |
| `sqflite` | runtime | L2 (TS-01) |
| `path` | runtime | `join` do caminho do banco |
| `flutter_lints` | dev | RNF-06 |
| `sqflite_common_ffi` | dev | testes do store sem dispositivo |

Versões: estável mais recente compatível com o Flutter stable no momento do scaffold, fixada pelo `pubspec.lock` versionado. Nenhuma outra dependência sem atualizar esta tabela.

---

## 12. Resolução das Open Questions do PRD

| # | Questão | Decisão |
|---|---|---|
| 1 | "Moves" vs. habilidades | Rótulo **"Abilities"** |
| 2 | Cor do `Unknown` | Medium Gray `#666666` |
| 3 | Contraste dos chips | Escurecer — algoritmo TS-10, §8.2 |
| 4 | Separador decimal | `6.9 kg` (locale `en`, D8) |
| 5 | Poppins | Asset (TS-14) |
| 6 | Swipe (RF-24) | Mantido como nice-to-have, último item do plano |
| 7 | Splash e ícone | Pokébola branca sobre Primary `#DC0A2D`, via splash nativo de Android/iOS (sem pacote extra) |

---

## 13. Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Fair-use/indisponibilidade da PokéAPI | E-03/E-08 frequentes | L2 elimina refetch entre sessões; dedupe; retry só manual |
| Corrupção ou falha ao abrir o SQLite | Perda do cache | LS-03/LS-04/LS-06: descarta e segue com L1 + rede |
| Índice parcial gravado (crash no meio) | Lista incompleta offline | LS-01 transação + `index_count` |
| Entidade evolui e L2 tem formato antigo | Crash ou dados errados | `payload_version` (LS-02) |
| Jank ao decodificar `/pokemon` (~300 KB) | Frames perdidos na transição | TS-12 `Isolate.run` |
| Offline: grid só com Silhouettes | UX pobre sem rede | Aceito e documentado (§4.4); cache de imagem em disco fora do escopo |
| Texto escuro em 13 tipos diverge do Figma | Fidelidade visual menor | Decisão consciente de acessibilidade (Open Question 3) |
| `sqflite` não roda em web/desktop | — | Fora de RNF-01 (Android/iOS); testes usam ffi |
