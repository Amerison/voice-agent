import 'package:flutter/material.dart';

abstract final class HubColors {
  static const background = Color(0xFF141414);
  static const surface = Color(0xFF1F1F1F);
  static const surfaceRaised = Color(0xFF292929);
  static const border = Color(0xFF333333);
  static const tabBar = Color(0xFF0A0A0A);
  static const text = Color(0xFFE6E6E6);
  static const textMuted = Color(0xFFA6A6A6);
  static const textSubtle = Color(0xFF8A8A8A);
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

ThemeData buildHubTheme() {
  const scheme = ColorScheme.dark(
    primary: HubColors.orange,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF3A2119),
    onPrimaryContainer: Color(0xFFFFB59E),
    secondary: HubColors.orange,
    onSecondary: Colors.white,
    tertiaryContainer: HubColors.surfaceRaised,
    onTertiaryContainer: HubColors.text,
    error: HubColors.danger,
    errorContainer: Color(0xFF3A1D1F),
    onErrorContainer: Color(0xFFFFB4B7),
    surface: HubColors.background,
    onSurface: HubColors.text,
    onSurfaceVariant: HubColors.textMuted,
    surfaceContainerLowest: HubColors.background,
    surfaceContainerLow: HubColors.surface,
    surfaceContainer: HubColors.surface,
    surfaceContainerHigh: HubColors.surfaceRaised,
    surfaceContainerHighest: HubColors.surfaceRaised,
    outline: HubColors.border,
    outlineVariant: HubColors.border,
  );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: HubColors.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: HubColors.background,
    fontFamily: HubFonts.sans,
    dividerColor: HubColors.border,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 34,
        height: 1.15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.4,
      ),
      headlineSmall: TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(
        fontFamily: HubFonts.mono,
        fontSize: 12,
        letterSpacing: 0.2,
        color: HubColors.textMuted,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
    ).apply(bodyColor: HubColors.text, displayColor: HubColors.text),
    iconTheme: const IconThemeData(color: HubColors.text, size: 22),
    appBarTheme: const AppBarTheme(
      backgroundColor: HubColors.background,
      foregroundColor: HubColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 20,
        color: HubColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: HubColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HubColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HubColors.surface,
      labelStyle: const TextStyle(color: HubColors.textMuted),
      hintStyle: const TextStyle(color: HubColors.textSubtle),
      helperStyle: const TextStyle(color: HubColors.textSubtle),
      floatingLabelStyle: const TextStyle(color: HubColors.text),
      prefixIconColor: HubColors.textMuted,
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
        disabledBackgroundColor: HubColors.surfaceRaised,
        disabledForegroundColor: HubColors.textSubtle,
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
        foregroundColor: HubColors.text,
        disabledForegroundColor: HubColors.textSubtle,
        side: const BorderSide(color: HubColors.textMuted),
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
        foregroundColor: HubColors.text,
        textStyle: const TextStyle(fontFamily: HubFonts.sans, fontSize: 16),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: HubColors.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: HubColors.surface,
        foregroundColor: HubColors.textMuted,
        selectedBackgroundColor: const Color(0xFF3A2119),
        selectedForegroundColor: HubColors.text,
        side: const BorderSide(color: HubColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? HubColors.orange
            : HubColors.surfaceRaised,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: HubColors.tabBar,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? HubColors.text
              : HubColors.textSubtle,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: HubFonts.sans,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? HubColors.text
              : HubColors.textSubtle,
        ),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: HubColors.surface,
      scrimColor: Color(0xB3000000),
      width: 330,
      shape: RoundedRectangleBorder(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: HubColors.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: HubColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        fontFamily: HubFonts.serif,
        fontSize: 22,
        color: HubColors.text,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: HubColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HubColors.border),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: HubColors.surfaceRaised,
      contentTextStyle: TextStyle(
        fontFamily: HubFonts.sans,
        color: HubColors.text,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: HubColors.text,
      unselectedLabelColor: HubColors.textSubtle,
      indicatorColor: HubColors.text,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: HubColors.border,
      labelStyle: TextStyle(
        fontFamily: HubFonts.sans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(fontFamily: HubFonts.sans, fontSize: 16),
    ),
    dividerTheme: const DividerThemeData(
      color: HubColors.border,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: HubColors.orange,
      linearTrackColor: HubColors.surface,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: HubColors.orange,
      selectionHandleColor: HubColors.orange,
    ),
  );
}
