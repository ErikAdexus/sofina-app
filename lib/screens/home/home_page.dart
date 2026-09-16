import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/menu_opcion.dart';
import '../../services/navegacion_pendiente_service.dart';
import '../../services/notificaciones_service.dart';
import '../cuenta/mi_cuenta_page.dart';
import '../clientes/listado_clientes_page.dart';
import '../especialistas/listado_especialistas_page.dart';
import '../catalogo/catalogo_servicios_page.dart';
import '../citas/admin_gestion_citas_page.dart';
import '../citas/citas_especialista_page.dart';
import '../citas/conciliacion_pagos_page.dart';
import '../citas/historial_especialista_page.dart';
import '../calificaciones/mis_calificaciones_page.dart';
import '../disponibilidad/horario_base_page.dart';
import '../solicitudes/solicitudes_cotizacion_page.dart';

class HomePage extends StatefulWidget {
  final String rol;
  final String identificador;
  final String nombre;

  const HomePage({
    super.key,
    this.rol = 'administrador',
    this.identificador = '',
    this.nombre = '',
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  String get rolUsuario => widget.rol.trim().toLowerCase();

  @override
  void initState() {
    super.initState();

    // Mismo punto que en proyectocitas2: AuthGate ya confirmó acá que
    // hay sesión, el rol es válido (especialista o administrador) y la
    // cuenta está activa -- un solo hook sirve para los dos roles, no
    // hace falta duplicar esto en ningún otro lado.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      configurarNotificacionesPush(uid);
    }
    configurarAperturaDesdeNotificacion();

    citaPendienteDeNotificacion.addListener(_atenderCitaPendiente);
    _atenderCitaPendiente();
  }

  void _atenderCitaPendiente() {
    final pendiente = citaPendienteDeNotificacion.value;
    if (pendiente == null) return;

    // Se consume una sola vez.
    citaPendienteDeNotificacion.value = null;

    // addPostFrameCallback: esta función se llama tanto desde un listener
    // (seguro, la app ya está montada) como directo en initState (todavía
    // sin Navigator ancestor disponible) -- diferirlo un frame cubre los
    // dos casos sin duplicar la lógica.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (rolUsuario == 'administrador') {
        Navigator.push(
          context,
          MaterialPageRoute(
            // AdminGestionCitasPage no trae su propio Scaffold -- está
            // pensada para vivir como body: de HomePage (ver build() de
            // más abajo), que es quien normalmente le da el Material
            // ancestor. Empujarla sola sin este Scaffold deja a sus
            // TextField (BuscadorEstandar) sin Material: en debug tira
            // "No Material widget found"; en release el assert es un
            // no-op y en cambio se ve el glitch visual (fondo negro, sin
            // barra superior) que motivó este fix.
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Citas')),
              body: AdminGestionCitasPage(citaIdInicial: pendiente.citaId),
            ),
          ),
        );
        return;
      }

      if (rolUsuario == 'especialista') {
        // estadosAccionablesEspecialista ya es público en
        // citas_especialista_page.dart (import ya existe acá para el
        // menú) -- evita duplicar el set de estados terminales.
        final esAccionable = estadosAccionablesEspecialista
            .contains(pendiente.estado ?? '');

        Navigator.push(
          context,
          MaterialPageRoute(
            // Mismo motivo que el caso administrador de arriba:
            // CitasEspecialistaPage/HistorialEspecialistaPage tampoco
            // traen Scaffold propio.
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(esAccionable ? 'Citas' : 'Historial'),
              ),
              body: esAccionable
                  ? CitasEspecialistaPage(citaIdInicial: pendiente.citaId)
                  : HistorialEspecialistaPage(citaIdInicial: pendiente.citaId),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    citaPendienteDeNotificacion.removeListener(_atenderCitaPendiente);
    super.dispose();
  }

  List<MenuOpcion> opcionesMenu() {
    final opciones = <MenuOpcion>[];

    if (rolUsuario == 'especialista') {
      opciones.addAll(
        const [
          MenuOpcion(
            titulo: 'Citas',
            icono: Icons.event_note,
            pagina: CitasEspecialistaPage(),
          ),
          MenuOpcion(
            titulo: 'Historial',
            icono: Icons.history,
            pagina: HistorialEspecialistaPage(),
          ),
          MenuOpcion(
            titulo: 'Calificaciones',
            icono: Icons.star_rate,
            pagina: MisCalificacionesPage(),
          ),
          MenuOpcion(
            titulo: 'Disponibilidad',
            icono: Icons.event_available,
            pagina: HorarioBasePage(),
          ),
        ],
      );
    }

    if (rolUsuario == 'administrador') {
      opciones.addAll(
        const [
          MenuOpcion(
            titulo: 'Catálogo',
            icono: Icons.storefront,
            pagina: CatalogoServiciosPage(),
          ),
          MenuOpcion(
            titulo: 'Solicitudes',
            icono: Icons.request_quote,
            pagina: SolicitudesCotizacionPage(),
          ),
          MenuOpcion(
            titulo: 'Clientes',
            icono: Icons.list,
            pagina: ListadoClientesPage(),
          ),
          MenuOpcion(
            titulo: 'Especialistas',
            icono: Icons.badge,
            pagina: ListadoEspecialistasPage(),
          ),
          MenuOpcion(
            titulo: 'Citas',
            icono: Icons.assignment_ind,
            pagina: AdminGestionCitasPage(),
          ),
          MenuOpcion(
            titulo: 'Pagos',
            icono: Icons.receipt_long,
            pagina: ConciliacionPagosPage(),
          ),
        ],
      );
    }

    return opciones;
  }

  void cambiarPagina(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void abrirMiCuenta() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiCuentaPage(
          nombre: widget.nombre,
          identificador: widget.identificador,
          rol: rolUsuario,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opciones = opcionesMenu();

    if (selectedIndex >= opciones.length) {
      selectedIndex = 0;
    }

    final opcionActual = opciones[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(opcionActual.titulo),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            onPressed: abrirMiCuenta,
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      body: opcionActual.pagina,
      // BottomNavigationBar exige mínimo 2 items; si un rol solo tiene una
      // pantalla disponible, se omite la barra y se muestra esa pantalla sola.
      bottomNavigationBar: opciones.length < 2
          ? null
          : BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: cambiarPagina,
              items: [
                for (final opcion in opciones)
                  BottomNavigationBarItem(
                    icon: Icon(opcion.icono),
                    label: opcion.titulo,
                  ),
              ],
            ),
    );
  }
}
