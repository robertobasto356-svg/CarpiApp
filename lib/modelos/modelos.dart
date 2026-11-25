import '../core/ui.dart';

// =====================================================================
// Utilidades de lectura de JSON (PostgREST)
// =====================================================================
double? _num(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int _int(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _txt(dynamic v) => v?.toString() ?? '';
DateTime? _fecha(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
Map<String, dynamic>? _mapa(dynamic v) =>
    v is Map<String, dynamic> ? v : (v is List && v.isNotEmpty ? v.first as Map<String, dynamic> : null);

// =====================================================================
// Catálogos fijos
// =====================================================================
const tiposMueble = [
  'Clóset',
  'Cocina',
  'Mesa de comedor',
  'Escritorio',
  'Librero',
  'Cama',
  'Puerta',
  'Mueble de TV',
  'Otro',
];

const materialesAcabados = [
  'Melamina blanca',
  'Melamina color madera',
  'MDF laqueado',
  'MDF RH (zonas húmedas)',
  'Triplay de pino',
  'Pino · Barniz natural',
  'Cedro · Barniz natural',
  'Encino · Barniz natural',
  'Parota · Aceite natural',
  'Tzalam · Barniz mate',
  'Caoba · Barniz brillante',
  'Aún no lo sé',
];

IconData iconoMueble(String tipo) {
  final t = tipo.toLowerCase();
  if (t.contains('cl')) return Icons.checkroom_outlined;
  if (t.contains('cocina')) return Icons.kitchen_outlined;
  if (t.contains('mesa')) return Icons.table_restaurant_outlined;
  if (t.contains('escritorio')) return Icons.desk_outlined;
  if (t.contains('librero')) return Icons.menu_book_outlined;
  if (t.contains('cama')) return Icons.bed_outlined;
  if (t.contains('puerta')) return Icons.door_front_door_outlined;
  if (t.contains('tv')) return Icons.tv_outlined;
  return Icons.chair_outlined;
}

/// Archivo del modelo 3D de referencia según el tipo de mueble.
String modeloMueble(String tipo) {
  final t = tipo.toLowerCase();
  if (t.contains('cl')) return 'closet';
  if (t.contains('cocina')) return 'cocina';
  if (t.contains('mesa')) return 'mesa';
  if (t.contains('escritorio')) return 'escritorio';
  if (t.contains('librero')) return 'librero';
  if (t.contains('cama')) return 'cama';
  if (t.contains('puerta')) return 'puerta';
  if (t.contains('tv')) return 'mueble_tv';
  return 'librero';
}

// =====================================================================
// Estados del pedido
// =====================================================================
class EstadoPedido {
  final String clave;
  final String etiqueta;
  final Color color;
  final int paso; // 0 solicitud · 1 cita · 2 cotización · 3 fabricación · 4 entrega

  const EstadoPedido(this.clave, this.etiqueta, this.color, this.paso);

  static const todos = <EstadoPedido>[
    EstadoPedido('solicitado', 'Solicitud recibida', Color(0xFF6B7C93), 0),
    EstadoPedido('cita_agendada', 'Cita agendada', Color(0xFF3D7EA6), 1),
    EstadoPedido('en_cotizacion', 'En cotización', Color(0xFF8E6BBF), 2),
    EstadoPedido('cotizado', 'Cotización enviada', Color(0xFF2F6FDB), 2),
    EstadoPedido('ajustes_solicitados', 'Ajustes solicitados', Color(0xFFC77700), 2),
    EstadoPedido('aceptado', 'Cotización aceptada', Color(0xFF2E7D4F), 3),
    EstadoPedido('en_fabricacion', 'En fabricación', Color(0xFFD9822B), 3),
    EstadoPedido('por_entregar', 'Listo para entregar', Color(0xFF7B4BB7), 4),
    EstadoPedido('entregado', 'Entregado', Color(0xFF1B7F5A), 4),
    EstadoPedido('rechazado', 'Rechazado', Color(0xFFD22B2B), 2),
    EstadoPedido('cancelado', 'Cancelado', Color(0xFF8D8D8D), 0),
  ];

  static EstadoPedido de(String clave) =>
      todos.firstWhere((e) => e.clave == clave, orElse: () => todos.first);

  static const nuevos = ['solicitado', 'cita_agendada', 'en_cotizacion', 'ajustes_solicitados'];
  static const enProceso = ['aceptado', 'en_fabricacion', 'por_entregar'];
  static const cerrados = ['entregado', 'rechazado', 'cancelado'];
  static const fabricacion = ['aceptado', 'en_fabricacion', 'por_entregar', 'entregado'];
}

const pasosPedido = ['Solicitud', 'Cita', 'Cotización', 'Fabricación', 'Entrega'];

// =====================================================================
// Modelos
// =====================================================================
class Perfil {
  final String id;
  final String rol;
  String nombre;
  String telefono;
  String direccion;
  String ciudad;
  String rfc;
  String metodoPago;
  bool notificaciones;
  String? avatarPath;

  Perfil({
    required this.id,
    required this.rol,
    required this.nombre,
    this.telefono = '',
    this.direccion = '',
    this.ciudad = 'Mérida',
    this.rfc = '',
    this.metodoPago = '',
    this.notificaciones = true,
    this.avatarPath,
  });

  bool get esCarpintero => rol == 'carpintero';

  factory Perfil.desde(Map<String, dynamic> m) => Perfil(
        id: _txt(m['id']),
        rol: _txt(m['rol']),
        nombre: _txt(m['nombre']),
        telefono: _txt(m['telefono']),
        direccion: _txt(m['direccion']),
        ciudad: _txt(m['ciudad']),
        rfc: _txt(m['rfc']),
        metodoPago: _txt(m['metodo_pago']),
        notificaciones: m['notificaciones'] != false,
        avatarPath: m['avatar_path'] as String?,
      );
}

class Carpinteria {
  final String id;
  final String propietarioId;
  String nombre;
  String descripcion;
  String telefono;
  String correo;
  String direccion;
  String ciudad;
  String? logoPath;
  double? calificacion;
  int resenas;

  Carpinteria({
    required this.id,
    required this.propietarioId,
    required this.nombre,
    this.descripcion = '',
    this.telefono = '',
    this.correo = '',
    this.direccion = '',
    this.ciudad = 'Mérida',
    this.logoPath,
    this.calificacion,
    this.resenas = 0,
  });

  factory Carpinteria.desde(Map<String, dynamic> m) {
    final cal = m['calificaciones'];
    double? prom;
    var n = 0;
    if (cal is List && cal.isNotEmpty) {
      n = cal.length;
      prom = cal.map((c) => _num(c['estrellas']) ?? 0).reduce((a, b) => a + b) / n;
    }
    return Carpinteria(
      id: _txt(m['id']),
      propietarioId: _txt(m['propietario_id']),
      nombre: _txt(m['nombre']),
      descripcion: _txt(m['descripcion']),
      telefono: _txt(m['telefono']),
      correo: _txt(m['correo']),
      direccion: _txt(m['direccion']),
      ciudad: _txt(m['ciudad']),
      logoPath: m['logo_path'] as String?,
      calificacion: prom,
      resenas: n,
    );
  }
}

class Cliente {
  final int id;
  final String carpinteriaId;
  final String? perfilId;
  String nombre;
  String telefono;
  String correo;
  String direccion;
  String notas;
  int pedidos;

  Cliente({
    required this.id,
    required this.carpinteriaId,
    this.perfilId,
    required this.nombre,
    this.telefono = '',
    this.correo = '',
    this.direccion = '',
    this.notas = '',
    this.pedidos = 0,
  });

  bool get tieneCuenta => perfilId != null;

  factory Cliente.desde(Map<String, dynamic> m) => Cliente(
        id: _int(m['id']),
        carpinteriaId: _txt(m['carpinteria_id']),
        perfilId: m['perfil_id'] as String?,
        nombre: _txt(m['nombre']),
        telefono: _txt(m['telefono']),
        correo: _txt(m['correo']),
        direccion: _txt(m['direccion']),
        notas: _txt(m['notas']),
        pedidos: m['pedidos'] is List
            ? (m['pedidos'] as List).isNotEmpty && (m['pedidos'] as List).first is Map && (m['pedidos'] as List).first['count'] != null
                ? _int((m['pedidos'] as List).first['count'])
                : (m['pedidos'] as List).length
            : 0,
      );
}

class Pedido {
  final int id;
  final String carpinteriaId;
  final int clienteId;
  final int? catalogoId;
  String titulo;
  String tipoMueble;
  String materialAcabado;
  String descripcion;
  String estado;
  int progreso;
  double? alto;
  double? ancho;
  double? fondo;
  String medidasNotas;
  DateTime? medidasRegistradasAt;
  DateTime? fechaEntrega;
  final DateTime creado;
  DateTime actualizado;
  Cliente? cliente;
  Carpinteria? carpinteria;

  Pedido({
    required this.id,
    required this.carpinteriaId,
    required this.clienteId,
    this.catalogoId,
    required this.titulo,
    required this.tipoMueble,
    this.materialAcabado = '',
    this.descripcion = '',
    this.estado = 'solicitado',
    this.progreso = 0,
    this.alto,
    this.ancho,
    this.fondo,
    this.medidasNotas = '',
    this.medidasRegistradasAt,
    this.fechaEntrega,
    required this.creado,
    required this.actualizado,
    this.cliente,
    this.carpinteria,
  });

  String get folio => 'P-${id.toString().padLeft(4, '0')}';
  EstadoPedido get est => EstadoPedido.de(estado);
  bool get tieneMedidas => alto != null && ancho != null && fondo != null;
  String get medidasTexto => tieneMedidas
      ? 'Alto ${_cm(alto)} · Ancho ${_cm(ancho)} · Fondo ${_cm(fondo)}'
      : 'Sin medidas registradas';
  static String _cm(double? v) =>
      v == null ? '—' : '${v == v.roundToDouble() ? v.toInt() : v} cm';

  factory Pedido.desde(Map<String, dynamic> m) {
    final c = _mapa(m['clientes']);
    final k = _mapa(m['carpinterias']);
    return Pedido(
      id: _int(m['id']),
      carpinteriaId: _txt(m['carpinteria_id']),
      clienteId: _int(m['cliente_id']),
      catalogoId: m['catalogo_id'] == null ? null : _int(m['catalogo_id']),
      titulo: _txt(m['titulo']),
      tipoMueble: _txt(m['tipo_mueble']),
      materialAcabado: _txt(m['material_acabado']),
      descripcion: _txt(m['descripcion']),
      estado: _txt(m['estado']),
      progreso: _int(m['progreso']),
      alto: _num(m['alto_cm']),
      ancho: _num(m['ancho_cm']),
      fondo: _num(m['fondo_cm']),
      medidasNotas: _txt(m['medidas_notas']),
      medidasRegistradasAt: _fecha(m['medidas_registradas_at']),
      fechaEntrega: _fecha(m['fecha_entrega']),
      creado: _fecha(m['created_at']) ?? DateTime.now(),
      actualizado: _fecha(m['updated_at']) ?? DateTime.now(),
      cliente: c == null ? null : Cliente.desde(c),
      carpinteria: k == null ? null : Carpinteria.desde(k),
    );
  }
}

class Cita {
  final int id;
  final String carpinteriaId;
  final int? clienteId;
  final int? pedidoId;
  DateTime fechaHora;
  String motivo;
  String direccion;
  String estado;
  String notas;
  String clienteNombre;
  String pedidoTitulo;

  Cita({
    required this.id,
    required this.carpinteriaId,
    this.clienteId,
    this.pedidoId,
    required this.fechaHora,
    this.motivo = 'Toma de medidas',
    this.direccion = '',
    this.estado = 'confirmada',
    this.notas = '',
    this.clienteNombre = '',
    this.pedidoTitulo = '',
  });

  String get estadoTexto => const {
        'propuesta': 'Propuesta por el cliente',
        'confirmada': 'Confirmada',
        'realizada': 'Realizada',
        'cancelada': 'Cancelada',
      }[estado] ??
      estado;

  factory Cita.desde(Map<String, dynamic> m) => Cita(
        id: _int(m['id']),
        carpinteriaId: _txt(m['carpinteria_id']),
        clienteId: m['cliente_id'] == null ? null : _int(m['cliente_id']),
        pedidoId: m['pedido_id'] == null ? null : _int(m['pedido_id']),
        fechaHora: _fecha(m['fecha_hora']) ?? DateTime.now(),
        motivo: _txt(m['motivo']),
        direccion: _txt(m['direccion']),
        estado: _txt(m['estado']),
        notas: _txt(m['notas']),
        clienteNombre: _txt(_mapa(m['clientes'])?['nombre']),
        pedidoTitulo: _txt(_mapa(m['pedidos'])?['titulo']),
      );
}

class Partida {
  int? id;
  String concepto;
  double cantidad;
  String unidad;
  double precioUnitario;

  Partida({
    this.id,
    required this.concepto,
    this.cantidad = 1,
    this.unidad = 'pza',
    this.precioUnitario = 0,
  });

  double get importe => (cantidad * precioUnitario * 100).roundToDouble() / 100;

  factory Partida.desde(Map<String, dynamic> m) => Partida(
        id: _int(m['id']),
        concepto: _txt(m['concepto']),
        cantidad: _num(m['cantidad']) ?? 1,
        unidad: _txt(m['unidad']),
        precioUnitario: _num(m['precio_unitario']) ?? 0,
      );

  Map<String, dynamic> aMapa(int cotizacionId) => {
        'cotizacion_id': cotizacionId,
        'concepto': concepto,
        'cantidad': cantidad,
        'unidad': unidad,
        'precio_unitario': precioUnitario,
      };
}

class Cotizacion {
  final int id;
  final int pedidoId;
  final String carpinteriaId;
  double costoMateriales;
  double manoObra;
  double costosAdicionales;
  String notas;
  String estado;
  String comentarioCliente;
  String? pdfPath;
  DateTime? enviadaAt;
  DateTime? respondidaAt;
  final DateTime creado;
  List<Partida> partidas;
  Pedido? pedido;

  Cotizacion({
    required this.id,
    required this.pedidoId,
    required this.carpinteriaId,
    this.costoMateriales = 0,
    this.manoObra = 0,
    this.costosAdicionales = 0,
    this.notas = '',
    this.estado = 'borrador',
    this.comentarioCliente = '',
    this.pdfPath,
    this.enviadaAt,
    this.respondidaAt,
    required this.creado,
    this.partidas = const [],
    this.pedido,
  });

  double get total => costoMateriales + manoObra + costosAdicionales;
  String get folio => 'COT-${id.toString().padLeft(3, '0')}';

  String get estadoTexto => const {
        'borrador': 'Borrador',
        'enviada': 'Enviada',
        'aceptada': 'Aceptada',
        'rechazada': 'Rechazada',
        'ajustes': 'Ajustes solicitados',
      }[estado] ??
      estado;

  Color get estadoColor => const {
        'borrador': Color(0xFF8A7D73),
        'enviada': Color(0xFF2F6FDB),
        'aceptada': Color(0xFF2E7D4F),
        'rechazada': Color(0xFFD22B2B),
        'ajustes': Color(0xFFC77700),
      }[estado] ??
      const Color(0xFF8A7D73);

  factory Cotizacion.desde(Map<String, dynamic> m) {
    final p = _mapa(m['pedidos']);
    final partidas = (m['cotizacion_partidas'] as List?)
            ?.map((e) => Partida.desde(e as Map<String, dynamic>))
            .toList() ??
        <Partida>[];
    return Cotizacion(
      id: _int(m['id']),
      pedidoId: _int(m['pedido_id']),
      carpinteriaId: _txt(m['carpinteria_id']),
      costoMateriales: _num(m['costo_materiales']) ?? 0,
      manoObra: _num(m['mano_obra']) ?? 0,
      costosAdicionales: _num(m['costos_adicionales']) ?? 0,
      notas: _txt(m['notas']),
      estado: _txt(m['estado']),
      comentarioCliente: _txt(m['comentario_cliente']),
      pdfPath: m['pdf_path'] as String?,
      enviadaAt: _fecha(m['enviada_at']),
      respondidaAt: _fecha(m['respondida_at']),
      creado: _fecha(m['created_at']) ?? DateTime.now(),
      partidas: partidas,
      pedido: p == null ? null : Pedido.desde(p),
    );
  }
}

class Avance {
  final int id;
  final String estado;
  final int progreso;
  final String nota;
  final DateTime fecha;

  Avance({required this.id, required this.estado, required this.progreso, required this.nota, required this.fecha});

  factory Avance.desde(Map<String, dynamic> m) => Avance(
        id: _int(m['id']),
        estado: _txt(m['estado']),
        progreso: _int(m['progreso']),
        nota: _txt(m['nota']),
        fecha: _fecha(m['created_at']) ?? DateTime.now(),
      );
}

class Foto {
  final int id;
  final int pedidoId;
  final String? autorId;
  final String path;
  final String tipo;
  String descripcion;
  String descripcionIa;
  final DateTime fecha;

  Foto({
    required this.id,
    required this.pedidoId,
    this.autorId,
    required this.path,
    this.tipo = 'referencia',
    this.descripcion = '',
    this.descripcionIa = '',
    required this.fecha,
  });

  factory Foto.desde(Map<String, dynamic> m) => Foto(
        id: _int(m['id']),
        pedidoId: _int(m['pedido_id']),
        autorId: m['autor_id'] as String?,
        path: _txt(m['path']),
        tipo: _txt(m['tipo']),
        descripcion: _txt(m['descripcion']),
        descripcionIa: _txt(m['descripcion_ia']),
        fecha: _fecha(m['created_at']) ?? DateTime.now(),
      );
}

class Proveedor {
  final int id;
  final String? carpinteriaId;
  String tipo;
  String nombre;
  String descripcion;
  String telefono;
  String whatsapp;
  String correo;
  String sitioWeb;
  String direccion;
  String horario;

  Proveedor({
    required this.id,
    this.carpinteriaId,
    required this.tipo,
    required this.nombre,
    this.descripcion = '',
    this.telefono = '',
    this.whatsapp = '',
    this.correo = '',
    this.sitioWeb = '',
    this.direccion = '',
    this.horario = '',
  });

  bool get esPropio => carpinteriaId != null;

  factory Proveedor.desde(Map<String, dynamic> m) => Proveedor(
        id: _int(m['id']),
        carpinteriaId: m['carpinteria_id'] as String?,
        tipo: _txt(m['tipo']),
        nombre: _txt(m['nombre']),
        descripcion: _txt(m['descripcion']),
        telefono: _txt(m['telefono']),
        whatsapp: _txt(m['whatsapp']),
        correo: _txt(m['correo']),
        sitioWeb: _txt(m['sitio_web']),
        direccion: _txt(m['direccion']),
        horario: _txt(m['horario']),
      );

  Map<String, dynamic> aMapa() => {
        'tipo': tipo,
        'nombre': nombre,
        'descripcion': descripcion,
        'telefono': telefono,
        'whatsapp': whatsapp,
        'correo': correo,
        'sitio_web': sitioWeb,
        'direccion': direccion,
        'horario': horario,
      };
}

class ItemInventario {
  final int id;
  String tipo;
  String nombre;
  String categoria;
  String unidad;
  double cantidad;
  double costoUnitario;
  double stockMinimo;
  String notas;

  ItemInventario({
    required this.id,
    required this.tipo,
    required this.nombre,
    this.categoria = '',
    this.unidad = 'pza',
    this.cantidad = 0,
    this.costoUnitario = 0,
    this.stockMinimo = 0,
    this.notas = '',
  });

  bool get bajo => stockMinimo > 0 && cantidad <= stockMinimo;

  factory ItemInventario.desde(Map<String, dynamic> m) => ItemInventario(
        id: _int(m['id']),
        tipo: _txt(m['tipo']),
        nombre: _txt(m['nombre']),
        categoria: _txt(m['categoria']),
        unidad: _txt(m['unidad']),
        cantidad: _num(m['cantidad']) ?? 0,
        costoUnitario: _num(m['costo_unitario']) ?? 0,
        stockMinimo: _num(m['stock_minimo']) ?? 0,
        notas: _txt(m['notas']),
      );

  Map<String, dynamic> aMapa() => {
        'tipo': tipo,
        'nombre': nombre,
        'categoria': categoria,
        'unidad': unidad,
        'cantidad': cantidad,
        'costo_unitario': costoUnitario,
        'stock_minimo': stockMinimo,
        'notas': notas,
      };
}

class Gasto {
  final int id;
  final String concepto;
  final String categoria;
  final double monto;
  final DateTime fecha;

  Gasto({required this.id, required this.concepto, required this.categoria, required this.monto, required this.fecha});

  factory Gasto.desde(Map<String, dynamic> m) => Gasto(
        id: _int(m['id']),
        concepto: _txt(m['concepto']),
        categoria: _txt(m['categoria']),
        monto: _num(m['monto']) ?? 0,
        fecha: _fecha(m['fecha']) ?? DateTime.now(),
      );
}

class Mensaje {
  final int id;
  final String carpinteriaId;
  final String clientePerfilId;
  final String autorId;
  final String texto;
  final String? fotoPath;
  bool leido;
  final DateTime fecha;

  Mensaje({
    required this.id,
    required this.carpinteriaId,
    required this.clientePerfilId,
    required this.autorId,
    required this.texto,
    this.fotoPath,
    this.leido = false,
    required this.fecha,
  });

  factory Mensaje.desde(Map<String, dynamic> m) => Mensaje(
        id: _int(m['id']),
        carpinteriaId: _txt(m['carpinteria_id']),
        clientePerfilId: _txt(m['cliente_perfil_id']),
        autorId: _txt(m['autor_id']),
        texto: _txt(m['texto']),
        fotoPath: m['foto_path'] as String?,
        leido: m['leido'] == true,
        fecha: _fecha(m['created_at']) ?? DateTime.now(),
      );
}

class Notificacion {
  final int id;
  final String titulo;
  final String cuerpo;
  final String tipo;
  final int? pedidoId;
  bool leida;
  final DateTime fecha;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.tipo,
    this.pedidoId,
    this.leida = false,
    required this.fecha,
  });

  IconData get icono => switch (tipo) {
        'mensaje' => Icons.chat_bubble_outline,
        'cotizacion' => Icons.request_quote_outlined,
        'avance' => Icons.trending_up,
        _ => Icons.inventory_2_outlined,
      };

  factory Notificacion.desde(Map<String, dynamic> m) => Notificacion(
        id: _int(m['id']),
        titulo: _txt(m['titulo']),
        cuerpo: _txt(m['cuerpo']),
        tipo: _txt(m['tipo']),
        pedidoId: m['pedido_id'] == null ? null : _int(m['pedido_id']),
        leida: m['leida'] == true,
        fecha: _fecha(m['created_at']) ?? DateTime.now(),
      );
}

class ItemCatalogo {
  final int id;
  final String carpinteriaId;
  String titulo;
  String tipoMueble;
  String material;
  String descripcion;
  double? precioDesde;
  String? imagenPath;
  bool publicado;
  String carpinteriaNombre;

  ItemCatalogo({
    required this.id,
    required this.carpinteriaId,
    required this.titulo,
    required this.tipoMueble,
    this.material = '',
    this.descripcion = '',
    this.precioDesde,
    this.imagenPath,
    this.publicado = true,
    this.carpinteriaNombre = '',
  });

  factory ItemCatalogo.desde(Map<String, dynamic> m) => ItemCatalogo(
        id: _int(m['id']),
        carpinteriaId: _txt(m['carpinteria_id']),
        titulo: _txt(m['titulo']),
        tipoMueble: _txt(m['tipo_mueble']),
        material: _txt(m['material']),
        descripcion: _txt(m['descripcion']),
        precioDesde: _num(m['precio_desde']),
        imagenPath: m['imagen_path'] as String?,
        publicado: m['publicado'] != false,
        carpinteriaNombre: _txt(_mapa(m['carpinterias'])?['nombre']),
      );

  Map<String, dynamic> aMapa() => {
        'titulo': titulo,
        'tipo_mueble': tipoMueble,
        'material': material,
        'descripcion': descripcion,
        'precio_desde': precioDesde,
        'imagen_path': imagenPath,
        'publicado': publicado,
      };
}

class FichaConocimiento {
  final int id;
  final String categoria;
  final String titulo;
  final String contenido;
  final double puntaje;

  FichaConocimiento({
    required this.id,
    required this.categoria,
    required this.titulo,
    required this.contenido,
    required this.puntaje,
  });

  factory FichaConocimiento.desde(Map<String, dynamic> m) => FichaConocimiento(
        id: _int(m['id']),
        categoria: _txt(m['categoria']),
        titulo: _txt(m['titulo']),
        contenido: _txt(m['contenido']),
        puntaje: _num(m['puntaje']) ?? 0,
      );
}

/// Resumen de una conversación para las listas de mensajes.
class Conversacion {
  final String carpinteriaId;
  final String clientePerfilId;
  final String titulo;
  final String ultimo;
  final DateTime fecha;
  final int sinLeer;

  Conversacion({
    required this.carpinteriaId,
    required this.clientePerfilId,
    required this.titulo,
    required this.ultimo,
    required this.fecha,
    required this.sinLeer,
  });
}
