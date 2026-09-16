import 'package:flutter/material.dart';

class MenuOpcion {
  final String titulo;
  final IconData icono;
  final Widget pagina;

  const MenuOpcion({
    required this.titulo,
    required this.icono,
    required this.pagina,
  });
}
