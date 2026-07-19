import 'package:budgets/domain/life_event.dart';
import 'package:budgets/domain/stay_chain.dart';
import 'package:budgets/features/life_chains/life_chain_screen.dart';
import 'package:budgets/features/life_events/life_event_form_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class LifeEventsScreen extends ConsumerWidget {
  const LifeEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifeEventsAsync = ref.watch(lifeEventsProvider);
    final homebaseAsync = ref.watch(homebaseChainProvider);
    final jobAsync = ref.watch(jobChainProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: const SyncStatusNavButton(),
        middle: const Text('Life Events'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => LifeEventFormSheet.show(context, ref: ref),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: lifeEventsAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stackTrace) {
            debugPrint('LifeEventsProvider error: $error\n$stackTrace');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SelectableText(
                  '$error',
                  style: AppText.body.medium.error,
                ),
              ),
            );
          },
          data: (lifeEvents) => _LifeEventsBody(
            lifeEvents: lifeEvents,
            homebaseChain: homebaseAsync.asData?.value,
            jobChain: jobAsync.asData?.value,
          ),
        ),
      ),
    );
  }
}

class _LifeEventsBody extends ConsumerWidget {
  const _LifeEventsBody({
    required this.lifeEvents,
    required this.homebaseChain,
    required this.jobChain,
  });

  final List<LifeEvent> lifeEvents;
  final StayChain? homebaseChain;
  final StayChain? jobChain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _LifeChainHeroCard(
          kind: LifeChainKind.homebase,
          chain: homebaseChain,
        ),
        const SizedBox(height: AppSpacing.sm),
        _LifeChainHeroCard(
          kind: LifeChainKind.job,
          chain: jobChain,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Milestones', style: AppText.body.medium.semibold),
        const SizedBox(height: AppSpacing.sm),
        if (lifeEvents.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'No milestones yet',
                  style: AppText.body.large.semibold,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'One-off dates and ranges still show on Trends.',
                  style: AppText.body.small,
                ),
                const SizedBox(height: AppSpacing.md),
                CupertinoButton.filled(
                  onPressed: () =>
                      LifeEventFormSheet.show(context, ref: ref),
                  child: const Text('Add life event'),
                ),
              ],
            ),
          )
        else
          for (var index = 0; index < lifeEvents.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _LifeEventListTile(
              lifeEvent: lifeEvents[index],
              onTap: () => LifeEventFormSheet.show(
                context,
                ref: ref,
                lifeEvent: lifeEvents[index],
              ),
            ),
          ],
      ],
    );
  }
}

class _LifeChainHeroCard extends StatelessWidget {
  const _LifeChainHeroCard({
    required this.kind,
    required this.chain,
  });

  final LifeChainKind kind;
  final StayChain? chain;

  @override
  Widget build(BuildContext context) {
    final current = chain?.current;
    final accent = kind.trendBandColor;
    final caption = current == null
        ? kind.emptyHeroCaption
        : '${current.stay.label} · since '
            '${DateFormat.yMMMd().format(current.rangeStart)}';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => LifeChainScreen(kind: kind),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.14),
              AppColors.backgroundDepth2,
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.22),
              ),
              child: Icon(kind.icon, color: accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind.screenTitle,
                    style: AppText.body.large.semibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: AppText.body.small.copyWith(
                      color: AppColors.textColor2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textColor4,
            ),
          ],
        ),
      ),
    );
  }
}

class _LifeEventListTile extends StatelessWidget {
  const _LifeEventListTile({
    required this.lifeEvent,
    required this.onTap,
  });

  final LifeEvent lifeEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lifeEvent.title, style: AppText.body.large.semibold),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lifeEvent.dateCaption,
              style: AppText.body.small,
            ),
            if (lifeEvent.note != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(lifeEvent.note!, style: AppText.caption),
            ],
          ],
        ),
      ),
    );
  }
}
