import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ScanVault premium visual theme.
/// Privacy-first, offline, warm minimalism.
abstract final class ScanVaultTheme {
  // Brand Colors
  static const Color cream = Color(0xFFFAF6ED);
  static const Color darkTeal = Color(0xFF1A3A3A);
  static const Color teal = Color(0xFF2DD4BF);
  static const Color gold = Color(0xFFD4A843);

  // Neutral Colors
  static const Color warmGray = Color(0xFF7A7060);
  static const Color lightGray = Color(0xFFA89878);
  static const Color paperWhite = Color(0xFFFFFFFF);
  static const Color foldTan = Color(0xFFD4C8B0);
  
  // Semantic
  static const Color success = Color(0xFF0D9488);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2DD4BF);

  static ThemeData light() => _buildTheme();
  static ThemeData dark() => _buildDarkTheme();

  static ThemeData _buildTheme() {
    final colorScheme = const ColorScheme.light(
      primary: darkTeal,
      onPrimary: cream,
      secondary: teal,
      onSecondary: darkTeal,
      error: error,
      onError: paperWhite,
      surface: paperWhite,
      onSurface: darkTeal,
      onSurfaceVariant: warmGray,
      outline: foldTan,
    );

    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.5, color: darkTeal),
      displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: 0, color: darkTeal),
      titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: 0, color: darkTeal),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0, color: darkTeal),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, letterSpacing: 0, color: darkTeal),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, letterSpacing: 0, color: warmGray),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0, color: darkTeal),
      labelSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0.5, color: lightGray),
      bodySmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0, color: lightGray), // Caption
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cream,
      canvasColor: cream,
      dividerColor: foldTan,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: textTheme,
      
      appBarTheme: AppBarTheme(
        backgroundColor: cream,
        foregroundColor: darkTeal,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: darkTeal, size: 24),
        titleTextStyle: textTheme.displayMedium,
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        color: paperWhite,
        margin: EdgeInsets.zero,
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkTeal,
        foregroundColor: cream,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        iconSize: 24,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkTeal,
          foregroundColor: cream,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: warmGray,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTeal,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: darkTeal, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkTeal,
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48),
          iconSize: 24,
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkTeal.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyLarge?.copyWith(color: lightGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
      ),
      
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paperWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      dialogTheme: DialogThemeData(
        backgroundColor: paperWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: foldTan,
        thickness: 1,
        space: 1,
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkTeal,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: cream),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final colors = ScanVaultColors(true);
    final colorScheme = ColorScheme.dark(
      primary: colors.accentTeal,
      onPrimary: colors.bgBase,
      secondary: colors.accentGold,
      onSecondary: colors.bgBase,
      error: const Color(0xFFEF4444),
      onError: colors.bgBase,
      surface: colors.bgSurface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.bgElevated,
      outline: colors.glassBorder,
    );

    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.5, color: colors.textPrimary),
      displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: 0, color: colors.textPrimary),
      titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: 0, color: colors.textPrimary),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0, color: colors.textPrimary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, letterSpacing: 0, color: colors.textPrimary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, letterSpacing: 0, color: colors.textSecondary),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0, color: colors.textPrimary),
      labelSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0.5, color: colors.textTertiary),
      bodySmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0, color: colors.textTertiary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bgBase,
      canvasColor: colors.bgBase,
      dividerColor: colors.glassBorder,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: textTheme,
      
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bgElevated,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: colors.textPrimary, size: 24),
        titleTextStyle: textTheme.displayMedium,
      ),
      
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.glassBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        color: colors.bgSurface,
        margin: EdgeInsets.zero,
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accentTeal,
        foregroundColor: colors.bgBase,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        iconSize: 24,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accentTeal,
          foregroundColor: colors.bgBase,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textTertiary,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          side: BorderSide(color: colors.textPrimary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48),
          iconSize: 24,
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.bgElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyLarge?.copyWith(color: colors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.glassBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.glassBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.accentTeal, width: 1.5),
        ),
      ),
      
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.bgSurface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      dialogTheme: DialogThemeData(
        backgroundColor: colors.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      
      dividerTheme: DividerThemeData(
        color: colors.glassBorder,
        thickness: 1,
        space: 1,
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.bgElevated,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class ScanVaultColors {
  final bool isDark;

  ScanVaultColors(this.isDark);

  Color get bgBase => isDark ? const Color(0xFF0A0F0F) : const Color(0xFFFAF6ED);
  Color get bgSurface => isDark ? const Color(0xFF141E1E) : const Color(0xFFFFFFFF);
  Color get bgElevated => isDark ? const Color(0xFF1A2A2A) : const Color(0xFFF5F0E6);
  Color get textPrimary => isDark ? const Color(0xFFE8E2D6) : const Color(0xFF1A3A3A);
  Color get textSecondary => isDark ? const Color(0xFF8A8A7A) : const Color(0xFF7A7060);
  Color get textTertiary => isDark ? const Color(0xFF6B7A7A) : const Color(0xFFA89878);
  Color get accentTeal => isDark ? const Color(0xFF00E5FF) : const Color(0xFF2DD4BF);
  Color get accentGold => isDark ? const Color(0xFFF5D485) : const Color(0xFFD4A843);
  Color get glassBorder => isDark ? const Color(0x1400E5FF) : const Color(0x141A3A3A);
  Color get glassBg => isDark ? const Color(0xB3141E1E) : const Color(0x0D1A3A3A);
}
