// Datos bancarios capturados en el Paso 4 del registro público de
// especialistas -- pensados para pagos futuros. `declaracionTitularidad` es
// una declaración de la propia especialista (checkbox obligatorio), no una
// verificación real contra el banco.
enum BancoEspecialista {
  bcp,
  bbva,
  interbank,
  scotiabank,
  otro;

  String get valorRtdb => name;

  String get etiqueta {
    switch (this) {
      case BancoEspecialista.bcp:
        return 'BCP';
      case BancoEspecialista.bbva:
        return 'BBVA';
      case BancoEspecialista.interbank:
        return 'Interbank';
      case BancoEspecialista.scotiabank:
        return 'Scotiabank';
      case BancoEspecialista.otro:
        return 'Otro';
    }
  }
}

// CCI peruano: siempre 20 dígitos numéricos.
final RegExp formatoCci = RegExp(r'^\d{20}$');

class DatosBancarios {
  final BancoEspecialista banco;
  // Solo aplica (y se exige) si banco == otro.
  final String? bancoOtroNombre;
  // Fija en Soles -- sin selector, ver Paso 4 en RegistroEspecialistaPublicoPage.
  final String moneda;
  final String numeroCuenta;
  final String cci;
  final bool declaracionTitularidad;

  const DatosBancarios({
    required this.banco,
    this.bancoOtroNombre,
    this.moneda = 'PEN',
    required this.numeroCuenta,
    required this.cci,
    required this.declaracionTitularidad,
  });

  Map<String, dynamic> toMap() {
    return {
      'banco': banco.valorRtdb,
      if (banco == BancoEspecialista.otro) 'bancoOtroNombre': bancoOtroNombre,
      'moneda': moneda,
      'numeroCuenta': numeroCuenta,
      'cci': cci,
      'declaracionTitularidad': declaracionTitularidad,
    };
  }
}
