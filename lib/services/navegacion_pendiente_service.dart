import 'package:flutter/foundation.dart';

// Cita a abrir apenas HomePage esté lista, cuando el especialista o
// administrador llegó acá tocando una notificación push (segundo plano,
// o el sistema recién lanzando la app desde cero) -- ver
// notificaciones_service.dart. Vive fuera del árbol de widgets porque
// getInitialMessage() se resuelve en main() antes de que exista
// cualquier widget que lo reciba por constructor. Guarda también
// [estado] (tal como viaja en el payload del push) porque HomePage lo
// necesita para decidir el destino de un especialista
// (CitasEspecialistaPage vs HistorialEspecialistaPage) sin leer la cita
// completa antes de navegar.
class CitaPendienteDeNotificacion {
  final String citaId;
  final String? estado;

  const CitaPendienteDeNotificacion({required this.citaId, this.estado});
}

final ValueNotifier<CitaPendienteDeNotificacion?> citaPendienteDeNotificacion =
    ValueNotifier<CitaPendienteDeNotificacion?>(null);
