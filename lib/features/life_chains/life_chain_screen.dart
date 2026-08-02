import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/domain/stay_chain.dart';
import 'package:spend_trends/features/life_chains/chain_stay_form_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';

class LifeChainScreen extends ConsumerWidget {
  const LifeChainScreen({required this.kind});

  final LifeChainKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chainAsync = switch (kind) {
      LifeChainKind.housing => ref.watch(housingChainProvider),
      LifeChainKind.job => ref.watch(jobChainProvider),
    };

    return AppScaffoldShell(
      appBar: AppBar(title: Text(kind.screenTitle)),
      body: chainAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppMetrics.spaceLg),
            child: Text(
              '$error',
              style: AppText.body.copyWith(color: AppColors.danger),
            ),
          ),
        ),
        data: (chain) => _ChainBody(kind: kind, chain: chain),
      ),
    );
  }
}

class _ChainBody extends ConsumerWidget {
  const _ChainBody({required this.kind, required this.chain});

  final LifeChainKind kind;
  final StayChain chain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.spaceLg,
        AppMetrics.spaceMd,
        AppMetrics.spaceLg,
        AppMetrics.spaceXl,
      ),
      children: [
        Text(
          kind == LifeChainKind.housing
              ? 'Where you’ve lived — a path of places over time.'
              : 'Where you’ve worked — a path of roles over time.',
          style: AppText.body.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppMetrics.spaceLg),
        if (chain.isEmpty)
          _EmptyChain(kind: kind)
        else
          _ChainPath(kind: kind, chain: chain),
        const SizedBox(height: AppMetrics.spaceXl),
        AppPrimaryButton(
          onPressed: () {
            final oldestStartedOn = chain.oldest?.stay.startedOn.startOfDay;
            ChainStayFormSheet.show(
              context,
              ref: ref,
              kind: kind,
              initialStartedOn: oldestStartedOn?.subtract(
                const Duration(days: 1),
              ),
            );
          },
          child: Text(kind.addCta),
        ),
      ],
    );
  }
}

class _EmptyChain extends StatelessWidget {
  const _EmptyChain({required this.kind});

  final LifeChainKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 32,
        horizontal: AppMetrics.spaceLg,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundLift,
        borderRadius: AppMetrics.borderRadius(AppMetrics.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(kind.icon, size: 36, color: kind.trendBandColor),
          const SizedBox(height: AppMetrics.spaceMd),
          Text(kind.emptyHeroCaption, style: AppText.section),
          const SizedBox(height: AppMetrics.spaceSm),
          Text(
            'Add the first link to start the chain.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChainPath extends ConsumerWidget {
  const _ChainPath({required this.kind, required this.chain});

  final LifeChainKind kind;
  final StayChain chain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentsNewestFirst = chain.segments.reversed.toList();

    return Column(
      children: [
        for (var index = 0; index < segmentsNewestFirst.length; index++) ...[
          if (index > 0) _PathConnector(color: kind.trendBandColor),
          _StayNode(
            kind: kind,
            segment: segmentsNewestFirst[index],
            onTap: () => ChainStayFormSheet.show(
              context,
              ref: ref,
              kind: kind,
              stay: segmentsNewestFirst[index].stay,
            ),
          ),
        ],
      ],
    );
  }
}

class _PathConnector extends StatelessWidget {
  const _PathConnector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Center(
        child: Container(
          width: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.55),
                color.withValues(alpha: 0.2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StayNode extends StatelessWidget {
  const _StayNode({
    required this.kind,
    required this.segment,
    required this.onTap,
  });

  final LifeChainKind kind;
  final ChainStaySegment segment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = kind.trendBandColor;
    final isCurrent = segment.isCurrent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppMetrics.spaceMd),
        decoration: BoxDecoration(
          color: isCurrent
              ? accent.withValues(alpha: 0.12)
              : AppColors.backgroundLift,
          borderRadius: AppMetrics.borderRadius(AppMetrics.radiusMd),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.55)
                : AppColors.border,
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isCurrent ? 44 : 36,
              height: isCurrent ? 44 : 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent
                    ? accent.withValues(alpha: 0.28)
                    : AppColors.surfaceRaised,
                border: Border.all(
                  color: isCurrent ? accent : AppColors.borderStrong,
                ),
              ),
              child: Icon(
                kind.icon,
                size: isCurrent ? 22 : 18,
                color: isCurrent ? accent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: AppMetrics.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCurrent) ...[
                    Text(
                      kind.currentCaption,
                      style: AppText.caption.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    segment.stay.label,
                    style: AppText.section.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isCurrent
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppMetrics.spaceXs),
                  Text(
                    segment.dateCaption,
                    style: AppText.caption.copyWith(
                      color: isCurrent
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                    ),
                  ),
                  if (segment.stay.note != null) ...[
                    const SizedBox(height: AppMetrics.spaceXs),
                    Text(segment.stay.note!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
