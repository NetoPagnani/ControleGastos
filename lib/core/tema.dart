import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta escura e sofisticada, definida pelo usuario:
/// quase-preto, marrom escuro, rose empoeirado, azul-ardosia, taupe claro.
const corFundo = Color(0xFF0E0E10); // fundo geral
const corSuperficie = Color(0xFF29211A); // cards, appbar, campos
const corPrimaria = Color(0xFFA08889); // destaque: botoes, fab, progresso
const corSecundaria = Color(0xFF4E5E67); // acento secundario
const corTexto = Color(0xFFB4AAA8); // texto secundario sobre fundo escuro
const corTextoForte = Color(0xFFF3EEEC); // titulos e numeros grandes

// Alertas continuam vermelho/amarelo (e o significado universal de
// "atencao"), so que em tons escuros pra combinar com o resto.
const corAlerta = Color(0xFFE5484D);
const corAlertaFundo = Color(0xFF3A1E1F);
const corAviso = Color(0xFFE0A030);
const corAvisoFundo = Color(0xFF3A2E17);

/// Estilo para valores em dinheiro em destaque (tela de lancar, resumo do
/// Inicio). Algarismos tabulares: os numeros nao "dancam" de largura
/// conforme digita.
TextStyle estiloValorGrande({double tamanho = 40}) => GoogleFonts.plusJakartaSans(
      fontSize: tamanho,
      fontWeight: FontWeight.w800,
      color: corTextoForte,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData construirTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: corPrimaria,
    brightness: Brightness.dark,
  ).copyWith(
    primary: corPrimaria,
    onPrimary: corFundo,
    secondary: corSecundaria,
    onSecondary: corTextoForte,
    surface: corSuperficie,
    onSurface: corTextoForte,
    error: corAlerta,
  );

  final TextTheme tipografia = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).apply(
    bodyColor: corTexto,
    displayColor: corTextoForte,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: esquema,
    scaffoldBackgroundColor: corFundo,
    textTheme: tipografia,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: corFundo,
      surfaceTintColor: Colors.transparent,
      foregroundColor: corTextoForte,
      elevation: 0,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: corTextoForte,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: corSuperficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: corTexto.withValues(alpha: 0.12)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: corPrimaria,
        foregroundColor: corFundo,
        // So a altura minima: largura infinita quebra botao em linha e em dialogo.
        // Quem precisa ocupar a largura toda fica num SizedBox(width: double.infinity).
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: corTextoForte,
        // So a altura minima: largura infinita quebra botao em linha e em dialogo.
        // Quem precisa ocupar a largura toda fica num SizedBox(width: double.infinity).
        minimumSize: const Size(64, 50),
        side: BorderSide(color: corTexto.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: corPrimaria),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: corSuperficie,
      indicatorColor: corPrimaria.withValues(alpha: 0.22),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: corTextoForte),
      ),
      iconTheme: WidgetStateProperty.all(const IconThemeData(color: corTextoForte)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: corSuperficie,
      indicatorColor: corPrimaria.withValues(alpha: 0.22),
      selectedLabelTextStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: corTextoForte),
      unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(color: corTexto),
      selectedIconTheme: const IconThemeData(color: corTextoForte),
      unselectedIconTheme: IconThemeData(color: corTexto.withValues(alpha: 0.8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      labelStyle: TextStyle(color: corTexto),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: corTexto.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: corTexto.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: corPrimaria, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    dividerTheme: DividerThemeData(color: corTexto.withValues(alpha: 0.15), space: 1),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      iconColor: corTexto,
    ),
    iconTheme: const IconThemeData(color: corTexto),
  );
}
