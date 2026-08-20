import 'package:flutter/material.dart';

/// 全局主题：由单一种子色派生 Material 3 配色，并统一圆角、留白与控件层级。
///
/// 界面代码只允许引用 [ColorScheme] 与 [TextTheme] 中的令牌，
/// 不再硬编码具体色值，深色模式才能跟随系统正确反色。
class AppTheme {
  static const Color seed = Color(0xFF1A1A1A);

  /// 棋盘、卡片等容器统一圆角。
  static const double radius = 18;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // fromSeed remaps near-black to teal/cyan containers; build neutrals explicitly.
    final scheme = _neutralScheme(brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
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
        indicatorColor: scheme.secondaryContainer,
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
    const onPrimary = Colors.white;
    final onSurface = light ? seed : const Color(0xFFF5F5F5);
    final surface = light ? const Color(0xFFFAFAFA) : const Color(0xFF121212);
    final surfaceLow = light ? const Color(0xFFF2F2F2) : const Color(0xFF1C1C1C);
    final surfaceMid = light ? const Color(0xFFEBEBEB) : const Color(0xFF242424);
    final surfaceHigh = light ? const Color(0xFFE3E3E3) : const Color(0xFF2C2C2C);
    final surfaceHighest =
        light ? const Color(0xFFD9D9D9) : const Color(0xFF363636);
    final outline = light ? const Color(0xFFB0B0B0) : const Color(0xFF6E6E6E);
    final outlineVariant =
        light ? const Color(0xFFD6D6D6) : const Color(0xFF4A4A4A);

    return ColorScheme(
      brightness: brightness,
      primary: seed,
      onPrimary: onPrimary,
      primaryContainer: surfaceHighest,
      onPrimaryContainer: onSurface,
      secondary: seed,
      onSecondary: onPrimary,
      secondaryContainer: surfaceHigh,
      onSecondaryContainer: onSurface,
      tertiary: seed,
      onTertiary: onPrimary,
      tertiaryContainer: surfaceMid,
      onTertiaryContainer: onSurface,
      error: const Color(0xFFB3261E),
      onError: onPrimary,
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
