import 'package:spend_trends/domain/life_event.dart';
import 'package:spend_trends/domain/stay_chain.dart';
import 'package:spend_trends/features/life_chains/life_chain_screen.dart';
import 'package:spend_trends/features/life_events/life_event_form_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/app_card.dart';
import 'package:spend_trends/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class LifeEventsScreen extends ConsumerWidget {
  const LifeEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifeEventsAsync = ref.watch(lifeEventsProvider);
    final housingAsync = ref.watch(housingChainProvider);
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
            housingChain: housingAsync.asData?.value,
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
    required this.housingChain,
    required this.jobChain,
  });

  final List<LifeEvent> lifeEvents;
  final StayChain? housingChain;
  final StayChain? jobChain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _LifeChainHeroCard(
          kind: LifeChainKind.housing,
          chain: housingChain,
        ),
        VSpace.sm,
        _LifeChainHeroCard(
          kind: LifeChainKind.job,
          chain: jobChain,
        ),
        VSpace.lg,
        Text('Milestones', style: AppText.body.medium.semibold),
        VSpace.sm,
        if (lifeEvents.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'No milestones yet',
                  style: AppText.body.large.semibold,
                ),
                VSpace.xs,
                Text(
                  'One-off dates and ranges still show on Trends.',
                  style: AppText.body.small,
                ),
                VSpace.md,
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
            if (index > 0) VSpace.sm,
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
            HSpace.md,
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
                      color: AppColors.textBody,
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
              color: AppColors.textDim,
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
            VSpace.xs,
            Text(
              lifeEvent.dateCaption,
              style: AppText.body.small,
            ),
            if (lifeEvent.note != null) ...[
              VSpace.xs,
              Text(lifeEvent.note!, style: AppText.caption),
            ],
          ],
        ),
      ),
    );
  }
}
