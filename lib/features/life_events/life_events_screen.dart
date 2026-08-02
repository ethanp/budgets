import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spend_trends/domain/life_event.dart';
import 'package:spend_trends/domain/stay_chain.dart';
import 'package:spend_trends/features/life_chains/life_chain_screen.dart';
import 'package:spend_trends/features/life_events/life_event_form_sheet.dart';
import 'package:spend_trends/providers/spend_trends_providers.dart';
import 'package:spend_trends/widgets/app_card.dart';
import 'package:spend_trends/widgets/app_primary_button.dart';
import 'package:spend_trends/widgets/sync_status_nav_button.dart';

const _logger = ELogger('LifeEventsScreen');

class LifeEventsScreen extends ConsumerWidget {
  const LifeEventsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifeEventsAsync = ref.watch(lifeEventsProvider);
    final housingAsync = ref.watch(housingChainProvider);
    final jobAsync = ref.watch(jobChainProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const SyncStatusNavButton(),
        title: const Text('Life Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => LifeEventFormSheet.show(context, ref: ref),
          ),
        ],
      ),
      body: SafeArea(
        child: lifeEventsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            _logger.log('LifeEventsProvider error: $error\n$stackTrace');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppMetrics.spaceLg),
                child: SelectableText(
                  '$error',
                  style: AppText.body.copyWith(color: AppColors.danger),
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
      padding: const EdgeInsets.all(AppMetrics.spaceLg),
      children: [
        _LifeChainHeroCard(
          kind: LifeChainKind.housing,
          chain: housingChain,
        ),
        const SizedBox(height: AppMetrics.spaceSm),
        _LifeChainHeroCard(
          kind: LifeChainKind.job,
          chain: jobChain,
        ),
        const SizedBox(height: AppMetrics.spaceLg),
        Text(
          'Milestones',
          style: AppText.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppMetrics.spaceSm),
        if (lifeEvents.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'No milestones yet',
                  style: AppText.section.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppMetrics.spaceXs),
                Text(
                  'One-off dates and ranges still show on Trends.',
                  style: AppText.caption,
                ),
                const SizedBox(height: AppMetrics.spaceMd),
                AppPrimaryButton(
                  onPressed: () =>
                      LifeEventFormSheet.show(context, ref: ref),
                  child: const Text('Add life event'),
                ),
              ],
            ),
          )
        else
          for (var index = 0; index < lifeEvents.length; index++) ...[
            if (index > 0) const SizedBox(height: AppMetrics.spaceSm),
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
          MaterialPageRoute<void>(
            builder: (_) => LifeChainScreen(kind: kind),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppMetrics.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.backgroundLift,
          borderRadius: AppMetrics.borderRadius(AppMetrics.radiusMd),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.14),
              AppColors.backgroundLift,
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
            const SizedBox(width: AppMetrics.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind.screenTitle,
                    style: AppText.section.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
        padding: const EdgeInsets.all(AppMetrics.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lifeEvent.title,
              style: AppText.section.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppMetrics.spaceXs),
            Text(
              lifeEvent.dateCaption,
              style: AppText.caption,
            ),
            if (lifeEvent.note != null) ...[
              const SizedBox(height: AppMetrics.spaceXs),
              Text(lifeEvent.note!, style: AppText.caption),
            ],
          ],
        ),
      ),
    );
  }
}
