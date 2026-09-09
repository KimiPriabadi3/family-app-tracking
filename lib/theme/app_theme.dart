import 'package:flutter/material.dart';

/// A warm, bright palette meant to feel like a home rather than an office.
/// Coral leads, sunny yellow marks whose turn it is, teal calms the rest.
class AppColors {
  static const coral = Color(0xFFFF7F5C);
  static const coralDeep = Color(0xFFE85D3A);
  static const sun = Color(0xFFFFC44D);
  static const teal = Color(0xFF3FBFAE);
  static const rose = Color(0xFFE8618C);

  static const ground = Color(0xFFFFF8F4);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF3B2E2A);
  static const inkSoft = Color(0xFF8A7A73);
  static const line = Color(0xFFF0E2D9);

  static const darkGround = Color(0xFF221B19);
  static const darkCard = Color(0xFF2E2523);
  static const darkInk = Color(0xFFF5EAE5);
  static const darkInkSoft = Color(0xFFB9A79F);
  static const darkLine = Color(0xFF433733);

  /// One colour per member, used for their avatar and anything they wrote.
  static const members = <String, Color>{
    'bunda': rose,
    'aku': Color(0xFF4A9DEC),
    'adek': Color(0xFFF2A03D),
  };

  static const membersDark = <String, Color>{
    'bunda': Color(0xFFFF92B4),
    'aku': Color(0xFF8CC3F7),
    'adek': Color(0xFFFFC178),
  };

  static Color forMember(BuildContext context, String profileId) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final table = dark ? membersDark : members;
    return table[profileId] ?? (dark ? darkInkSoft : inkSoft);
  }
}

class AppRadius {
  static const card = 22.0;
  static const chip = 14.0;
  static const button = 18.0;
}

/// Soft shadows with a real offset and blur — never a flat coloured halo.
List<BoxShadow> softShadow(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark) return const [];
  return const [
    BoxShadow(
      color: Color(0x12A05A3C),
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
  ];
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  final ground = dark ? AppColors.darkGround : AppColors.ground;
  final surface = dark ? AppColors.darkCard : AppColors.card;
  final onSurface = dark ? AppColors.darkInk : AppColors.ink;
  final onSurfaceSoft = dark ? AppColors.darkInkSoft : AppColors.inkSoft;
  final outline = dark ? AppColors.darkLine : AppColors.line;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFFFF9B7C) : AppColors.coral,
    onPrimary: dark ? const Color(0xFF3A1A10) : Colors.white,
    primaryContainer: dark ? const Color(0xFF4A2318) : const Color(0xFFFFE3D9),
    onPrimaryContainer: dark ? const Color(0xFFFFD9CB) : AppColors.coralDeep,
    secondary: AppColors.sun,
    onSecondary: AppColors.ink,
    secondaryContainer: dark ? const Color(0xFF463519) : const Color(0xFFFFEFC9),
    onSecondaryContainer: dark ? const Color(0xFFFFE2A6) : AppColors.ink,
    tertiary: AppColors.teal,
    onTertiary: Colors.white,
    error: dark ? const Color(0xFFFF9A8F) : const Color(0xFFD9534F),
    onError: dark ? const Color(0xFF3A1512) : Colors.white,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerLowest: ground,
    surfaceContainerLow: ground,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: surface,
    onSurfaceVariant: onSurfaceSoft,
    outline: outline,
    outlineVariant: outline,
  );

  RoundedRectangleBorder rounded(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: ground,
    appBarTheme: AppBarTheme(
      backgroundColor: ground,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: dark ? const Color(0xFF4A2318) : const Color(0xFFFFE3D9),
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : onSurfaceSoft,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : onSurfaceSoft,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: rounded(AppRadius.button),
      extendedTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded(AppRadius.button),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: rounded(AppRadius.chip),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded(AppRadius.button),
        side: BorderSide(color: outline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      elevation: 0,
      shape: rounded(AppRadius.card),
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onSurface,
      contentTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: dark ? AppColors.darkGround : Colors.white,
      ),
      shape: rounded(AppRadius.chip),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      labelStyle: TextStyle(fontFamily: 'Roboto', color: onSurfaceSoft),
      floatingLabelStyle: TextStyle(fontFamily: 'Roboto', color: scheme.primary),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: rounded(7),
      side: BorderSide(color: outline, width: 2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : onSurfaceSoft),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? scheme.primary : outline),
    ),
    listTileTheme: ListTileThemeData(
      shape: rounded(AppRadius.chip),
      iconColor: onSurfaceSoft,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: onSurfaceSoft,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: AppColors.sun.withValues(alpha: 0.45),
      selectionHandleColor: scheme.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}
