import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pokedex/app/theme/app_colors.dart';
import 'package:pokedex/app/theme/app_typography.dart';
import 'package:pokedex/core/pokemon/official_artwork_url.dart';
import 'package:pokedex/core/ui/components/app_bottom_sheet.dart';
import 'package:pokedex/features/pokemon/domain/entities/index_state.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/generation_sample.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/index_coordinator.dart';
import 'package:pokedex/features/pokemon/presentation/coordinators/index_fallbacks.dart';

/// Outcome returned by [`GenerationsSheet`] via [`Navigator.pop`].
///
/// Wrapped in a record so the caller can distinguish a drag-to-dismiss
/// (showModalBottomSheet returns `null`) from an explicit tap-to-select
/// (returns a record with `value` set to the chosen id or `null`).
typedef GenerationsSheetResult = ({int? value});

/// The Generation sheet (RF-25..RF-28), now driven by the live National-Dex
/// index instead of an 8-entry hardcoded map.
///
/// Renders one 160×129 tile per generation present in the index — so Gen IX
/// (rows 906–1025) appears as soon as the index has loaded. Each tile shows
/// three random distinct sprites (frozen during a single open, reshuffled on
/// close-and-reopen) and the Roman-numeral label. Tapping a tile pops with
/// the chosen generation id; tapping the active tile clears the filter.
///
/// When the index isn't available yet — first launch offline or while the
/// initial fetch is in flight — the sheet renders `IndexFallbacks` (the
/// published generations with fixed starter trios) so the surface is never
/// empty.
class GenerationsSheet extends ConsumerStatefulWidget {
  /// Creates a [GenerationsSheet] preloaded with [initial].
  const GenerationsSheet({this.initial, super.key});

  /// The currently active generation id, or `null` for no filter.
  final int? initial;

  @override
  ConsumerState<GenerationsSheet> createState() => _GenerationsSheetState();
}

class _GenerationsSheetState extends ConsumerState<GenerationsSheet> {
  @override
  void initState() {
    super.initState();
    // Per-open re-roll — the throttle inside the notifier guards against
    // rapid reopen jank (debug or animated router back-pop).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(generationSampleSeedProvider.notifier).reshuffle();
    });
  }

  void _select(int id) {
    final wasActive = widget.initial == id;
    Navigator.of(
      context,
    ).pop<GenerationsSheetResult>((value: wasActive ? null : id));
  }

  void _clear() {
    Navigator.of(context).pop<GenerationsSheetResult>((value: null));
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = widget.initial != null;
    final index = ref.watch(indexCoordinatorProvider);
    final isLive =
        index.value?.status == IndexStatus.ready ||
        index.value?.status == IndexStatus.stale;
    final ids = isLive
        ? (index.value!.generationIds.toList()..sort())
        : IndexFallbacks.generationIds;

    return AppBottomSheet(
      title: 'Generations',
      subtitle: 'Use search for generations to explore your Pokémon!',
      titleTrailing: hasActive
          ? TextButton(onPressed: _clear, child: const Text('Clear'))
          : null,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            // 160 / 129 in the Figma component (`105:617`).
            childAspectRatio: 160 / 129,
          ),
          itemCount: ids.length,
          itemBuilder: (context, gridIndex) {
            final generationId = ids[gridIndex];
            final label =
                IndexFallbacks.generationLabels[generationId] ??
                'Generation $generationId';
            return _GenerationCard(
              generationId: generationId,
              label: label,
              selected: widget.initial == generationId,
              onTap: () => _select(generationId),
            );
          },
        ),
      ),
    );
  }
}

class _GenerationCard extends ConsumerWidget {
  const _GenerationCard({
    required this.generationId,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int generationId;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = selected ? AppColors.actionPrimary : AppColors.backgroundInput;
    final fg = selected ? AppColors.textWhite : AppColors.textGray;
    final asyncSample = ref.watch(generationSampleProvider(generationId));
    final starterIds =
        asyncSample.value ??
        IndexFallbacks.starterTrios[generationId] ??
        const <int>[];
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 10 : 0,
      shadowColor: selected
          ? AppColors.actionPrimary.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Pokeball + dot pattern overlay — only meaningful on the grey
              // unselected variant; the red selected variant would otherwise
              // mask it with the same grey gradient.
              if (!selected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: SvgPicture.asset(
                      'assets/illustrations/generation_card_pattern.svg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // < 3 members renders what's available; padding
                            // with question marks would lie about coverage.
                            if (starterIds.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final spriteSize =
                                (constraints.maxWidth / starterIds.length)
                                    .clamp(28.0, 50.0);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final id in starterIds)
                                  _StarterSprite(
                                    pokemonId: id,
                                    size: spriteSize,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTypography.description.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarterSprite extends StatelessWidget {
  const _StarterSprite({required this.pokemonId, required this.size});

  final int pokemonId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: officialArtworkUrl(pokemonId),
        fit: BoxFit.contain,
        // No placeholder/error widget — empty space matches Figma's empty
        // tile state and avoids leaking a Material spinner into the grid.
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
