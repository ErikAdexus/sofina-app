import 'package:flutter/material.dart';

// Colores de marca (vinotinto), como ThemeExtension propia: no todos los
// roles que usa la app hoy (el "acento oscuro" y el "tinte suave" de
// fondos/estados seleccionados) mapean limpio a los slots estándar de
// ColorScheme, así que se exponen acá con nombre explícito en vez de
// forzarlos dentro de roles de Material que no significan lo mismo.
// Mismos valores y misma estructura que proyectocitas2 (Sofina Cliente),
// para que ambas apps compartan una sola identidad visual.
@immutable
class SofinaColors extends ThemeExtension<SofinaColors> {
  final Color primaryDark;
  final Color softTint;

  const SofinaColors({
    required this.primaryDark,
    required this.softTint,
  });

  static const light = SofinaColors(
    // Rebranding aprobado por Sofía: terracota (antes vinotinto 0xFF6E2323).
    primaryDark: Color(0xFFA32D2D),
    softTint: Color(0xFFF7E9E6),
  );

  static const dark = SofinaColors(
    primaryDark: Color(0xFFE39089),
    softTint: Color(0xFF3A2320),
  );

  @override
  SofinaColors copyWith({Color? primaryDark, Color? softTint}) {
    return SofinaColors(
      primaryDark: primaryDark ?? this.primaryDark,
      softTint: softTint ?? this.softTint,
    );
  }

  @override
  SofinaColors lerp(ThemeExtension<SofinaColors>? other, double t) {
    if (other is! SofinaColors) return this;
    return SofinaColors(
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      softTint: Color.lerp(softTint, other.softTint, t)!,
    );
  }
}

// Rojo de "peligro" (errores, cancelar, rechazado): separado a propósito
// del vinotinto de marca -- no cambia con este rebranding. Ya estaba así
// en el proyecto (Color(0xFFC62828) repetido en varios archivos); queda
// acá centralizado también para no perder esa separación semántica cuando
// se reemplacen los hex sueltos de marca.
const Color sofinaColorPeligro = Color(0xFFC62828);

ThemeData construirTemaClaro() {
  const colorScheme = ColorScheme.light(
    // Rebranding aprobado por Sofía: terracota (antes vinotinto 0xFF8A2E2E).
    primary: Color(0xFFB5442E),
    onPrimary: Colors.white,
    secondary: Color(0xFFB5442E),
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black87,
    error: sofinaColorPeligro,
    onError: Colors.white,
  );

  return _construirTema(
    colorScheme: colorScheme,
    sofinaColors: SofinaColors.light,
    scaffoldBackgroundColor: const Color(0xFFF8EDEE),
  );
}

ThemeData construirTemaOscuro() {
  const colorScheme = ColorScheme.dark(
    // onPrimary oscuro a propósito: #C9736B es un tono medio-claro, texto
    // blanco encima da ~3.4:1 de contraste (no llega a 4.5:1 AA para texto
    // normal). Con texto oscuro sube a ~6.2:1.
    primary: Color(0xFFC9736B),
    onPrimary: Color(0xFF2A1210),
    secondary: Color(0xFFC9736B),
    onSecondary: Color(0xFF2A1210),
    surface: Color(0xFF241A19),
    onSurface: Colors.white70,
    error: Color(0xFFE57373),
    onError: Color(0xFF2A1210),
  );

  return _construirTema(
    colorScheme: colorScheme,
    sofinaColors: SofinaColors.dark,
    scaffoldBackgroundColor: const Color(0xFF1C1414),
  );
}

ThemeData _construirTema({
  required ColorScheme colorScheme,
  required SofinaColors sofinaColors,
  required Color scaffoldBackgroundColor,
}) {
  return ThemeData(
    useMaterial3: false,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    extensions: [sofinaColors],
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      iconTheme: IconThemeData(color: colorScheme.onPrimary),
      titleTextStyle: TextStyle(
        color: colorScheme.onPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colorScheme.primary : null,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colorScheme.primary : null,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colorScheme.primary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary.withValues(alpha: 0.5)
            : null,
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: sofinaColors.softTint,
      checkmarkColor: colorScheme.primary,
      labelStyle: TextStyle(color: colorScheme.onSurface),
      backgroundColor: sofinaColors.softTint.withValues(alpha: 0.4),
    ),
    tabBarTheme: TabBarThemeData(
      // El único TabBar de la app vive dentro del AppBar (fondo
      // colorScheme.primary) -- el texto usa onPrimary (blanco) en vez de
      // onSurface (pensado para texto sobre una superficie clara). Antes:
      // onSurface a alpha 0.6 sobre un AppBar terracota daba ~2.6:1 de
      // contraste (bajo el mínimo WCAG AA de 3:1) -- la pestaña no
      // seleccionada quedaba prácticamente invisible; con onPrimary sube a
      // ~3.5:1 (no seleccionada) y ~5.5:1 (seleccionada).
      labelColor: colorScheme.onPrimary,
      unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.7),
      indicatorColor: colorScheme.onPrimary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
