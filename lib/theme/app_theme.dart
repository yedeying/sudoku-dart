import 'package:flutter/material.dart';

import 'board_palette.dart';

/// 全局主题：由单一种子色派生 Material 3 配色，并统一圆角、留白与控件层级。
///
/// 界面代码只允许引用 [ColorScheme] 与 [TextTheme] 中的令牌，
/// 不再硬编码具体色值，深色模式才能跟随系统正确反色。
class AppTheme {
  static const Color seed = Color(0xFF1A1A1A);

  /// 低饱和深蓝强调色：只用于选中、激活等状态，
  /// 饱和度刻意压低，避免和标记调色板（金/绿/蓝/红）抢注意力。
  static const Color accent = Color(0xFF35507A);
  static const Color accentDark = Color(0xFFA8BEDE);

  /// 随包内置的中文子集字体，避免 Web 首帧方块字。
  static const String fontFamily = 'AppSans';

  /// 棋盘、卡片等容器统一圆角。
  static const double radius = 18;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // fromSeed remaps near-black to teal/cyan containers; build neutrals explicitly.
    final scheme = _neutralScheme(brightness);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: const ['Noto Sans SC', 'PingFang SC', 'sans-serif'],
    );
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: [
        brightness == Brightness.light
            ? BoardPalette.lightPalette
            : BoardPalette.darkPalette,
      ],
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        scrolledUnderElevation: 2,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: text.labelLarge,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  /// Grayscale Material 3 scheme so chrome cannot pick up seed-derived teal/cyan.
  static ColorScheme _neutralScheme(Brightness brightness) {
    final light = brightness == Brightness.light;
    final onSurface = light ? seed : const Color(0xFFF5F5F5);
    final surface = light ? const Color(0xFFFAFAFA) : const Color(0xFF141414);
    final surfaceLow = light ? const Color(0xFFF1F1F1) : const Color(0xFF242424);
    final surfaceMid = light ? const Color(0xFFE7E7E7) : const Color(0xFF2E2E2E);
    final surfaceHigh = light ? const Color(0xFFDCDCDC) : const Color(0xFF383838);
    final surfaceHighest =
        light ? const Color(0xFFCFCFCF) : const Color(0xFF454545);
    final outline = light ? const Color(0xFF8A8A8A) : const Color(0xFF8A8A8A);
    final outlineVariant =
        light ? const Color(0xFFC4C4C4) : const Color(0xFF5C5C5C);
    // 深色模式下强调色必须反相，否则深色按钮会消失在近黑的底色里。
    final primary = light ? accent : accentDark;
    final onPrimary = light ? Colors.white : const Color(0xFF16233A);
    final primaryContainer =
        light ? const Color(0xFFDCE4F1) : const Color(0xFF2C3D5A);
    final onPrimaryContainer =
        light ? const Color(0xFF16233A) : const Color(0xFFDCE4F1);

    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      // 次级/三级仍走灰度，保证只有“选中/激活”会出现强调色。
      secondary: onSurface,
      onSecondary: surface,
      secondaryContainer: surfaceHigh,
      onSecondaryContainer: onSurface,
      tertiary: onSurface,
      onTertiary: surface,
      tertiaryContainer: surfaceMid,
      onTertiaryContainer: onSurface,
      error: light ? const Color(0xFFB3261E) : const Color(0xFFF2B8B5),
      onError: light ? Colors.white : const Color(0xFF601410),
      errorContainer: light ? const Color(0xFFF9DEDC) : const Color(0xFF8C1D18),
      onErrorContainer: light ? const Color(0xFF410E0B) : const Color(0xFFF9DEDC),
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: light ? const Color(0xFF5C5C5C) : const Color(0xFFB0B0B0),
      surfaceContainerLowest: light ? Colors.white : const Color(0xFF0A0A0A),
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceMid,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: light ? const Color(0xFFCCCCCC) : const Color(0xFF555555),
      surfaceTint: Colors.transparent,
    );
  }
}
