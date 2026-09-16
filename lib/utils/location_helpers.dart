import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'formatters.dart';

Future<Position?> obtenerUbicacionActual(BuildContext context) async {
  final servicioActivo = await Geolocator.isLocationServiceEnabled();

  if (!servicioActivo) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa el GPS del celular para registrar ubicación.'),
        ),
      );
    }
    return null;
  }

  LocationPermission permiso = await Geolocator.checkPermission();

  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }

  if (permiso == LocationPermission.denied ||
      permiso == LocationPermission.deniedForever) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se otorgó permiso de ubicación.'),
        ),
      );
    }
    return null;
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );
}

Future<void> abrirMapaEspecialista(
  BuildContext context,
  dynamic latitud,
  dynamic longitud,
) async {
  final lat = leerDouble(latitud);
  final lng = leerDouble(longitud);

  if (lat == null || lng == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aún no hay ubicación registrada de la especialista.'),
      ),
    );
    return;
  }

  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
  );

  final abierto = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!abierto && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir Google Maps.'),
      ),
    );
  }
}
