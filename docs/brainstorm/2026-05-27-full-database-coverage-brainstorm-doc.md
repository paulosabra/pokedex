---
date: 2026-05-27
topic: full-database-coverage
---

# Full Database Coverage — Search · Generations · Sort · Filters

## What We're Building

Lift the four discovery surfaces (Search field, Generations sheet, Sort sheet,
Filters sheet) off the paginated subset of Pokémon and onto the **entire
PokeAPI catalogue** (1025 entries as of 2026, growing). Introduce a single
lightweight global index — one HTTP call against `/pokemon?limit=100000`
returning `{id, name, url}` for every Pokémon — persisted to a new Drift table
that becomes the source of truth for "what Pokémon exist." Search, Sort,
Generations, and the NumberRange filter read from this index directly;
non-index filters (Types, Weaknesses, Heights, Weights) become progressively
complete via a paced background backfill of `PokemonDetails`. Search results,
generation tiles, and detail screens hydrate lazily from the existing
per-Pokémon cache when tapped.

Net surface change: Search finds every Pokémon by name or id; the Generations
sheet shows one tile per real generation in the index (Gen IX appears
automatically) with three random-but-distinct Pokémon per tile chosen fresh on
each sheet open; Sort orders the entire catalogue; the NumberRange slider
snaps to the catalogue's true min/max (currently `1..1025`) instead of the
hardcoded `1..898`.

## Why This Approach

Four sibling asks, one underlying problem: the data layer's notion of "the
world" is bounded by what the user has scrolled through. The cheapest credible
fix is a **second cache layer** that mirrors PokeAPI's catalogue index (~1300
rows of `id + name + generation`, ~50KB persisted) instead of trying to
materialize the full detail catalogue eagerly. The PokeAPI `/pokemon` list
endpoint already returns a paginated index for free; calling it with
`limit=100000&offset=0` returns the entire catalogue in one ~200KB JSON
document — slower than a single 24-page request but still one round-trip and
only repeated on TTL expiry.

Three alternatives were weighed.

**Background backfill of full detail cache** — silently page through every
Pokémon to populate `PokemonSummaries` and `PokemonDetails` end-to-end — was
rejected as the *primary* mechanism because it conflates "I know X exists"
with "I have all X's data" and forces ~1300 detail calls (~10MB cached)
before Search/Sort feel complete. It's right *for filter dimensions that need
detail*, which is why we keep it as a secondary mechanism behind the index —
but starting there punishes users on first launch and doesn't fix Search at
all.

**On-demand per-operation queries** — each sheet/search hits PokeAPI in
isolation — was rejected because PokeAPI has no remote search endpoint.
Search would still need a client-side index, so we'd build the index anyway
plus extra remote calls for the other sheets. Strictly worse.

**Skip the index and just bump the NumberRange constant to 1025** — addresses
one of the four asks but leaves Search/Sort/Generations bounded by
pagination. Fails the "use the entire database" intent and bakes in a future
bug every time PokeAPI releases a generation.

On the **random-3-per-generation** spec, "always different" was clarified to
mean *three distinct Pokémon per tile*, not *different from previously-seen
Pokémon*. The sample is computed when the Generations sheet opens and frozen
for the lifetime of that open — eliminates rebuild flicker (keyboard, scroll,
theme change all rebuild the sheet) while still feeling lively because
closing-and-reopening reshuffles. No persistence, no "seen" state, no edge
case where all members of a generation have been shown. Replaces the
hardcoded `_starters` const map entirely; starters are no longer special.

