import 'package:budgets/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

/// Per-section accent used for icons, links, and hairlines.
class SettingsSectionStyle {
  const SettingsSectionStyle({required this.accent});

  final Color accent;

  /// Banks — teal (money / SimpleFIN).
  static const banks = SettingsSectionStyle(accent: AppColors.accentPrimary);

  /// Sync — cool indigo.
  static const sync = SettingsSectionStyle(accent: Color(0xFF7B8CDE));

  /// Maintenance — muted clay (not bright yellow).
  static const maintenance = SettingsSectionStyle(accent: Color(0xFF9A7B6A));
}

/// Emphatic type roles for Settings (stronger than global AppText defaults).
class SettingsType {
  SettingsType._();

  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textBright,
    height: 1.15,
    letterSpacing: -0.4,
  );

  static const sectionMeta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textDim,
    height: 1.35,
  );

  static const institution = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSupport,
    height: 1.2,
    letterSpacing: 0.9,
  );

  static const rowTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textBody,
    height: 1.3,
  );

  static const rowTitleEmphasis = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textBright,
    height: 1.3,
  );

  static const toolTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textBright,
    height: 1.25,
  );

  static const toolCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textDim,
    height: 1.35,
  );

  static const amount = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textBright,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const amountMuted = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textDim,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Bare accent icon — no chip background.
class SettingsGlyph extends StatelessWidget {
  const SettingsGlyph({
    super.key,
    required this.icon,
    required this.style,
    this.size = 22,
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
    super.key,
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
        HSpace.md,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SettingsType.sectionTitle),
              if (caption != null) ...[
                VSpace.xs,
                Text(caption!, style: SettingsType.sectionMeta),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-row maintenance control with a left-weighted accent gradient.
class SettingsToolRow extends StatelessWidget {
  const SettingsToolRow({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    required this.onAction,
    required this.style,
    this.busy = false,
    this.message,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onAction;
  final SettingsSectionStyle style;
  final bool busy;
  final String? message;
  final Widget? progress;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: busy ? null : onAction,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: busy ? 0.7 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: style.accent.withValues(alpha: 0.28),
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                style.accent.withValues(alpha: 0.22),
                style.accent.withValues(alpha: 0.08),
                AppColors.backgroundDepth2.withValues(alpha: 0.55),
                AppColors.backgroundDepth1.withValues(alpha: 0.2),
              ],
              stops: const [0.0, 0.22, 0.65, 1.0],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsGlyph(icon: icon, style: style),
              HSpace.md,
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
                    VSpace.xs,
                    Text(
                      caption,
                      style: SettingsType.toolCaption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (progress != null) ...[
                      VSpace.sm,
                      progress!,
                    ],
                    if (message != null) ...[
                      VSpace.xs,
                      Text(message!, style: SettingsType.sectionMeta),
                    ],
                  ],
                ),
              ),
              if (busy) ...[
                HSpace.sm,
                CupertinoActivityIndicator(
                  radius: 8,
                  color: style.accent,
                ),
              ] else ...[
                HSpace.sm,
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: style.accent.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsHairline extends StatelessWidget {
  const SettingsHairline({super.key, this.style});

  final SettingsSectionStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = style == null
        ? AppColors.borderDepth1
        : style!.accent.withValues(alpha: 0.35);
    return Container(height: 1, color: color);
  }
}

/// Thin accent progress bar shared by long-running maintenance tools.
class SettingsProgressBar extends StatelessWidget {
  const SettingsProgressBar({
    super.key,
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
                Container(color: AppColors.backgroundDepth5),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(color: style.accent),
                ),
              ],
            ),
          ),
        ),
        VSpace.xs,
        Text(label, style: SettingsType.sectionMeta),
      ],
    );
  }
}
