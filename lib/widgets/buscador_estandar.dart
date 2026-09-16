import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Buscador estándar reutilizado en los listados de citas (Citas,
// Historial, Gestión de citas): mismo padding, mismo radio de bordes,
// debounce de 300ms para no filtrar en cada tecla, y botón para limpiar.
// Copia 1:1 de proyectocitas2/lib/widgets/buscador_estandar.dart (Sofina
// Cliente) -- no hay paquete compartido entre las 2 apps, mismo criterio
// que ya usamos con ServicioChip/colorEstadoCita/transiciones_cita.dart.
//
// Este widget SOLO entrega el texto de búsqueda vía onChanged -- el
// filtrado (contains, case-insensitive) lo hace cada pantalla sobre los
// datos que ya tiene en memoria del StreamBuilder. No toca streams de
// Firebase ni los recrea, así que no dispara el bug de resuscripción ya
// corregido antes en otras pantallas (Pagos, Especialistas): mientras el
// stream de la pantalla que lo usa esté cacheado como campo `late final`
// (no creado inline en build()), el setState que dispara este buscador
// solo re-filtra datos ya recibidos, nunca se vuelve a suscribir.
class BuscadorEstandar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const BuscadorEstandar({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<BuscadorEstandar> createState() => _BuscadorEstandarState();
}

class _BuscadorEstandarState extends State<BuscadorEstandar> {
  final controlador = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    controlador.dispose();
    super.dispose();
  }

  void _onTextoCambiado(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(texto);
    });
    // Refresca el ícono de limpiar (aparece/desaparece según haya texto)
    // sin esperar al debounce.
    setState(() {});
  }

  void limpiar() {
    controlador.clear();
    _debounce?.cancel();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controlador,
        onChanged: _onTextoCambiado,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controlador.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: limpiar,
                ),
          filled: true,
          fillColor: Theme.of(context)
              .extension<SofinaColors>()!
              .softTint
              .withValues(alpha: 0.4),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
