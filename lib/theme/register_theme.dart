import 'package:flutter/material.dart';

/// The household rendered as a civil register: ruled fields, stamped values,
/// one ink per member. Colour is data here — nothing is tinted for decoration.
class RegisterInk {
  /// Ground: the pale security tint a Kartu Keluarga is printed on.
  static const tint = Color(0xFFEAF2EC);

  /// The field colour that carries whole regions.
  static const green = Color(0xFF0E5C4A);

  /// Reserved for cancelled entries and overdue turns. Never decorative.
  static const red = Color(0xFFD62828);

  /// Reserved for whose turn it is now.
  static const gold = Color(0xFFE8B004);

  static const paper = Color(0xFFF7FBF7);
  static const ink = Color(0xFF0F1A17);
  static const rule = Color(0xFF9BB3A7);

  static const darkGround = Color(0xFF0B1512);
  static const darkField = Color(0xFF12241E);
  static const darkInk = Color(0xFFE4EFE7);
  static const darkRule = Color(0xFF34534A);

  /// One ink per member, like three officials' pens on the same page. Keyed by
  /// the Firestore profile id.
  static const memberInks = <String, Color>{
    'bunda': Color(0xFF7B2D8E),
    'aku': Color(0xFF1050A0),
    'adek': Color(0xFFC25E00),
  };

  static const memberInksDark = <String, Color>{
    'bunda': Color(0xFFD79AE6),
    'aku': Color(0xFF8FBDF5),
    'adek': Color(0xFFF0A961),
  };

  static Color forMember(BuildContext context, String profileId) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final table = dark ? memberInksDark : memberInks;
    return table[profileId] ?? (dark ? darkInk : ink);
  }
}

/// Field labels are set the way a form prints them: small, tracked, upper case.
/// Values keep tabular figures so times and dates line up down a column.
class RegisterType {
  /// Named explicitly: styles handed straight to a component theme are used
  /// as-is rather than merged onto the text theme, so they carry no family of
  /// their own unless one is written here.
  static const family = 'Roboto';

  static const label = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w700,
  );

  static const value = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const valueStrong = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const annotation = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const serial = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1,
    letterSpacing: 0.6,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Hairline rules and square corners carry the structure, so every surface
/// sits at elevation zero and nothing is rounded.
ThemeData buildRegisterTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  final ground = dark ? RegisterInk.darkGround : RegisterInk.tint;
  final surface = dark ? RegisterInk.darkField : RegisterInk.paper;
  final onSurface = dark ? RegisterInk.darkInk : RegisterInk.ink;
  final outline = dark ? RegisterInk.darkRule : RegisterInk.rule;
  final primary = dark ? const Color(0xFF62C6A8) : RegisterInk.green;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: dark ? RegisterInk.darkGround : Colors.white,
    primaryContainer: dark ? const Color(0xFF17342B) : const Color(0xFFCFE3D8),
    onPrimaryContainer: dark ? RegisterInk.darkInk : RegisterInk.green,
    secondary: RegisterInk.gold,
    onSecondary: RegisterInk.ink,
    secondaryContainer: dark ? const Color(0xFF3B2F09) : const Color(0xFFF7E4AE),
    onSecondaryContainer: dark ? const Color(0xFFF7E4AE) : RegisterInk.ink,
    error: dark ? const Color(0xFFFF8A80) : RegisterInk.red,
    onError: dark ? RegisterInk.darkGround : Colors.white,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerLowest: ground,
    surfaceContainerLow: ground,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: surface,
    onSurfaceVariant: dark ? const Color(0xFFA9C4B7) : const Color(0xFF41564C),
    outline: outline,
    outlineVariant: outline,
  );

  const square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);

  return ThemeData(
    useMaterial3: true,
    fontFamily: RegisterType.family,
    colorScheme: scheme,
    scaffoldBackgroundColor: ground,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: RegisterType.family,
        color: scheme.onPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.secondary,
      elevation: 0,
      height: 68,
      indicatorShape: square,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => RegisterType.label.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? RegisterInk.ink
              : scheme.onSurfaceVariant,
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
      shape: square,
      extendedTextStyle: RegisterType.label,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: square,
        elevation: 0,
        textStyle: RegisterType.label,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: square, textStyle: RegisterType.label),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: square,
        side: BorderSide(color: outline),
        textStyle: RegisterType.label,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: outline),
      ),
      titleTextStyle: RegisterType.label.copyWith(color: onSurface, fontSize: 13),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      elevation: 0,
      shape: square,
      showDragHandle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? RegisterInk.darkField : RegisterInk.ink,
      contentTextStyle: RegisterType.annotation.copyWith(
        color: dark ? RegisterInk.darkInk : RegisterInk.paper,
      ),
      shape: square,
      behavior: SnackBarBehavior.fixed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? RegisterInk.darkGround : RegisterInk.tint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      labelStyle: RegisterType.label.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: RegisterType.label.copyWith(color: scheme.primary),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      side: BorderSide(color: outline, width: 2),
    ),
    listTileTheme: ListTileThemeData(
      shape: square,
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: RegisterType.value.copyWith(color: onSurface),
      subtitleTextStyle: RegisterType.annotation.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: RegisterType.label,
      unselectedLabelStyle: RegisterType.label,
      labelColor: scheme.onPrimary,
      unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.7),
      indicatorColor: RegisterInk.gold,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: RegisterInk.gold.withValues(alpha: 0.4),
      selectionHandleColor: scheme.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearMinHeight: 2,
    ),
  );
}
