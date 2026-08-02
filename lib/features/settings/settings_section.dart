import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/theme/finance_colors.dart';

/// Per-section accent used for icons, links, and hairlines.
class SettingsSectionStyle {
  const SettingsSectionStyle({required this.accent});

  final Color accent;

  /// Banks — teal (money / SimpleFIN).
  static const banks = SettingsSectionStyle(accent: FinanceColors.accentPrimary);

  /// Sync — cool indigo (near console chrome).
  static const sync = SettingsSectionStyle(accent: Color(0xFF7B8CDE));

  /// Maintenance — muted clay (not bright yellow).
  static const maintenance = SettingsSectionStyle(accent: Color(0xFF9A7B6A));
}

/// Emphatic type roles for Settings (stronger than global AppText defaults).
class SettingsType {
  SettingsType._();

  static const sectionTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.4,
  );

  static const sectionMeta = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.35,
  );

  static const institution = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    height: 1.2,
    letterSpacing: 0.9,
  );

  static const rowTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  static const rowTitleEmphasis = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const toolTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const toolCaption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.35,
  );

  static const amount = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const amountMuted = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Bare accent icon — no chip background.
class SettingsGlyph extends StatelessWidget {
  const SettingsGlyph({
    required this.icon,
    required this.style,
    this.size = 26,
  });

  final IconData icon;
  final SettingsSectionStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Icon(icon, size: size, color: style.accent),
    );
  }
}

/// Icon + title (+ optional caption) for a Settings page section.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    required this.icon,
    required this.title,
    required this.style,
    this.caption,
  });

  final IconData icon;
  final String title;
  final SettingsSectionStyle style;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SettingsGlyph(icon: icon, style: style),
        const SizedBox(width: AppMetrics.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SettingsType.sectionTitle),
              if (caption != null) ...[
                const SizedBox(height: AppMetrics.spaceXs),
                Text(caption!, style: SettingsType.sectionMeta),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-row maintenance control with metal fill + finance accent overlay.
class SettingsToolRow extends StatelessWidget {
  const SettingsToolRow({
    required this.icon,
    required this.title,
    required this.caption,
    required this.onAction,
    required this.style,
    this.busy = false,
    this.message,
    this.progress,
    this.onCancel,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onAction;
  final SettingsSectionStyle style;
  final bool busy;
  final String? message;
  final Widget? progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onAction,
        borderRadius: AppMetrics.borderRadius(AppMetrics.radiusSm),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: busy ? 0.7 : 1,
          child: AppSurface(
            kind: AppSurfaceKind.tinted,
            accent: style.accent,
            padding: const EdgeInsets.all(AppMetrics.spaceMd),
            borderRadius: AppMetrics.borderRadius(AppMetrics.radiusSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsGlyph(icon: icon, style: style),
                const SizedBox(width: AppMetrics.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: SettingsType.toolTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppMetrics.spaceXs),
                      Text(
                        caption,
                        style: SettingsType.toolCaption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: AppMetrics.spaceSm),
                        progress!,
                      ],
                      if (message != null) ...[
                        const SizedBox(height: AppMetrics.spaceXs),
                        Text(message!, style: SettingsType.sectionMeta),
                      ],
                    ],
                  ),
                ),
                if (busy && onCancel != null) ...[
                  const SizedBox(width: AppMetrics.spaceSm),
                  TextButton(
                    onPressed: onCancel,
                    child: Text(
                      'Cancel',
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: style.accent,
                      ),
                    ),
                  ),
                ] else if (busy) ...[
                  const SizedBox(width: AppMetrics.spaceSm),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: style.accent,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: AppMetrics.spaceSm),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: style.accent.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsHairline extends StatelessWidget {
  const SettingsHairline({this.style});

  final SettingsSectionStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = style == null
        ? AppColors.border
        : style!.accent.withValues(alpha: 0.35);
    return Container(height: 1, color: color);
  }
}

/// Thin accent progress bar shared by long-running maintenance tools.
class SettingsProgressBar extends StatelessWidget {
  const SettingsProgressBar({
    required this.fraction,
    required this.label,
    required this.style,
  });

  final double fraction;
  final String label;
  final SettingsSectionStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: AppColors.surfaceInset),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(color: style.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppMetrics.spaceXs),
        Text(label, style: SettingsType.sectionMeta),
      ],
    );
  }
}
