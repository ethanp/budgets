import 'dart:async';

import 'package:budgets/features/settings/settings_section.dart';
import 'package:budgets/providers/sync_ui_provider.dart';
import 'package:budgets/services/sync/sync_config.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// PowerSync connection: status, Home LAN vs Tailscale reachability, Probe/Switch.
class SyncStatusTile extends ConsumerStatefulWidget {
  const SyncStatusTile({super.key});

  @override
  ConsumerState<SyncStatusTile> createState() => _SyncStatusTileState();
}

class _SyncStatusTileState extends ConsumerState<SyncStatusTile> {
  static const _style = SettingsSectionStyle.sync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !budgetsSyncConfigured()) return;
      unawaited(ref.read(syncEnsureProvider).ensureConnected());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!budgetsSyncConfigured()) {
      return const SettingsSectionHeader(
        icon: CupertinoIcons.cloud,
        title: 'Sync',
        style: _style,
        caption:
            'Set POWERSYNC_JWT_SECRET and SERVER_HOST_LAN in .env to enable sync.',
      );
    }

    final syncStatus = ref.watch(syncStatusProvider);
    final description = ref.watch(syncStatusDescriptionProvider);
    final pendingAsync = ref.watch(pendingUploadCountProvider);
    final activeHost = ref.watch(hostResolverProvider);
    final health = ref.watch(hostHealthProvider);
    final hostResolution = ref.watch(syncConfigProvider).hostResolution;
    final isConnected = syncStatus.value?.connected ?? false;
    final isConnecting = syncStatus.value?.connecting ?? false;
    final offline = ref.watch(isOfflineProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(offline: offline, isProbing: health.isProbing),
        VSpace.md,
        _statusRow(
          isConnected: isConnected,
          isConnecting: isConnecting,
          description: description,
        ),
        VSpace.sm,
        ..._hostRows(
          activeHost: activeHost,
          health: health,
          hostResolution: hostResolution,
        ),
        ..._switchRouteSection(
          activeHost: activeHost,
          hostResolution: hostResolution,
        ),
        if ((pendingAsync.value ?? 0) > 0) ...[
          VSpace.xs,
          _pendingRow(pendingAsync.value!),
        ],
      ],
    );
  }

  Widget _header({
    required bool offline,
    required bool isProbing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SettingsSectionHeader(
            icon: offline ? CupertinoIcons.cloud : CupertinoIcons.cloud_fill,
            title: 'Sync',
            style: _style,
          ),
        ),
        HSpace.sm,
        _probeButton(isProbing),
      ],
    );
  }

  Widget _probeButton(bool isProbing) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      minimumSize: Size.zero,
      color: AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onPressed: isProbing
          ? null
          : () => ref.read(syncEnsureProvider).ensureConnected(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isProbing)
            CupertinoActivityIndicator(radius: 7, color: _style.accent)
          else
            Icon(
              CupertinoIcons.dot_radiowaves_left_right,
              size: 14,
              color: _style.accent,
            ),
          HSpace.xs,
          Text(
            'Probe',
            style: AppText.body.small.semibold.copyWith(color: _style.accent),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required bool isConnected,
    required bool isConnecting,
    required String description,
  }) {
    final dotColor = isConnected
        ? AppColors.success
        : (isConnecting ? _style.accent : AppColors.warning);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
        HSpace.sm,
        Expanded(
          child: Text(
            description,
            style: AppText.body.medium.copyWith(color: AppColors.textSupport),
          ),
        ),
      ],
    );
  }

  List<Widget> _hostRows({
    required String activeHost,
    required HostHealthState health,
    required HostResolutionSettings hostResolution,
  }) {
    final rows = <Widget>[];
    for (var index = 0; index < hostResolution.candidates.length; index++) {
      if (index > 0) rows.add(VSpace.xs);
      final host = hostResolution.candidates[index];
      rows.add(
        _hostRow(
          label: hostResolution.labels[host] ?? host,
          host: host,
          probe: health.forHost(host),
          isActive: activeHost == host,
          isProbing: health.isProbing && health.candidates.isEmpty,
        ),
      );
    }
    return rows;
  }

  Widget _hostRow({
    required String label,
    required String host,
    required HostCandidateHealth? probe,
    required bool isActive,
    required bool isProbing,
  }) {
    final statusIcon = _probeIcon(probe: probe, isProbing: isProbing);
    final statusColor = _probeColor(probe: probe, isProbing: isProbing);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          HSpace.sm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: AppText.body.small.copyWith(
                        color: AppColors.textSupport,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (isActive) ...[
                      HSpace.xs,
                      Text(
                        '· selected',
                        style: AppText.body.small.semibold
                            .copyWith(color: _style.accent),
                      ),
                    ],
                  ],
                ),
                Text(
                  host.isEmpty ? '(not configured)' : host,
                  style: AppText.body.small.copyWith(color: AppColors.textDim),
                ),
                if (probe != null && !isProbing) ...[
                  Text(
                    probe.summary,
                    style: AppText.body.small.copyWith(color: statusColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _switchRouteSection({
    required String activeHost,
    required HostResolutionSettings hostResolution,
  }) {
    final alternate = _alternateRoute(
      activeHost: activeHost,
      hostResolution: hostResolution,
    );
    if (alternate == null) return const [];
    return [
      VSpace.md,
      SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          color: AppColors.backgroundDepth2,
          onPressed: () =>
              ref.read(syncEnsureProvider).switchHost(alternate.host),
          child: Text(
            'Switch to ${alternate.label}',
            style: AppText.body.medium.semibold.copyWith(color: _style.accent),
          ),
        ),
      ),
    ];
  }

  _AlternateRoute? _alternateRoute({
    required String activeHost,
    required HostResolutionSettings hostResolution,
  }) {
    if (hostResolution.candidates.length < 2) return null;
    for (final host in hostResolution.candidates) {
      if (host == activeHost) continue;
      return _AlternateRoute(
        label: hostResolution.labels[host] ?? host,
        host: host,
      );
    }
    return null;
  }

  IconData _probeIcon({
    required HostCandidateHealth? probe,
    required bool isProbing,
  }) {
    if (isProbing || probe == null) return CupertinoIcons.circle;
    if (probe.reachable) return CupertinoIcons.checkmark_circle_fill;
    return CupertinoIcons.xmark_circle_fill;
  }

  Color _probeColor({
    required HostCandidateHealth? probe,
    required bool isProbing,
  }) {
    if (isProbing || probe == null) return AppColors.textDim;
    if (probe.reachable) return AppColors.success;
    return AppColors.warning;
  }

  Widget _pendingRow(int pending) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.arrow_up_circle,
            size: 14,
            color: AppColors.textDim,
          ),
          HSpace.sm,
          Expanded(
            child: Text(
              '$pending pending upload${pending == 1 ? '' : 's'}',
              style: AppText.body.small.copyWith(color: AppColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternateRoute {
  const _AlternateRoute({required this.label, required this.host});

  final String label;
  final String host;
}
