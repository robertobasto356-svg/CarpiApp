import 'ui.dart';

/// Colores tomados de los mockups nuevos del Figma.
/// Carpintero: terracota sobre crema. Cliente: verde sobre blanco hueso.
class Paleta {
  final Color primario;
  final Color primarioSuave;
  final Color fondo;
  final Color superficieAlterna;
  final Color texto;
  final Color textoSuave;
  final Color borde;

  const Paleta({
    required this.primario,
    required this.primarioSuave,
    required this.fondo,
    required this.superficieAlterna,
    required this.texto,
    required this.textoSuave,
    required this.borde,
  });
}

const paletaCarpintero = Paleta(
  primario: Color(0xFFA8461D),
  primarioSuave: Color(0xFFF2DFCF),
  fondo: Color(0xFFFFFAF4),
  superficieAlterna: Color(0xFFF4EEE8),
  texto: Color(0xFF2B211C),
  textoSuave: Color(0xFF8A7D73),
  borde: Color(0xFFEDE3DA),
);

const paletaCliente = Paleta(
  primario: Color(0xFF176C4D),
  primarioSuave: Color(0xFFE3F0EA),
  fondo: Color(0xFFF8F8F6),
  superficieAlterna: Color(0xFFEFF1EF),
  texto: Color(0xFF272B29),
  textoSuave: Color(0xFF79807C),
  borde: Color(0xFFE2E6E3),
);

/// Colores de apoyo comunes.
class Colores {
  static const ia = Color(0xFFE7F2E9);
  static const iaTexto = Color(0xFF1F5A3F);
  static const aviso = Color(0xFFFFF4CC);
  static const avisoTexto = Color(0xFF6B5518);
  static const error = Color(0xFFD22B2B);
  static const exito = Color(0xFF2E7D4F);
  static const madera = Color(0xFF5A3825);
  static const resumen = Color(0xFFF4E8DC);
}

ThemeData construirTema(Paleta p) {
  final esquema = ColorScheme.fromSeed(
    seedColor: p.primario,
    brightness: Brightness.light,
  ).copyWith(
    primary: p.primario,
    onPrimary: Colors.white,
    primaryContainer: p.primarioSuave,
    onPrimaryContainer: p.primario,
    secondary: p.primario,
    surface: Colors.white,
    onSurface: p.texto,
    onSurfaceVariant: p.textoSuave,
    surfaceContainerHighest: p.superficieAlterna,
    surfaceContainerHigh: p.superficieAlterna,
    surfaceContainer: p.superficieAlterna,
    surfaceContainerLow: p.fondo,
    outline: p.borde,
    outlineVariant: p.borde,
    error: Colores.error,
  );

  final redondeo = BorderRadius.circular(14);
  OutlineInputBorder borde(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: p.fondo,
    appBarTheme: AppBarTheme(
      backgroundColor: p.fondo,
      foregroundColor: p.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: p.texto,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: Typography.blackMountainView.apply(
      bodyColor: p.texto,
      displayColor: p.texto,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: p.textoSuave, fontSize: 14),
      border: borde(p.borde),
      enabledBorder: borde(p.borde),
      focusedBorder: borde(p.primario, 1.6),
      errorBorder: borde(Colores.error),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: redondeo),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: p.texto,
        side: BorderSide(color: p.borde),
        shape: RoundedRectangleBorder(borderRadius: redondeo),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.primario),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.borde),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.superficieAlterna,
      selectedColor: p.primario,
      labelStyle: TextStyle(color: p.texto, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: p.primarioSuave,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight:
              s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.primario : p.textoSuave,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? p.primario : p.textoSuave,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.borde, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.texto,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primario,
      linearTrackColor: p.superficieAlterna,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.primario,
      thumbColor: p.primario,
      inactiveTrackColor: p.superficieAlterna,
    ),
  );
}
