import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const backgroundDepth1 = Color(0xFF0E0E11);
  static const backgroundDepth2 = Color(0xFF15151A);
  static const backgroundDepth3 = Color(0xFF1E1E24);
  static const backgroundDepth4 = Color(0xFF2A2A31);
  static const backgroundDepth5 = Color(0xFF35353E);

  static const borderDepth1 = Color(0xFF2E2E36);
  static const borderDepth2 = Color(0xFF3C3C45);

  static const textBright = Color(0xFFF4F4F6);
  static const textBody = Color(0xFFD6D6DF);
  static const textSupport = Color(0xFFABABB5);
  static const textDim = Color(0xFF7F7F8A);

  static const accentPrimary = Color(0xFF2A9D8F);
  static const accentSecondary = Color(0xFFE9C46A);
  /// Housing chain, Housing category, and Trends “Spending” series.
  static const housing = Color(0xFFE76F51);
  static const success = Color(0xFF3FB37F);
  static const warning = Color(0xFFE9C46A);
  static const error = Color(0xFFE15A64);
}

class AppText {
  static const body = _BodyScale();
  static const headline = _HeadlineScale();

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSupport,
    height: 1.4,
  );

  static const navTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textBright,
  );

  /// Trends / chart tick labels — IBM Plex, brighter than muted UI captions.
  static TextStyle get chartAxis => GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textBody,
        height: 1.1,
        letterSpacing: 0.15,
      );
}

class _BodyScale {
  const _BodyScale();

  TextStyle get large => const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textBright,
    height: 1.35,
  );

  TextStyle get medium => const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textBody,
    height: 1.35,
  );

  TextStyle get small => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSupport,
    height: 1.35,
  );
}

class _HeadlineScale {
  const _HeadlineScale();

  TextStyle get large => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textBright,
    height: 1.2,
  );

  TextStyle get medium => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textBright,
    height: 1.25,
  );

  TextStyle get small => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textBright,
    height: 1.3,
  );
}

extension AppTextModifiers on TextStyle {
  TextStyle get bright => copyWith(color: AppColors.textBright);
  TextStyle get body => copyWith(color: AppColors.textBody);
  TextStyle get support => copyWith(color: AppColors.textSupport);
  TextStyle get accent => copyWith(color: AppColors.accentPrimary);
  TextStyle get error => copyWith(color: AppColors.error);
  TextStyle get success => copyWith(color: AppColors.success);
  TextStyle get warning => copyWith(color: AppColors.warning);
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class VSpace {
  static const xs = SizedBox(height: AppSpacing.xs);
  static const sm = SizedBox(height: AppSpacing.sm);
  static const md = SizedBox(height: AppSpacing.md);
  static const lg = SizedBox(height: AppSpacing.lg);
  static const xl = SizedBox(height: AppSpacing.xl);
  static const xxl = SizedBox(height: AppSpacing.xxl);
  static SizedBox of(double height) => SizedBox(height: height);
}

class HSpace {
  static const xs = SizedBox(width: AppSpacing.xs);
  static const sm = SizedBox(width: AppSpacing.sm);
  static const md = SizedBox(width: AppSpacing.md);
  static const lg = SizedBox(width: AppSpacing.lg);
  static const xl = SizedBox(width: AppSpacing.xl);
  static const xxl = SizedBox(width: AppSpacing.xxl);
  static SizedBox of(double width) => SizedBox(width: width);
}

class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
}

class AppComponents {
  static BoxDecoration get primaryCard => BoxDecoration(
    color: AppColors.backgroundDepth3,
    borderRadius: BorderRadius.circular(AppRadius.md),
    border: Border.all(color: AppColors.borderDepth1),
  );
}

CupertinoThemeData buildAppTheme() {
  return const CupertinoThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDepth1,
    barBackgroundColor: AppColors.backgroundDepth2,
    primaryColor: AppColors.accentPrimary,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(color: AppColors.textBright),
      actionTextStyle: TextStyle(
        inherit: false,
        color: AppColors.accentPrimary,
      ),
      navTitleTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textBright,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      navLargeTitleTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textBright,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      tabLabelTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textSupport,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
