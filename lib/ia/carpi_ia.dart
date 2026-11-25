import 'dart:math' as math;

import '../datos/api.dart';
import '../modelos/modelos.dart';

/// CarpiIA: asistente propio de CarpiApp, gratuito y sin servicios externos.
///
/// Combina tres piezas:
///  1. Reglas de intención en español (saludo, límites, proveedores, cálculo
///     de tableros, revisión de pedido, armado de solicitud…).
///  2. Búsqueda de texto completo en español sobre la base de conocimiento
///     verificada (`buscar_conocimiento` en Supabase).
///  3. Plantillas de respuesta que respetan los límites definidos en el diseño:
///     la IA informa y organiza, pero NO diseña muebles ni confirma precios,
///     medidas, materiales definitivos o fechas.
class CarpiIA {
  final String rol; // 'carpintero' | 'cliente'
  final Pedido? pedido;
  BorradorSolicitud? _borrador;
  int _pasoBorrador = -1;

  CarpiIA({required this.rol, this.pedido});

  bool get armandoSolicitud => _pasoBorrador >= 0;

  // ------------------------------------------------------------------
  // Texto
  // ------------------------------------------------------------------
  static String normalizar(String s) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? a[i] : ch);
    }
    return b.toString();
  }

  static bool _tiene(String t, List<String> palabras) => palabras.any((p) => RegExp('\\b$p').hasMatch(t));

  static const _dominio = [
    'madera', 'mdf', 'melamina', 'triplay', 'aglomerado', 'tablero', 'barniz', 'laca', 'sellador', 'tinta',
    'aceite', 'cera', 'acabado', 'closet', 'cocina', 'mueble', 'mesa', 'escritorio', 'librero', 'cama',
    'puerta', 'bisagra', 'corredera', 'jaladera', 'tapacanto', 'canto', 'herraje', 'comejen', 'termita',
    'humedad', 'sol', 'medida', 'medir', 'cotizacion', 'pedido', 'cita', 'herramienta', 'sierra', 'taladro',
    'router', 'rebajadora', 'ingletadora', 'pino', 'cedro', 'caoba', 'encino', 'roble', 'parota', 'tzalam',
    'ciricote', 'melina', 'rosa morada', 'despiece', 'proveedor', 'material', 'pintura', 'lijar', 'carpinter',
    'cajon', 'repisa', 'gabinete', 'limpi', 'manten', 'realidad aumentada', 'foto', 'entrega', 'fabrica',
  ];

  // ------------------------------------------------------------------
  // Respuesta principal
  // ------------------------------------------------------------------
  Future<RespuestaIA> responder(String mensaje) async {
    final t = normalizar(mensaje.trim());
    if (t.isEmpty) return RespuestaIA('Escribe tu pregunta y con gusto te ayudo.');

    if (armandoSolicitud) return _continuarBorrador(mensaje.trim(), t);

    if (_tiene(t, ['hola', 'buen', 'que tal', 'hey'])&& t.length < 25) return bienvenida();
    if (_tiene(t, ['gracias', 'muchas gracias', 'excelente', 'perfecto']) && t.length < 30) {
      return RespuestaIA('¡Con gusto! Si tienes otra duda sobre maderas, acabados o tu pedido, aquí estoy.',
          sugerencias: _sugerencias());
    }

    // Cliente: armar la solicitud
    if (rol == 'cliente' &&
        (_tiene(t, ['preparar', 'quiero', 'necesito', 'busco', 'me gustaria', 'solicitar', 'hacer un', 'mandar a hacer']) &&
            (_tiene(t, ['mueble', 'closet', 'cocina', 'mesa', 'escritorio', 'librero', 'cama', 'puerta', 'pedido', 'solicitud', 'tv']) ||
                t.contains('preparar mi pedido')))) {
      final r = await _infoSiAplica(t);
      final inicio = _iniciarBorrador(t);
      if (r != null) {
        return RespuestaIA('${r.texto}\n\n${inicio.texto}',
            fichas: r.fichas, sugerencias: inicio.sugerencias, borrador: inicio.borrador);
      }
      return inicio;
    }

    // Límites: precio, medidas exactas, fechas, diseño
    final limite = _limite(t);
    if (limite != null) return limite;

    // Carpintero: revisar el pedido en contexto
    if (rol == 'carpintero' && pedido != null && _tiene(t, ['revis', 'falta', 'pendiente', 'checa', 'verifica'])) {
      final h = revisarPedido(pedido!);
      return RespuestaIA(
        'Revisé ${pedido!.folio} · ${pedido!.titulo}:\n${h.map((x) => '${x.ok ? '✅' : '⚠️'} ${x.texto}').join('\n')}',
        sugerencias: const ['¿Qué acabado conviene para humedad?', 'Proveedores de MDF', 'Cómo hacer un despiece'],
      );
    }

    // Carpintero: cálculo rápido de tableros
    final calculo = _calcularTableros(t);
    if (calculo != null) return calculo;

    // Proveedores
    if (_tiene(t, ['proveedor', 'donde compro', 'donde consigo', 'quien vende', 'maderer', 'ferreter', 'donde venden', 'comprar'])) {
      return _proveedores(t);
    }

    // Conocimiento general
    final fichas = await Api.buscarConocimiento(mensaje, rol, limite: 4);
    final relevantes = fichas.where((f) => f.puntaje >= .35).toList();
    if (relevantes.isEmpty) {
      if (!_tiene(t, _dominio)) return _fueraDeAlcance();
      return RespuestaIA(
        'No encontré información verificada sobre eso en la guía local. '
        '${rol == 'cliente' ? 'Te sugiero preguntarle directamente a tu carpintero; puedo ayudarte a preparar la consulta.' : 'Intenta con otras palabras (por ejemplo, el nombre del material o del acabado).'}',
        sugerencias: _sugerencias(),
      );
    }
    final principal = relevantes.first;
    final extra = relevantes.skip(1).take(2).map((f) => f.titulo).toList();
    final b = StringBuffer()
      ..writeln('**${principal.titulo}**')
      ..writeln(principal.contenido);
    if (extra.isNotEmpty) b.write('\nTambién te puede servir: ${extra.join(' · ')}.');
    if (rol == 'cliente' && ['madera', 'tablero', 'acabado'].contains(principal.categoria)) {
      b.write('\n\nLa disponibilidad se confirma con el proveedor. El carpintero revisará contigo cuál opción funciona para tu proyecto.');
    }
    return RespuestaIA(b.toString().trim(), fichas: relevantes, sugerencias: _sugerencias(despuesDe: principal.categoria));
  }

  RespuestaIA bienvenida() => RespuestaIA(
        rol == 'cliente'
            ? 'Hola, soy el asistente de CarpiApp. Puedo darte información general de maderas, tableros y acabados, '
                'cuidados para el calor y la humedad de Mérida, y ayudarte a organizar tu solicitud para el carpintero.\n\n'
                'No genero diseños ni confirmo precios, medidas o fechas: eso lo acuerdas con tu carpintero.'
            : 'Hola, soy CarpiIA. Puedo resolver dudas de materiales, herramientas y acabados, consultar proveedores de Mérida, '
                'estimar tableros para un despiece y revisar si a un pedido le faltan datos antes de cotizar o fabricar.\n\n'
                'Tú decides qué aplicar: mis respuestas son de apoyo.',
        sugerencias: _sugerencias(),
      );

  List<String> _sugerencias({String? despuesDe}) => rol == 'cliente'
      ? [
          'Preparar mi pedido',
          if (despuesDe != 'cuidado') '¿Qué madera resiste la humedad?',
          if (despuesDe != 'acabado') '¿Qué acabado conviene para una mesa?',
          '¿Quién toma las medidas?',
        ]
      : [
          if (pedido != null) 'Revisar este pedido',
          'Proveedores de MDF y melamina',
          '¿Cuántos tableros necesito para 10 m²?',
          'Prevención del comején',
        ];

  RespuestaIA? _limite(String t) {
    final precio = _tiene(t, ['cuanto cuesta', 'cuanto sale', 'precio', 'costo', 'cuanto cobra', 'presupuesto']);
    final medidas = _tiene(t, ['que medida', 'cuanto mide', 'medidas exactas', 'de que tamano', 'medida exacta']);
    final fecha = _tiene(t, ['en cuantos dias', 'fecha de entrega', 'cuanto tarda', 'cuanto tiempo', 'para cuando']) ||
        (t.contains('cuando') && RegExp(r'entreg|termin|listo|estara|instal').hasMatch(t));
    final diseno = _tiene(t, ['disena', 'diseno', 'dibuja', 'hazme un modelo', 'genera un', 'crea un diseno']);
    if (rol == 'carpintero') {
      // Al carpintero solo le aclaramos el diseño; precios y fechas los define él.
      if (diseno) {
        return RespuestaIA('No genero diseños. Puedo ayudarte con medidas estándar de referencia, materiales y herrajes para que tú definas el diseño.',
            sugerencias: const ['Medidas estándar de muebles', 'Bisagras de cazoleta']);
      }
      return null;
    }
    if (!(precio || medidas || fecha || diseno)) return null;
    final que = [
      if (precio) 'el precio',
      if (medidas) 'las medidas',
      if (fecha) 'la fecha de entrega',
      if (diseno) 'el diseño',
    ].join(', ');
    return RespuestaIA(
      'Eso no lo puedo confirmar yo: $que lo determina o acuerda contigo el carpintero. '
      '${precio ? 'Él te enviará una cotización en PDF con el desglose de materiales, mano de obra y costos adicionales. ' : ''}'
      '${medidas ? 'Las medidas las toma él en la cita, midiendo en varios puntos del espacio. ' : ''}'
      '\n\nSi quieres, preparo tu solicitud para que te responda más rápido.',
      sugerencias: const ['Preparar mi pedido', '¿Qué incluye una cotización?', '¿Quién toma las medidas?'],
    );
  }

  RespuestaIA _fueraDeAlcance() => RespuestaIA(
        'Eso está fuera de lo que puedo confirmar con la información de CarpiApp. '
        'Puedo ayudarte con maderas, tableros, acabados, herrajes, cuidados de muebles'
        '${rol == 'cliente' ? ' y a preparar tu consulta para el carpintero.' : ', proveedores locales y la revisión de tus pedidos.'}',
        sugerencias: _sugerencias(),
      );

  Future<RespuestaIA?> _infoSiAplica(String t) async {
    if (!_tiene(t, ['madera', 'acabado', 'humedad', 'comejen', 'cuidado'])) return null;
    final f = await Api.buscarConocimiento(t, rol, limite: 2);
    if (f.isEmpty || f.first.puntaje < .35) return null;
    return RespuestaIA('**${f.first.titulo}**\n${f.first.contenido}\nLa disponibilidad se confirma con el proveedor.', fichas: f);
  }

  RespuestaIA? _calcularTableros(String t) {
    if (rol != 'carpintero') return null;
    if (!_tiene(t, ['tablero', 'hojas', 'hoja de'])) return null;
    final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(m2|m²|metros cuadrados|mts2|metros)').firstMatch(t);
    if (m == null) return null;
    final area = double.parse(m.group(1)!.replaceAll(',', '.'));
    const tablero = 1.22 * 2.44; // 2.977 m²
    const aprovechamiento = .87; // ≈13 % de desperdicio
    final hojas = (area / (tablero * aprovechamiento)).ceil();
    return RespuestaIA(
      'Para ${area.toStringAsFixed(area % 1 == 0 ? 0 : 1)} m² de piezas necesitas aproximadamente **$hojas tableros** de 1.22 × 2.44 m '
      '(${tablero.toStringAsFixed(2)} m² cada uno, con ~13 % de desperdicio por cortes y grueso de sierra).\n\n'
      'Confírmalo con tu despiece real: piezas grandes o vetas en una dirección pueden pedir una hoja más. '
      'No olvides tapacanto: suma el perímetro de los cantos visibles.',
      sugerencias: const ['Cómo hacer un despiece', 'Estimar el costo de materiales', 'Proveedores de MDF y melamina'],
    );
  }

  Future<RespuestaIA> _proveedores(String t) async {
    if (rol == 'cliente') {
      return RespuestaIA(
        'El directorio de proveedores es para los carpinteros: tu carpintero consigue los materiales con maderas y ferreterías de Mérida '
        'y te los incluye en la cotización. Si te interesa un material en particular, menciónalo en tu solicitud.',
        sugerencias: const ['Preparar mi pedido', '¿Qué es la melamina?'],
      );
    }
    final todos = [...await Api.proveedores('materiales'), ...await Api.proveedores('herramientas')];
    final claves = t
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 2 && !['proveedor', 'proveedores', 'donde', 'compro', 'consigo', 'quien', 'vende', 'para', 'los', 'las', 'del', 'que'].contains(w))
        .toList();
    var encontrados = todos.where((p) {
      final texto = normalizar('${p.nombre} ${p.descripcion}');
      return claves.any(texto.contains);
    }).toList();
    final general = encontrados.isEmpty;
    if (general) {
      final herramienta = _tiene(t, ['herramienta', 'sierra', 'taladro', 'herraje', 'bisagra', 'corredera', 'jaladera']);
      encontrados = todos.where((p) => p.tipo == (herramienta ? 'herramientas' : 'materiales')).toList();
    }
    final lista = encontrados.take(4).toList();
    return RespuestaIA(
      general
          ? 'Estos son proveedores del directorio de Mérida que te pueden servir:'
          : 'Encontré estos proveedores que manejan lo que buscas:',
      proveedores: lista,
      sugerencias: const ['Proveedores de herrajes', 'Proveedores de madera sólida', 'Tapacanto'],
      pie: 'Existencias y precios se confirman directamente con cada proveedor.',
    );
  }

  // ------------------------------------------------------------------
  // Borrador de solicitud del cliente (conversación guiada)
  // ------------------------------------------------------------------
  static const usos = ['Recámara', 'Cocina', 'Sala', 'Comedor', 'Oficina', 'Baño', 'Exterior'];

  /// Palabras con las que la gente nombra cada tipo de mueble.
  static const _claves = <String, List<String>>{
    'Clóset': ['closet', 'ropero', 'armario', 'vestidor'],
    'Cocina': ['cocina', 'alacena', 'gabinete', 'cocineta'],
    'Mesa de comedor': ['mesa', 'comedor'],
    'Escritorio': ['escritorio', 'home office'],
    'Librero': ['librero', 'repisa', 'estante', 'estanteria'],
    'Cama': ['cama', 'cabecera', 'litera'],
    'Puerta': ['puerta', 'porton'],
    'Mueble de TV': ['tv', 'television', 'tele', 'entretenimiento'],
  };

  static String? tipoDe(String t) {
    for (final e in _claves.entries) {
      if (e.value.any((k) => RegExp('\\b$k').hasMatch(t))) return e.key;
    }
    return null;
  }

  RespuestaIA _iniciarBorrador(String t) {
    _borrador = BorradorSolicitud();
    final tipo = tipoDe(t) ?? '';
    if (tipo.isNotEmpty) {
      _borrador!.tipo = tipo;
      _pasoBorrador = 1;
      return RespuestaIA('Perfecto, organizo tu solicitud de **$tipo**. ¿En qué espacio o para qué uso será?', sugerencias: usos);
    }
    _pasoBorrador = 0;
    return RespuestaIA('¡Claro! Te hago unas preguntas sencillas para preparar tu solicitud. ¿Qué mueble necesitas?',
        sugerencias: tiposMueble);
  }

  Future<RespuestaIA> _continuarBorrador(String original, String t) async {
    final b = _borrador!;
    if (_tiene(t, ['cancelar', 'olvidalo', 'salir'])) {
      _pasoBorrador = -1;
      _borrador = null;
      return RespuestaIA('Listo, dejamos la solicitud para después.', sugerencias: _sugerencias());
    }
    switch (_pasoBorrador) {
      case 0:
        final tipo = tipoDe(t);
        if (tipo == null) {
          b.tipo = 'Otro';
          b.descripcion = 'Mueble: $original.';
        } else {
          b.tipo = tipo;
        }
        _pasoBorrador = 1;
        return RespuestaIA('¿En qué espacio o para qué uso será el ${b.tipo.toLowerCase()}?', sugerencias: usos);
      case 1:
        b.uso = original;
        _pasoBorrador = 2;
        final humedo = _tiene(t, ['bano', 'cocina', 'exterior', 'jardin', 'terraza']);
        return RespuestaIA(
          '${humedo ? 'Como estará en una zona con humedad, conviene MDF RH o maderas resistentes, con cantos bien sellados. ' : ''}'
          '¿Tienes alguna preferencia de material o acabado?',
          sugerencias: materialesAcabados.take(6).toList()..add('Aún no lo sé'),
        );
      case 2:
        b.material = _tiene(t, ['no se', 'aun no', 'no lo se', 'lo que recomiende']) ? '' : original;
        _pasoBorrador = 3;
        return RespuestaIA(
          'Cuéntame en pocas palabras cómo lo imaginas (puertas, cajones, color, estilo…). '
          'Si prefieres, escribe "listo" y lo detallas con el carpintero en la cita.',
          sugerencias: const ['Listo'],
        );
      default:
        if (!_tiene(t, ['listo', 'es todo', 'nada mas', 'ninguno'])) {
          b.descripcion = [b.descripcion, original].where((s) => s.isNotEmpty).join(' ');
        }
        _pasoBorrador = -1;
        final borrador = b;
        _borrador = null;
        return RespuestaIA(
          'Preparé este borrador. Puedes editarlo antes de enviarlo al carpintero, agregar fotos de referencia y proponer la fecha de la cita.',
          borrador: borrador,
          sugerencias: const ['Adjuntar una foto', '¿Quién toma las medidas?'],
        );
    }
  }

  // ------------------------------------------------------------------
  // Revisión de datos faltantes de un pedido (carpintero)
  // ------------------------------------------------------------------
  static List<Hallazgo> revisarPedido(Pedido p, {int fotos = 0, Cotizacion? cotizacion, List<Cita> citas = const []}) {
    final h = <Hallazgo>[];
    void r(bool ok, String si, String no) => h.add(Hallazgo(ok, ok ? si : no));

    r(p.materialAcabado.trim().isNotEmpty, 'Material y acabado definidos: ${p.materialAcabado}.',
        'Falta definir el material y el acabado con el cliente.');
    final medidas = [p.alto, p.ancho, p.fondo];
    final faltan = <String>[
      if (p.alto == null) 'alto',
      if (p.ancho == null) 'ancho',
      if (p.fondo == null) 'fondo',
    ];
    r(faltan.isEmpty, 'Medidas registradas: ${p.medidasTexto}.',
        'Faltan medidas: ${faltan.join(', ')}. Tómalas en la cita usando la medida menor.');
    if (faltan.isEmpty) {
      final alto = p.alto!, ancho = p.ancho!, fondo = p.fondo!;
      final tipo = normalizar(p.tipoMueble);
      if (tipo.contains('closet') && (fondo < 45 || fondo > 70)) {
        h.add(Hallazgo(false, 'El fondo de ${fondo.toStringAsFixed(0)} cm es poco usual para un clóset (lo común es 55–60 cm). Verifícalo.'));
      }
      if (tipo.contains('mesa') && (alto < 60 || alto > 90)) {
        h.add(Hallazgo(false, 'Una mesa de comedor suele medir ≈75 cm de alto; registraste ${alto.toStringAsFixed(0)} cm.'));
      }
      if (tipo.contains('escritorio') && (alto < 65 || alto > 85)) {
        h.add(Hallazgo(false, 'Un escritorio suele medir 73–76 cm de alto; registraste ${alto.toStringAsFixed(0)} cm.'));
      }
      if (medidas.any((v) => v! > 400) || math.max(alto, ancho) > 300 && tipo.contains('mesa')) {
        h.add(Hallazgo(false, 'Alguna medida es muy grande; confirma que esté en centímetros.'));
      }
    }
    r(fotos > 0, 'Tienes $fotos ${fotos == 1 ? 'foto' : 'fotos'} de referencia.',
        'No hay fotos de referencia del espacio; toma al menos una en la cita.');
    final cita = citas.where((c) => c.estado != 'cancelada').toList();
    r(cita.isNotEmpty || p.tieneMedidas, 'La cita para medir está ${cita.isEmpty ? 'cubierta' : cita.first.estadoTexto.toLowerCase()}.',
        'No hay cita agendada para tomar medidas.');
    if (cotizacion == null) {
      h.add(Hallazgo(false, 'Aún no hay cotización.'));
    } else {
      r(cotizacion.partidas.isNotEmpty, 'La cotización desglosa ${cotizacion.partidas.length} materiales.',
          'La cotización no desglosa materiales; agrega partidas para que el cliente vea el detalle.');
      r(cotizacion.manoObra > 0, 'Mano de obra incluida.', 'La cotización no incluye mano de obra.');
      if (cotizacion.estado == 'ajustes') {
        h.add(Hallazgo(false, 'El cliente pidió ajustes: “${cotizacion.comentarioCliente}”.'));
      }
    }
    if (EstadoPedido.enProceso.contains(p.estado)) {
      r(p.fechaEntrega != null, 'Fecha de entrega estimada: definida.', 'Define una fecha de entrega estimada para el cliente.');
    }
    return h;
  }
}

class Hallazgo {
  final bool ok;
  final String texto;
  Hallazgo(this.ok, this.texto);
}

class BorradorSolicitud {
  String tipo = '';
  String uso = '';
  String material = '';
  String descripcion = '';

  String get resumen => [
        tipo,
        if (uso.isNotEmpty) 'Uso: ${uso.toLowerCase()}',
        if (material.isNotEmpty) material,
      ].join(' · ');

  String get descripcionCompleta => [
        if (uso.isNotEmpty) 'Uso: $uso.',
        if (descripcion.isNotEmpty) descripcion,
      ].join(' ');
}

class RespuestaIA {
  final String texto;
  final List<FichaConocimiento> fichas;
  final List<Proveedor> proveedores;
  final List<String> sugerencias;
  final BorradorSolicitud? borrador;
  final String? pie;

  RespuestaIA(
    this.texto, {
    this.fichas = const [],
    this.proveedores = const [],
    this.sugerencias = const [],
    this.borrador,
    this.pie,
  });
}
