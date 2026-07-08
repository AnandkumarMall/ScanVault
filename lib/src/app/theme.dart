import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ScanVault premium visual theme.
/// Professional, Dependable, Fast, Private, and Quiet.
abstract final class ScanVaultTheme {
  // Shared Colors
  static const Color _primaryAccent = Color(0xFF4F46E5); // Indigo 600
  static const Color _success = Color(0xFF10B981); // Emerald 500
  static const Color _warning = Color(0xFFF59E0B); // Amber 500
  static const Color _danger = Color(0xFFEF4444); // Red 500

  // Dark Mode Colors
  static const Color _darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color _darkCanvas = Color(0xFF020617); // Slate 950
  static const Color _darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color _darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color _darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color _darkBorder = Color(0xFF334155); // Slate 700

  // Light Mode Colors
  static const Color _lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color _lightSurface = Color(0xFFFFFFFF); // Pure White
  static const Color _lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color _lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color _lightBorder = Color(0xFFE2E8F0); // Slate 200

  static ThemeData light() => _buildTheme(Brightness.light);
  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark ? _darkBackground : _lightBackground;
    final surface = isDark ? _darkSurface : _lightSurface;
    final textPrimary = isDark ? _darkTextPrimary : _lightTextPrimary;
    final textSecondary = isDark ? _darkTextSecondary : _lightTextSecondary;
    final border = isDark ? _darkBorder : _lightBorder;
    final canvas = isDark ? _darkCanvas : _lightBackground;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: _primaryAccent,
      onPrimary: Colors.white,
      secondary: _primaryAccent,
      onSecondary: Colors.white,
      error: _danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border.withValues(alpha: 0.5),
    );

    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0,
        color: textPrimary,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.1,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.plusJakartaSans( // Button text
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.0,
        letterSpacing: 0.2,
      ),
      bodySmall: GoogleFonts.plusJakartaSans( // Caption
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
        letterSpacing: 0.2,
        color: textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: canvas, // For crop/editor backgrounds
      dividerColor: border,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: textTheme,
      
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: textPrimary, size: 24),
        titleTextStyle: textTheme.headlineLarge,
      ),
      
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1, // Level 1 elevation
        shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        color: surface,
        margin: EdgeInsets.zero,
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryAccent,
        foregroundColor: Colors.white,
        elevation: isDark ? 0 : 2, // Level 2 elevation
        focusElevation: isDark ? 0 : 2,
        hoverElevation: isDark ? 0 : 2,
        highlightElevation: isDark ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28), // 56/2 for circle
        ),
        iconSize: 24,
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryAccent,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48), // 48dp touch target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryAccent,
          textStyle: textTheme.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(64, 48), // 48dp touch target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: textTheme.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48), // 48dp touch target
          side: BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48), // 48dp minimum target
          iconSize: 24,
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyLarge?.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryAccent, width: 1.5),
        ),
      ),
      
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: isDark ? 0 : 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: isDark ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: textPrimary),
        elevation: isDark ? 0 : 2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        labelStyle: textTheme.labelLarge?.copyWith(color: textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}
