import 'package:budgets/domain/life_event.dart';
import 'package:budgets/features/life_events/life_event_form_sheet.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class LifeEventsScreen extends ConsumerWidget {
  const LifeEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifeEventsAsync = ref.watch(lifeEventsProvider);

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
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('$error', style: AppText.body.medium.error),
            ),
          ),
          data: (lifeEvents) {
            if (lifeEvents.isEmpty) {
              return _emptyState(context, ref);
            }
            return _lifeEventsList(context, ref, lifeEvents);
          },
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No life events yet', style: AppText.headline.small),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Mark moves, jobs, and other milestones on your Trends charts.',
              style: AppText.body.medium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            CupertinoButton.filled(
              onPressed: () => LifeEventFormSheet.show(context, ref: ref),
              child: const Text('Add life event'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lifeEventsList(
    BuildContext context,
    WidgetRef ref,
    List<LifeEvent> lifeEvents,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: lifeEvents.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final lifeEvent = lifeEvents[index];
        return _LifeEventListTile(
          lifeEvent: lifeEvent,
          onTap: () => LifeEventFormSheet.show(
            context,
            ref: ref,
            lifeEvent: lifeEvent,
          ),
        );
      },
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
              DateFormat.yMMMd().format(lifeEvent.occurredOn),
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
