// Reglas de negocio de transición de estado de una cita -- fuente única
// de verdad para Cliente/Especialista/Admin (los 3 roles escriben
// `estado` de una cita). Espejada como red de seguridad server-side en
// database.rules.json (mismo criterio en Rules Language) -- ver ese
// archivo para el .validate equivalente. Las 2 capas deben decir
// exactamente lo mismo.
const _estadosFinalesCita = {'Atendida', 'Cancelada'};

// Regla general: ¿se puede pasar una cita de [estadoActual] a
// [estadoNuevo]?
// - Sin cambio real (mismo valor): siempre permitido -- ej. el admin
//   guarda solo la observación sin tocar el dropdown de estado.
// - Estados finales (Atendida/Cancelada): nadie cambia a otro estado,
//   ni el admin -- un error se corrige aparte, no reabriendo la cita.
// - "En sitio": la especialista ya viajó al lugar; el único destino
//   válido desde ahí es "Atendida".
bool puedeCambiarEstado(String estadoActual, String estadoNuevo) {
  if (estadoNuevo == estadoActual) return true;
  if (_estadosFinalesCita.contains(estadoActual)) return false;
  if (estadoActual == 'En sitio') return estadoNuevo == 'Atendida';
  return true;
}

// Caso particular más usado (botón "Cancelar"): azúcar sobre
// puedeCambiarEstado en vez de duplicar la lógica.
bool puedeCancelarCita(String estadoActual) =>
    puedeCambiarEstado(estadoActual, 'Cancelada');
