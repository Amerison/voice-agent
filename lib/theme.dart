import 'package:flutter/material.dart';

abstract final class HubColors {
  static bool _darkMode = true;

  static void useDarkMode(bool value) => _darkMode = value;

  static Color get background =>
      _darkMode ? const Color(0xFF141414) : const Color(0xFFF9F7F5);
  static Color get surface =>
      _darkMode ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);
  static Color get surfaceRaised =>
      _darkMode ? const Color(0xFF292929) : const Color(0xFFF2EFEC);
  static Color get border =>
      _darkMode ? const Color(0xFF333333) : const Color(0xFFE2DEDA);
  static Color get tabBar =>
      _darkMode ? const Color(0xFF0A0A0A) : const Color(0xFFF1EFED);
  static Color get text =>
      _darkMode ? const Color(0xFFE6E6E6) : const Color(0xFF171717);
  static Color get textMuted =>
      _darkMode ? const Color(0xFFA6A6A6) : const Color(0xFF66625F);
  static Color get textSubtle =>
      _darkMode ? const Color(0xFF8A8A8A) : const Color(0xFF817C78);

  static const orange = Color(0xFFEB5729);
  static const magenta = Color(0xFF992066);
  static const success = Color(0xFF00BDA5);
  static const danger = Color(0xFFF2545B);
  static const breeze = LinearGradient(
    colors: [magenta, Color(0xFFC23F51), orange],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

abstract final class HubFonts {
  static const sans = 'Avenir Next';
  static const serif = 'Georgia';
  static const mono = 'Menlo';
}

ThemeData buildHubTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? const Color(0xFF141414) : const Color(0xFFF9F7F5);
  final surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
  final surfaceRaised = isDark
      ? const Color(0xFF292929)
      : const Color(0xFFF2EFEC);
  final border = isDark ? const Color(0xFF333333) : const Color(0xFFE2DEDA);
  final tabBar = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1EFED);
  final text = isDark ? const Color(0xFFE6E6E6) : const Color(0xFF171717);
  final textMuted = isDark ? const Color(0xFFA6A6A6) : const Color(0xFF66625F);
  final textSubtle = isDark ? const Color(0xFF8A8A8A) : const Color(0xFF817C78);
  final selectedContainer = isDark
      ? const Color(0xFF3A2119)
      : const Color(0xFFFFE1D7);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: HubColors.orange,
        brightness: brightness,
        surface: background,
      ).copyWith(
        primary: HubColors.orange,
        onPrimary: Colors.white,
        primaryContainer: selectedContainer,
        secondary: HubColors.orange,
        onSecondary: Colors.white,
        tertiaryContainer: surfaceRaised,
        onTertiaryContainer: text,
        error: HubColors.danger,
        surface: background,
        onSurface: text,
        onSurfaceVariant: textMuted,
        surfaceContainerLowest: background,
        surfaceContainerLow: surface,
        surfaceContainer: surface,
        surfaceContainerHigh: surfaceRaised,
        surfaceContainerHighest: surfaceRaised,
        outline: border,
        outlineVariant: border,
      );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    fontFamily: HubFonts.sans,
    dividerColor: border,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displaySmall: const TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 34,
        height: 1.15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.6,
      ),
      headlineMedium: const TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.4,
      ),
      headlineSmall: const TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(
        fontFamily: HubFonts.mono,
        fontSize: 12,
        letterSpacing: 0.2,
        color: textMuted,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
    ).apply(bodyColor: text, displayColor: text),
    iconTheme: IconThemeData(color: text, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 20,
        color: text,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      labelStyle: TextStyle(color: textMuted),
      hintStyle: TextStyle(color: textSubtle),
      helperStyle: TextStyle(color: textSubtle),
      floatingLabelStyle: TextStyle(color: text),
      prefixIconColor: textMuted,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: HubColors.orange, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HubColors.orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: surfaceRaised,
        disabledForegroundColor: textSubtle,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: HubFonts.sans,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        disabledForegroundColor: textSubtle,
        side: BorderSide(color: textMuted),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontFamily: HubFonts.sans,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: text,
        textStyle: const TextStyle(fontFamily: HubFonts.sans, fontSize: 16),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: textMuted,
        selectedBackgroundColor: selectedContainer,
        selectedForegroundColor: text,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? HubColors.orange
            : surfaceRaised,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tabBar,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? text : textSubtle,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: HubFonts.sans,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? text : textSubtle,
        ),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: surface,
      scrimColor: const Color(0xB3000000),
      width: 330,
      shape: const RoundedRectangleBorder(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 22,
        color: text,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceRaised,
      contentTextStyle: TextStyle(fontFamily: HubFonts.sans, color: text),
      behavior: SnackBarBehavior.floating,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: text,
      unselectedLabelColor: textSubtle,
      indicatorColor: text,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: border,
      labelStyle: const TextStyle(
        fontFamily: HubFonts.sans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: HubFonts.sans,
        fontSize: 16,
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: HubColors.orange,
      linearTrackColor: surface,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: HubColors.orange,
      selectionHandleColor: HubColors.orange,
    ),
  );
}
