import 'dart:async';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/features/settings/settings_section.dart';
import 'package:spend_trends/providers/sync_ui_provider.dart';
import 'package:spend_trends/services/sync/sync_config.dart';

/// PowerSync connection: status, Home LAN vs Tailscale reachability, Probe/Switch.
class SyncStatusTile extends ConsumerStatefulWidget {
  const SyncStatusTile();

  @override
  ConsumerState<SyncStatusTile> createState() => _SyncStatusTileState();
}

class _SyncStatusTileState extends ConsumerState<SyncStatusTile> {
  static const _style = SettingsSectionStyle.sync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !spendTrendsSyncConfigured()) return;
      unawaited(ref.read(syncEnsureProvider).ensureConnected());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!spendTrendsSyncConfigured()) {
      return const SettingsSectionHeader(
        icon: Icons.cloud,
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
        const SizedBox(height: AppMetrics.spaceMd),
        _statusRow(
          isConnected: isConnected,
          isConnecting: isConnecting,
          description: description,
        ),
        const SizedBox(height: AppMetrics.spaceSm),
        ..._hostRows(
          activeHost: activeHost,
          health: health,
          hostResolution: hostResolution,
        ),
        ..._switchRouteSection(
          activeHost: activeHost,
          hostResolution: hostResolution,
        ),
        const SizedBox(height: AppMetrics.spaceXs),
        SizedBox(
          height: 18,
          child: (pendingAsync.value ?? 0) > 0
              ? _pendingRow(pendingAsync.value!)
              : const SizedBox.shrink(),
        ),
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
            icon: offline ? Icons.cloud_outlined : Icons.cloud,
            title: 'Sync',
            style: _style,
          ),
        ),
        const SizedBox(width: AppMetrics.spaceSm),
        _probeButton(isProbing),
      ],
    );
  }

  Widget _probeButton(bool isProbing) {
    return OutlinedButton(
      onPressed: isProbing
          ? null
          : () => ref.read(syncEnsureProvider).ensureConnected(),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.spaceMd,
          vertical: AppMetrics.spaceXs,
        ),
        backgroundColor: AppColors.backgroundLift,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isProbing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _style.accent,
              ),
            )
          else
            Icon(
              Icons.swap_horiz,
              size: 14,
              color: _style.accent,
            ),
          const SizedBox(width: AppMetrics.spaceXs),
          Text(
            'Probe',
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: _style.accent,
            ),
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
        const SizedBox(width: AppMetrics.spaceSm),
        Expanded(
          child: Text(
            description,
            style: AppText.body.copyWith(color: AppColors.textMuted),
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
      if (index > 0) rows.add(const SizedBox(height: AppMetrics.spaceXs));
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
      padding: const EdgeInsets.only(left: AppMetrics.spaceLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: AppMetrics.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: AppText.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: AppMetrics.spaceXs),
                      Text(
                        '· selected',
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _style.accent,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  host.isEmpty ? '(not configured)' : host,
                  style: AppText.caption.copyWith(color: AppColors.textMuted),
                ),
                if (probe != null && !isProbing)
                  Text(
                    probe.summary,
                    style: AppText.caption.copyWith(color: statusColor),
                  ),
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
      const SizedBox(height: AppMetrics.spaceMd),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () =>
              ref.read(syncEnsureProvider).switchHost(alternate.host),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppMetrics.spaceSm),
            backgroundColor: AppColors.backgroundLift,
            side: const BorderSide(color: AppColors.border),
          ),
          child: Text(
            'Switch to ${alternate.label}',
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: _style.accent,
            ),
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
    if (isProbing || probe == null) return Icons.circle_outlined;
    if (probe.reachable) return Icons.check_circle;
    return Icons.cancel;
  }

  Color _probeColor({
    required HostCandidateHealth? probe,
    required bool isProbing,
  }) {
    if (isProbing || probe == null) return AppColors.textMuted;
    if (probe.reachable) return AppColors.success;
    return AppColors.warning;
  }

  Widget _pendingRow(int pending) {
    return Padding(
      padding: const EdgeInsets.only(left: AppMetrics.spaceLg),
      child: Row(
        children: [
          const Icon(
            Icons.upload,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppMetrics.spaceSm),
          Expanded(
            child: Text(
              '$pending pending upload${pending == 1 ? '' : 's'}',
              style: AppText.caption.copyWith(color: AppColors.textMuted),
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