On the **source of truth for ceilings**, the index *is* the truth.
NumberRange `max = SELECT MAX(id) FROM pokemon_index`. Generations sheet
`tiles = SELECT DISTINCT generation_id FROM pokemon_index ORDER BY
generation_id`. Gen labels stay as a `const Map<int, String>` keyed by
generation id (labels don't change), but the **set** of tiles is data-driven.
New PokeAPI generations land in the UI on the next index refresh without a
code change. This also fixes the pre-existing drift between the
`_kNumberRangeMax = 898` constant and the `generation_ranges.dart` mapper
that already supports up to 1025.

On **filter coverage**, the honest framing is *progressive completeness*:
NumberRange and Search are full-DB from the moment the index loads;
Type / Weakness / Height / Weight filters are accurate within the *hydrated*
subset, and a paced background backfill (~8 concurrent, exponential backoff
on 429s) closes the gap over minutes. A small `indexing… X/Y` indicator in
the Filters sheet header tells the user when filters become exhaustive.
Hiding the gap entirely would require either pre-fetching every detail on
first launch (rejected above) or pretending partial filters are complete
(silently wrong).

On **search rendering during backfill**, results render as **skeleton cards
with id + name + sprite** (the official-artwork sprite URL is derivable from
id: `…/sprites/pokemon/other/official-artwork/{id}.png`, no detail call
needed), type chips show a loading shimmer, and tapping triggers a single
detail fetch into the existing cache. This matches the existing
tap-to-hydrate behavior for paginated rows and avoids the "search feels
broken because results are missing" failure mode that hiding skeletons would
cause.

## Key Decisions

- **New Drift table `PokemonIndex`** (id PK, name, nameNormalized,
  generationId, indexedAt) populated by a single
  `GET /pokemon?limit=100000` call on first launch and on TTL expiry.
  Rationale: separates "catalogue knowledge" from "detail cache" — two
  independent TTLs, two independent failure modes, no schema churn on
  `PokemonSummaries`. The existing summaries/details tables continue to cache
  hydrated rows; the new index covers everything.

- **Long TTL for the index (30 days), short for detail (7 days)**. New
  Pokémon ship roughly once a generation (years apart); a 30-day catalogue
  refresh is plenty and avoids waking up a 200KB call on every cold start.
  Detail cache stays at 7 days to keep stats/types fresh against any PokeAPI
  corrections.

- **Search reads from `PokemonIndex`, not `PokemonSummaries`**. The 300ms
  debounce and numeric-vs-text dispatch stay; what changes is the table
  queried. SQL `LIKE` over `nameNormalized` plus exact `id` match —
  identical query shape, larger row set. Existing `findPokemon` use case
  extended (not duplicated).

- **Sort runs on the join `PokemonIndex LEFT JOIN PokemonDetails`**.
  Number/name sorts work from the index alone (full coverage); future sorts
  that need stats (HP, attack) would degrade to the hydrated subset, but
  that's out of scope here. Cleanly extensible.

- **Filters split by what they need:**
  - NumberRange: index-only, full-DB, dynamic `min`/`max` from
    `SELECT MIN(id), MAX(id)` over `PokemonIndex`.
  - Types / Weaknesses / Heights / Weights: detail-required, progressively
    complete as background backfill runs. Header reads "Filtering across
    X of Y Pokémon" until X == Y.

- **Background detail backfill** launched when the index finishes loading
  and the user is idle (no in-flight pagination), throttled at 8 concurrent
  requests with exponential backoff on 429/5xx, persisting into the existing
  `PokemonDetails` table. Single coordinator provider; can be paused on app
  backgrounding and resumed on resume.

- **Generations sheet is data-driven**: one tile per `DISTINCT generationId`
  in the index. Gen labels (`I`, `II`, …) come from a `const Map<int,
  String>`; the tile *set* comes from the index. Gen IX appears
  automatically the first time the index runs.

- **Random 3 per generation tile**: `randomSample(genMembers, 3)` computed
  once when the sheet opens, held in the sheet's state, refreshed only on
  close-and-reopen. No persisted "seen" tracking. Replaces the hardcoded
  `_starters` map.

- **Skeleton search results**: result tiles render id + name +
  sprite-url-from-id immediately; type chips show shimmer until detail
  loads; tap fetches detail on demand. Indistinguishable from hydrated
  results once detail arrives.

- **Branch placement**: this brainstorm doc is written on the current
  branch `feature/presentation-part4`. The work itself spans data, domain,
  and presentation — almost certainly a dedicated epic. Confirm during
  planning whether it lives on a new `epic/full-database-coverage` branch
  or as a slice of an existing one (per [[project_git-flow]]).

## Open Questions

- **Storage budget**: index is ~50KB, full detail backfill is ~10MB on
  disk. Is that acceptable on web (IndexedDB) and constrained mobile? Worth
  confirming during planning before committing to "all 1300 backfilled by
  default."

- **First-launch UX during index fetch**: today the app shows a shimmer
  over an empty list and starts paginating. With an index gating
  Search/Sort/Filters/Generations, what does the user see if they open one
  of these sheets before the index resolves? Options to weigh in plan:
  block the sheet with a loading state, fall back to "loaded subset only"
  with a banner, or pre-load the index opportunistically before the user
  can open a sheet.

- **Backfill UX policy**: should the "indexing X/Y" indicator be visible
  only in the Filters sheet header, or globally (e.g., a thin progress bar
  on the list screen)? Affects whether backfill is a hidden mechanism or a
  user-visible feature.

- **Throttle parameters for backfill**: 8 concurrent / exponential backoff
  is a sensible default but PokeAPI's actual rate limits are undocumented
  (community lore says ~100 req/min unauthenticated). Worth a small load
  test during plan execution; may need to drop to 4–5 concurrent.

- **Migration of existing cache**: `PokemonSummaries` already exists.
  Should the index table coexist as a separate table, or should
  `PokemonSummaries` gain an `is_index_only` boolean? Coexisting tables is
  cleaner architecturally; one-table-with-flag is one fewer migration.
  Tradeoff to settle in design.

- **Offline behavior for the index**: if the index has never loaded and
  the user is offline, every "full-DB" surface degrades to the hydrated
  subset. Confirm during planning whether that needs an explicit error
  state (`OfflineErrorWidget` already exists for similar cases) or whether
  the existing stale-cache banner is enough.
