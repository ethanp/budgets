import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/features/life_chains/chain_stay_form_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LifeChainScreen extends ConsumerWidget {
  const LifeChainScreen({super.key, required this.kind});

  final LifeChainKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chainAsync = switch (kind) {
      LifeChainKind.housing => ref.watch(housingChainProvider),
      LifeChainKind.job => ref.watch(jobChainProvider),
    };

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(kind.screenTitle),
      ),
      child: SafeArea(
        child: chainAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('$error', style: AppText.body.medium.error),
            ),
          ),
          data: (chain) => _ChainBody(kind: kind, chain: chain),
        ),
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
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Text(
          kind == LifeChainKind.housing
              ? 'Where you’ve lived — a path of places over time.'
              : 'Where you’ve worked — a path of roles over time.',
          style: AppText.body.medium.copyWith(color: AppColors.textSupport),
        ),
        VSpace.lg,
        if (chain.isEmpty)
          _EmptyChain(kind: kind)
        else
          _ChainPath(kind: kind, chain: chain),
        VSpace.xl,
        CupertinoButton.filled(
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
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        children: [
          Icon(kind.icon, size: 36, color: kind.trendBandColor),
          VSpace.md,
          Text(kind.emptyHeroCaption, style: AppText.headline.small),
          VSpace.sm,
          Text(
            'Add the first link to start the chain.',
            style: AppText.body.small,
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
    // Newest at top for a “path arriving at now” feel.
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isCurrent
              ? accent.withValues(alpha: 0.12)
              : AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.55)
                : AppColors.borderDepth1,
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
                    : AppColors.backgroundDepth4,
                border: Border.all(
                  color: isCurrent ? accent : AppColors.borderDepth2,
                ),
              ),
              child: Icon(
                kind.icon,
                size: isCurrent ? 22 : 18,
                color: isCurrent ? accent : AppColors.textSupport,
              ),
            ),
            HSpace.md,
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
                    style: AppText.body.large.semibold.copyWith(
                      color: isCurrent
                          ? AppColors.textBright
                          : AppColors.textBody,
                    ),
                  ),
                  VSpace.xs,
                  Text(
                    segment.dateCaption,
                    style: AppText.body.small.copyWith(
                      color: isCurrent
                          ? AppColors.textBody
                          : AppColors.textSupport,
                    ),
                  ),
                  if (segment.stay.note != null) ...[
                    VSpace.xs,
                    Text(segment.stay.note!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textDim,
            ),
          ],
        ),
      ),
    );
  }
}
