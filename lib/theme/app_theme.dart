import 'package:flutter/cupertino.dart';

class AppColors {
  static const backgroundDepth1 = Color(0xFF0E0E11);
  static const backgroundDepth2 = Color(0xFF15151A);
  static const backgroundDepth3 = Color(0xFF1E1E24);
  static const backgroundDepth4 = Color(0xFF2A2A31);
  static const backgroundDepth5 = Color(0xFF35353E);

  static const borderDepth1 = Color(0xFF2E2E36);
  static const borderDepth2 = Color(0xFF3C3C45);

  static const textColor1 = Color(0xFFF4F4F6);
  static const textColor2 = Color(0xFFD6D6DF);
  static const textColor3 = Color(0xFFABABB5);
  static const textColor4 = Color(0xFF7F7F8A);

  static const accentPrimary = Color(0xFF2A9D8F);
  static const accentSecondary = Color(0xFFE9C46A);
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
    color: AppColors.textColor3,
    height: 1.4,
  );

  static const navTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textColor1,
  );
}

class _BodyScale {
  const _BodyScale();

  TextStyle get large => const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textColor1,
    height: 1.35,
  );

  TextStyle get medium => const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textColor2,
    height: 1.35,
  );

  TextStyle get small => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textColor3,
    height: 1.35,
  );
}

class _HeadlineScale {
  const _HeadlineScale();

  TextStyle get large => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textColor1,
    height: 1.2,
  );

  TextStyle get medium => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textColor1,
    height: 1.25,
  );

  TextStyle get small => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textColor1,
    height: 1.3,
  );
}

extension AppTextModifiers on TextStyle {
  TextStyle get primary => copyWith(color: AppColors.textColor1);
  TextStyle get secondary => copyWith(color: AppColors.textColor2);
  TextStyle get tertiary => copyWith(color: AppColors.textColor3);
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
      textStyle: TextStyle(color: AppColors.textColor1),
      actionTextStyle: TextStyle(
        inherit: false,
        color: AppColors.accentPrimary,
      ),
      navTitleTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textColor1,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      navLargeTitleTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textColor1,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      tabLabelTextStyle: TextStyle(
        inherit: false,
        color: AppColors.textColor3,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
