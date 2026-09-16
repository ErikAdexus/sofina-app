// Los 43 distritos de Lima Metropolitana, para que una especialista
// pueda registrar dónde VIVE (perfil, editado por el admin en
// listado_especialistas_page.dart). Esto es independiente de
// configuracion/distritosCobertura (ver ConfiguracionService), que es la
// whitelist de distritos donde el NEGOCIO da servicio (usada para
// validar direccionServicio antes de crear una cita) -- son dos
// conceptos distintos que antes vivían mezclados en la misma lista de 4
// por error (ver historial de abrirAsignarEspecialista).
const List<String> distritosLima = [
  'Ancón',
  'Ate',
  'Barranco',
  'Breña',
  'Carabayllo',
  'Chaclacayo',
  'Chorrillos',
  'Cieneguilla',
  'Comas',
  'El Agustino',
  'Independencia',
  'Jesús María',
  'La Molina',
  'La Victoria',
  'Lima Cercado',
  'Lince',
  'Los Olivos',
  'Lurigancho-Chosica',
  'Lurín',
  'Magdalena del Mar',
  'Miraflores',
  'Pachacámac',
  'Pucusana',
  'Pueblo Libre',
  'Puente Piedra',
  'Punta Hermosa',
  'Punta Negra',
  'Rímac',
  'San Bartolo',
  'San Borja',
  'San Isidro',
  'San Juan de Lurigancho',
  'San Juan de Miraflores',
  'San Luis',
  'San Martín de Porres',
  'San Miguel',
  'Santa Anita',
  'Santa María del Mar',
  'Santa Rosa',
  'Santiago de Surco',
  'Surquillo',
  'Villa El Salvador',
  'Villa María del Triunfo',
];
