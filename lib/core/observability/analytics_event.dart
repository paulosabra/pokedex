import 'package:meta/meta.dart';

/// Whether the Home list first rendered from a cold start or a warm cache.
enum ListOrigin {
  /// First render with no cached data yet.
  cold,

  /// First render served from existing cache.
  warm,
}

/// The detail-screen tab a user switched to (PRD §12 `detail_tab_changed`).
enum DetailTab {
  /// The About tab.
  about,

  /// The Stats tab.
  stats,

  /// The Evolution tab.
  evolution,
}

/// A typed, RNF-09-safe product-analytics event (PRD §12).
///
/// Every variant exposes only the whitelisted, non-PII properties from the
/// plan's §2.4 table — there is no free-form passthrough, so a caller cannot
/// accidentally log raw search terms or other personal data. [parameters]
/// values are non-null [Object] to match the Firebase/PostHog SDK contract
/// (`Map<String, Object>`).
///
/// T-30a defines all nine constructors; T-30b wires them at their call sites.
@immutable
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  /// The snake_case event name sent to analytics backends.
  String get name;

  /// The RNF-09-safe event properties.
  Map<String, Object> get parameters;
}

/// `list_viewed` — the Home list rendered (origin + visible count).
final class ListViewed extends AnalyticsEvent {
  /// Creates a [ListViewed] event.
  const ListViewed({required this.origin, required this.count});

  /// Whether this was a cold or warm first render.
  final ListOrigin origin;

  /// Number of items rendered.
  final int count;

  @override
  String get name => 'list_viewed';

  @override
  Map<String, Object> get parameters => {
    'origin': origin.name,
    'count': count,
  };
}

/// `search_performed` — a search resolved.
///
/// RNF-09: exposes only the [resultCount], **never** the raw query term.
final class SearchPerformed extends AnalyticsEvent {
  /// Creates a [SearchPerformed] event.
  const SearchPerformed({required this.resultCount});

  /// How many results the search returned.
  final int resultCount;

  @override
  String get name => 'search_performed';

  @override
  Map<String, Object> get parameters => {'result_count': resultCount};
}

/// `filter_applied` — a filter was applied (presence flags only, no values).
final class FilterApplied extends AnalyticsEvent {
  /// Creates a [FilterApplied] event.
  const FilterApplied({
    required this.hasType,
    required this.hasWeakness,
    required this.hasHeight,
  });

  /// Whether a type predicate is active.
  final bool hasType;

  /// Whether a weakness predicate is active.
  final bool hasWeakness;

  /// Whether a height predicate is active.
  final bool hasHeight;

  @override
  String get name => 'filter_applied';

  @override
  Map<String, Object> get parameters => {
    'has_type': hasType,
    'has_weakness': hasWeakness,
    'has_height': hasHeight,
  };
}

/// `sort_changed` — the sort criterion changed.
final class SortChanged extends AnalyticsEvent {
  /// Creates a [SortChanged] event.
  const SortChanged({required this.criteria});

  /// The new sort criterion's enum name.
  final String criteria;

  @override
  String get name => 'sort_changed';

  @override
  Map<String, Object> get parameters => {'criteria': criteria};
}

/// `generation_selected` — a National-Dex generation was selected.
final class GenerationSelected extends AnalyticsEvent {
  /// Creates a [GenerationSelected] event.
  const GenerationSelected({required this.generation});

  /// The selected generation (1–9).
  final int generation;

  @override
  String get name => 'generation_selected';

  @override
  Map<String, Object> get parameters => {'generation': generation};
}

/// `pokemon_opened` — a Pokémon detail was opened from the list.
final class PokemonOpened extends AnalyticsEvent {
  /// Creates a [PokemonOpened] event.
  const PokemonOpened({required this.id, required this.primaryType});

  /// National-Dex id of the opened Pokémon.
  final int id;

  /// The opened Pokémon's primary type name.
  final String primaryType;

  @override
  String get name => 'pokemon_opened';

  @override
  Map<String, Object> get parameters => {
    'id': id,
    'primary_type': primaryType,
  };
}

/// `detail_tab_changed` — the user switched detail tabs.
final class DetailTabChanged extends AnalyticsEvent {
  /// Creates a [DetailTabChanged] event.
  const DetailTabChanged({required this.tab});

  /// The tab switched to.
  final DetailTab tab;

  @override
  String get name => 'detail_tab_changed';

  @override
  Map<String, Object> get parameters => {'tab': tab.name};
}

/// `evolution_navigated` — the user tapped a stage in the evolution chain.
final class EvolutionNavigated extends AnalyticsEvent {
  /// Creates an [EvolutionNavigated] event.
  const EvolutionNavigated({required this.sourceId, required this.destId});

  /// The Pokémon navigated from.
  final int sourceId;

  /// The Pokémon navigated to.
  final int destId;

  @override
  String get name => 'evolution_navigated';

  @override
  Map<String, Object> get parameters => {
    'source_id': sourceId,
    'dest_id': destId,
  };
}

/// `error_shown` — a user-visible error state was rendered.
///
/// [teCode] is the PRD error code (e.g. `TE-01`); the failure→TE mapping is a
/// caller concern wired in T-30b (§4.3).
final class ErrorShown extends AnalyticsEvent {
  /// Creates an [ErrorShown] event.
  const ErrorShown({required this.teCode, required this.screen});

  /// The PRD error code shown (e.g. `TE-01`).
  final String teCode;

  /// The screen the error surfaced on.
  final String screen;

  @override
  String get name => 'error_shown';

  @override
  Map<String, Object> get parameters => {
    'te_code': teCode,
    'screen': screen,
  };
}
