import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supa.dart';
import '../modelos/modelos.dart';
import 'sesion.dart';

/// Acceso a datos de CarpiApp. Toda la seguridad la aplica la base (RLS);
/// aquí solo se arman las consultas.
class Api {
  static String get _miCarpinteria => sesion.carpinteria!.id;
  static String get miCarpinteriaId => _miCarpinteria;

  // ================================================================
  // Pedidos
  // ================================================================
  static const _selPedido = '*, clientes(*), carpinterias(*)';

  static Future<List<Pedido>> pedidosCarpinteria({List<String>? estados}) async {
    var q = supa.from('pedidos').select(_selPedido).eq('carpinteria_id', _miCarpinteria);
    if (estados != null) q = q.inFilter('estado', estados);
    final r = await q.order('updated_at', ascending: false);
    return r.map(Pedido.desde).toList();
  }

  static Future<List<Pedido>> pedidosCliente() async {
    final r = await supa.from('pedidos').select(_selPedido).order('updated_at', ascending: false);
    return r.map(Pedido.desde).toList();
  }

  static Future<List<Pedido>> pedidosDeCliente(int clienteId) async {
    final r = await supa
        .from('pedidos')
        .select(_selPedido)
        .eq('cliente_id', clienteId)
        .order('created_at', ascending: false);
    return r.map(Pedido.desde).toList();
  }

  static Future<Pedido> pedido(int id) async =>
      Pedido.desde(await supa.from('pedidos').select(_selPedido).eq('id', id).single());

  static Future<void> actualizarPedido(int id, Map<String, dynamic> cambios) =>
      supa.from('pedidos').update(cambios).eq('id', id);

  /// Estado, avance, fecha de entrega y nota en un solo registro del historial.
  static Future<void> registrarAvance(
    int id, {
    required String estado,
    required int progreso,
    DateTime? entrega,
    String nota = '',
  }) => supa.rpc(
    'registrar_avance',
    params: {
      'p_pedido': id,
      'p_estado': estado,
      'p_progreso': progreso,
      'p_entrega': entrega?.toIso8601String().substring(0, 10),
      'p_nota': nota.trim(),
    },
  );

  static Future<int> crearPedido({
    required int clienteId,
    required String titulo,
    required String tipoMueble,
    String materialAcabado = '',
    String descripcion = '',
    String estado = 'en_cotizacion',
  }) async {
    final r = await supa
        .from('pedidos')
        .insert({
          'carpinteria_id': _miCarpinteria,
          'cliente_id': clienteId,
          'titulo': titulo,
          'tipo_mueble': tipoMueble,
          'material_acabado': materialAcabado,
          'descripcion': descripcion,
          'estado': estado,
        })
        .select('id')
        .single();
    return r['id'] as int;
  }

  /// Solicitud del cliente: crea su ficha en la carpintería, el pedido y la cita.
  static Future<int> crearSolicitud({
    required String carpinteriaId,
    required String tipoMueble,
    required String titulo,
    required String materialAcabado,
    required String descripcion,
    DateTime? fechaCita,
    String direccion = '',
    int? catalogoId,
  }) async {
    final r = await supa.rpc(
      'crear_solicitud',
      params: {
        'p_carpinteria': carpinteriaId,
        'p_tipo_mueble': tipoMueble,
        'p_titulo': titulo,
        'p_material_acabado': materialAcabado,
        'p_descripcion': descripcion,
        'p_fecha_cita': fechaCita?.toUtc().toIso8601String(),
        'p_direccion': direccion,
        'p_catalogo': catalogoId,
      },
    );
    return (r as num).toInt();
  }

  // ================================================================
  // Citas
  // ================================================================
  static const _selCita = '*, clientes(nombre), pedidos(titulo)';

  static Future<List<Cita>> citasCarpinteria(DateTime desde, DateTime hasta) async {
    final r = await supa
        .from('citas')
        .select(_selCita)
        .eq('carpinteria_id', _miCarpinteria)
        .gte('fecha_hora', desde.toUtc().toIso8601String())
        .lt('fecha_hora', hasta.toUtc().toIso8601String())
        .order('fecha_hora', ascending: true);
    return r.map(Cita.desde).toList();
  }

  static Future<List<Cita>> citasPedido(int pedidoId) async {
    final r = await supa.from('citas').select(_selCita).eq('pedido_id', pedidoId).order('fecha_hora', ascending: true);
    return r.map(Cita.desde).toList();
  }

  static Future<void> crearCita({
    int? clienteId,
    int? pedidoId,
    required DateTime fechaHora,
    required String motivo,
    String direccion = '',
    String notas = '',
  }) => supa.from('citas').insert({
    'carpinteria_id': _miCarpinteria,
    'cliente_id': clienteId,
    'pedido_id': pedidoId,
    'fecha_hora': fechaHora.toUtc().toIso8601String(),
    'motivo': motivo,
    'direccion': direccion,
    'notas': notas,
    'estado': 'confirmada',
  });

  static Future<void> actualizarCita(int id, Map<String, dynamic> cambios) =>
      supa.from('citas').update(cambios).eq('id', id);

  static Future<void> borrarCita(int id) => supa.from('citas').delete().eq('id', id);

  // ================================================================
  // Cotizaciones
  // ================================================================
  static const _selCot = '*, cotizacion_partidas(*), pedidos(*, clientes(*), carpinterias(*))';

  static Future<Cotizacion?> cotizacionDePedido(int pedidoId) async {
    final r = await supa
        .from('cotizaciones')
        .select(_selCot)
        .eq('pedido_id', pedidoId)
        .order('created_at', ascending: false)
        .limit(1);
    return r.isEmpty ? null : Cotizacion.desde(r.first);
  }

  static Future<Cotizacion> cotizacion(int id) async =>
      Cotizacion.desde(await supa.from('cotizaciones').select(_selCot).eq('id', id).single());

  static Future<List<Cotizacion>> cotizacionesCarpinteria() async {
    final r = await supa
        .from('cotizaciones')
        .select(_selCot)
        .eq('carpinteria_id', _miCarpinteria)
        .order('updated_at', ascending: false);
    return r.map(Cotizacion.desde).toList();
  }

  /// Crea o actualiza la cotización y reemplaza sus partidas.
  static Future<Cotizacion> guardarCotizacion({
    int? id,
    required int pedidoId,
    required double manoObra,
    required double costosAdicionales,
    required String notas,
    required List<Partida> partidas,
  }) async {
    final datos = {
      'pedido_id': pedidoId,
      'carpinteria_id': _miCarpinteria,
      'mano_obra': manoObra,
      'costos_adicionales': costosAdicionales,
      'notas': notas,
    };
    int cotId;
    if (id == null) {
      final r = await supa.from('cotizaciones').insert({...datos, 'estado': 'borrador'}).select('id').single();
      cotId = r['id'] as int;
    } else {
      await supa.from('cotizaciones').update(datos).eq('id', id);
      cotId = id;
      await supa.from('cotizacion_partidas').delete().eq('cotizacion_id', cotId);
    }
    final validas = partidas.where((p) => p.concepto.trim().isNotEmpty && p.cantidad > 0).toList();
    if (validas.isNotEmpty) {
      await supa.from('cotizacion_partidas').insert(validas.map((p) => p.aMapa(cotId)).toList());
    }
    return cotizacion(cotId);
  }

  static Future<void> marcarCotizacionEnviada(Cotizacion c, String pdfPath) async {
    await supa
        .from('cotizaciones')
        .update({
          'estado': 'enviada',
          'pdf_path': pdfPath,
          'enviada_at': DateTime.now().toUtc().toIso8601String(),
          'comentario_cliente': '',
        })
        .eq('id', c.id);
    await actualizarPedido(c.pedidoId, {'estado': 'cotizado'});
  }

  static Future<void> responderCotizacion(int id, String respuesta, String comentario) => supa.rpc(
    'responder_cotizacion',
    params: {'p_cotizacion': id, 'p_respuesta': respuesta, 'p_comentario': comentario},
  );

  // ================================================================
  // Avances y fotos
  // ================================================================
  static Future<List<Avance>> avances(int pedidoId) async {
    final r = await supa.from('avances').select().eq('pedido_id', pedidoId).order('created_at', ascending: false);
    return r.map(Avance.desde).toList();
  }

  static Future<void> agregarNota(Pedido p, String nota) =>
      supa.from('avances').insert({'pedido_id': p.id, 'estado': p.estado, 'progreso': p.progreso, 'nota': nota});

  static Future<List<Foto>> fotos(int pedidoId) async {
    final r = await supa.from('fotos').select().eq('pedido_id', pedidoId).order('created_at', ascending: false);
    return r.map(Foto.desde).toList();
  }

  static Future<void> subirFoto({
    required Pedido pedido,
    required Uint8List bytes,
    String tipo = 'referencia',
    String descripcion = '',
    String descripcionIa = '',
  }) async {
    final ruta = '${pedido.carpinteriaId}/${pedido.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supa.storage
        .from('fotos')
        .uploadBinary(ruta, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    await supa.from('fotos').insert({
      'pedido_id': pedido.id,
      'path': ruta,
      'tipo': tipo,
      'descripcion': descripcion,
      'descripcion_ia': descripcionIa,
    });
  }

  static Future<void> borrarFoto(Foto f) async {
    await supa.storage.from('fotos').remove([f.path]);
    await supa.from('fotos').delete().eq('id', f.id);
  }

  static final _urls = <String, (String, DateTime)>{};

  /// URL temporal para archivos privados (se guarda 50 min en memoria).
  static Future<String> urlFirmada(String bucket, String ruta) async {
    final clave = '$bucket/$ruta';
    final guardada = _urls[clave];
    if (guardada != null && guardada.$2.isAfter(DateTime.now())) return guardada.$1;
    final url = await supa.storage.from(bucket).createSignedUrl(ruta, 3600);
    _urls[clave] = (url, DateTime.now().add(const Duration(minutes: 50)));
    return url;
  }

  static String urlPublica(String bucket, String ruta) => supa.storage.from(bucket).getPublicUrl(ruta);

  static Future<Uint8List> descargar(String bucket, String ruta) => supa.storage.from(bucket).download(ruta);

  static Future<String> subirPdfCotizacion(Cotizacion c, Uint8List pdf) async {
    final ruta = '${c.carpinteriaId}/${c.pedidoId}/${c.folio}.pdf';
    await supa.storage
        .from('cotizaciones')
        .uploadBinary(ruta, pdf, fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
    _urls.remove('cotizaciones/$ruta');
    return ruta;
  }

  // ================================================================
  // Clientes
  // ================================================================
  static Future<List<Cliente>> clientes() async {
    final r = await supa
        .from('clientes')
        .select('*, pedidos(count)')
        .eq('carpinteria_id', _miCarpinteria)
        .order('nombre', ascending: true);
    return r.map(Cliente.desde).toList();
  }

  static Future<Cliente> guardarCliente(int? id, Map<String, dynamic> datos) async {
    final r = id == null
        ? await supa.from('clientes').insert({...datos, 'carpinteria_id': _miCarpinteria}).select().single()
        : await supa.from('clientes').update(datos).eq('id', id).select().single();
    return Cliente.desde(r);
  }

  static Future<void> borrarCliente(int id) => supa.from('clientes').delete().eq('id', id);

  // ================================================================
  // Carpinterías, catálogo y favoritos
  // ================================================================
  static Future<List<Carpinteria>> carpinterias() async {
    final r = await supa.from('carpinterias').select('*, calificaciones(estrellas)').order('nombre', ascending: true);
    return r.map(Carpinteria.desde).toList();
  }

  static Future<List<ItemCatalogo>> catalogo({String? carpinteriaId, bool soloPublicados = true}) async {
    var q = supa.from('catalogo').select('*, carpinterias(nombre)');
    if (carpinteriaId != null) q = q.eq('carpinteria_id', carpinteriaId);
    if (soloPublicados) q = q.eq('publicado', true);
    final r = await q.order('created_at', ascending: false);
    return r.map(ItemCatalogo.desde).toList();
  }

  static Future<void> guardarItemCatalogo(ItemCatalogo? item, Map<String, dynamic> datos) async {
    if (item == null) {
      await supa.from('catalogo').insert({...datos, 'carpinteria_id': _miCarpinteria});
    } else {
      await supa.from('catalogo').update(datos).eq('id', item.id);
    }
  }

  static Future<void> borrarItemCatalogo(ItemCatalogo item) async {
    if (item.imagenPath != null) await supa.storage.from('catalogo').remove([item.imagenPath!]);
    await supa.from('catalogo').delete().eq('id', item.id);
  }

  static Future<String> subirImagenCatalogo(Uint8List bytes) async {
    final ruta = '$_miCarpinteria/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supa.storage
        .from('catalogo')
        .uploadBinary(ruta, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return ruta;
  }

  static Future<Set<int>> favoritos() async {
    final r = await supa.from('favoritos').select('catalogo_id').eq('perfil_id', miId!);
    return r.map((e) => e['catalogo_id'] as int).toSet();
  }

  static Future<void> cambiarFavorito(int catalogoId, bool marcar) async {
    if (marcar) {
      await supa.from('favoritos').upsert({'perfil_id': miId, 'catalogo_id': catalogoId});
    } else {
      await supa.from('favoritos').delete().eq('perfil_id', miId!).eq('catalogo_id', catalogoId);
    }
  }

  // ================================================================
  // Taller: inventario, proveedores y gastos
  // ================================================================
  static Future<List<ItemInventario>> inventario(String tipo) async {
    final r = await supa
        .from('inventario')
        .select()
        .eq('carpinteria_id', _miCarpinteria)
        .eq('tipo', tipo)
        .order('nombre', ascending: true);
    return r.map(ItemInventario.desde).toList();
  }

  static Future<void> guardarInventario(int? id, Map<String, dynamic> datos) => id == null
      ? supa.from('inventario').insert({...datos, 'carpinteria_id': _miCarpinteria})
      : supa.from('inventario').update(datos).eq('id', id);

  static Future<void> borrarInventario(int id) => supa.from('inventario').delete().eq('id', id);

  static Future<List<Proveedor>> proveedores(String tipo) async {
    final r = await supa.from('proveedores').select().eq('tipo', tipo).order('nombre', ascending: true);
    final lista = r.map(Proveedor.desde).toList();
    // Primero los propios del taller, luego el directorio general.
    lista.sort((a, b) => a.esPropio == b.esPropio ? a.nombre.compareTo(b.nombre) : (a.esPropio ? -1 : 1));
    return lista;
  }

  static Future<void> guardarProveedor(int? id, Map<String, dynamic> datos) => id == null
      ? supa.from('proveedores').insert({...datos, 'carpinteria_id': _miCarpinteria})
      : supa.from('proveedores').update(datos).eq('id', id);

  static Future<void> borrarProveedor(int id) => supa.from('proveedores').delete().eq('id', id);

  static Future<List<Gasto>> gastos(DateTime? desde) async {
    var q = supa.from('gastos').select().eq('carpinteria_id', _miCarpinteria);
    if (desde != null) q = q.gte('fecha', desde.toIso8601String().substring(0, 10));
    final r = await q.order('fecha', ascending: false);
    return r.map(Gasto.desde).toList();
  }

  static Future<void> agregarGasto(String concepto, String categoria, double monto, DateTime fecha) =>
      supa.from('gastos').insert({
        'carpinteria_id': _miCarpinteria,
        'concepto': concepto,
        'categoria': categoria,
        'monto': monto,
        'fecha': fecha.toIso8601String().substring(0, 10),
      });

  static Future<void> borrarGasto(int id) => supa.from('gastos').delete().eq('id', id);

  // ================================================================
  // Mensajes
  // ================================================================
  static Future<List<Mensaje>> mensajes(String carpinteriaId, String clientePerfilId) async {
    final r = await supa
        .from('mensajes')
        .select()
        .eq('carpinteria_id', carpinteriaId)
        .eq('cliente_perfil_id', clientePerfilId)
        .order('created_at', ascending: true)
        .limit(300);
    return r.map(Mensaje.desde).toList();
  }

  static Future<void> enviarMensaje({
    required String carpinteriaId,
    required String clientePerfilId,
    String texto = '',
    Uint8List? foto,
  }) async {
    String? ruta;
    if (foto != null) {
      ruta = '$carpinteriaId/$clientePerfilId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supa.storage
          .from('mensajes')
          .uploadBinary(ruta, foto, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    }
    await supa.from('mensajes').insert({
      'carpinteria_id': carpinteriaId,
      'cliente_perfil_id': clientePerfilId,
      'texto': texto.trim(),
      'foto_path': ruta,
    });
  }

  static Future<void> marcarLeidos(String carpinteriaId, String clientePerfilId) => supa
      .from('mensajes')
      .update({'leido': true})
      .eq('carpinteria_id', carpinteriaId)
      .eq('cliente_perfil_id', clientePerfilId)
      .neq('autor_id', miId!)
      .eq('leido', false);

  static RealtimeChannel escucharMensajes(
    String carpinteriaId,
    String clientePerfilId,
    void Function(Mensaje) alLlegar,
  ) {
    return supa
        .channel('chat-$carpinteriaId-$clientePerfilId-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensajes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'cliente_perfil_id',
            value: clientePerfilId,
          ),
          callback: (p) {
            final m = Mensaje.desde(p.newRecord);
            if (m.carpinteriaId == carpinteriaId) alLlegar(m);
          },
        )
        .subscribe();
  }

  static Future<List<Conversacion>> conversaciones() async {
    final esCarp = sesion.esCarpintero;
    var q = supa.from('mensajes').select();
    q = esCarp ? q.eq('carpinteria_id', _miCarpinteria) : q.eq('cliente_perfil_id', miId!);
    final r = await q.order('created_at', ascending: false).limit(500);
    final msgs = r.map(Mensaje.desde).toList();

    final nombres = <String, String>{};
    if (esCarp) {
      final cs = await supa
          .from('clientes')
          .select('perfil_id, nombre')
          .eq('carpinteria_id', _miCarpinteria)
          .not('perfil_id', 'is', null);
      for (final c in cs) {
        nombres[c['perfil_id'] as String] = c['nombre'] as String;
      }
    } else {
      final ks = await supa.from('carpinterias').select('id, nombre');
      for (final k in ks) {
        nombres[k['id'] as String] = k['nombre'] as String;
      }
    }

    final porClave = <String, Conversacion>{};
    final sinLeer = <String, int>{};
    for (final m in msgs) {
      final clave = esCarp ? m.clientePerfilId : m.carpinteriaId;
      if (!m.leido && m.autorId != miId) sinLeer[clave] = (sinLeer[clave] ?? 0) + 1;
      porClave.putIfAbsent(
        clave,
        () => Conversacion(
          carpinteriaId: m.carpinteriaId,
          clientePerfilId: m.clientePerfilId,
          titulo: nombres[clave] ?? (esCarp ? 'Cliente' : 'Carpintería'),
          ultimo: m.texto.isNotEmpty ? m.texto : '📷 Foto',
          fecha: m.fecha,
          sinLeer: 0,
        ),
      );
    }
    return porClave.entries
        .map(
          (e) => Conversacion(
            carpinteriaId: e.value.carpinteriaId,
            clientePerfilId: e.value.clientePerfilId,
            titulo: e.value.titulo,
            ultimo: e.value.ultimo,
            fecha: e.value.fecha,
            sinLeer: sinLeer[e.key] ?? 0,
          ),
        )
        .toList();
  }

  // ================================================================
  // Notificaciones
  // ================================================================
  static Future<List<Notificacion>> notificaciones() async {
    final r = await supa
        .from('notificaciones')
        .select()
        .eq('usuario_id', miId!)
        .order('created_at', ascending: false)
        .limit(100);
    return r.map(Notificacion.desde).toList();
  }

  static Future<int> notificacionesSinLeer() async {
    final r = await supa.from('notificaciones').select('id').eq('usuario_id', miId!).eq('leida', false);
    return r.length;
  }

  static Future<void> marcarNotificacionesLeidas() =>
      supa.from('notificaciones').update({'leida': true}).eq('usuario_id', miId!).eq('leida', false);

  static RealtimeChannel escucharNotificaciones(void Function(Notificacion) alLlegar) {
    return supa
        .channel('notif-${miId!}-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'usuario_id', value: miId!),
          callback: (p) => alLlegar(Notificacion.desde(p.newRecord)),
        )
        .subscribe();
  }

  // ================================================================
  // Calificaciones
  // ================================================================
  static Future<void> calificar(int pedidoId, int estrellas, String opinion) =>
      supa.rpc('calificar_pedido', params: {'p_pedido': pedidoId, 'p_estrellas': estrellas, 'p_opinion': opinion});

  static Future<Map<String, dynamic>?> calificacionDe(int pedidoId) =>
      supa.from('calificaciones').select().eq('pedido_id', pedidoId).maybeSingle();

  static Future<List<Map<String, dynamic>>> calificacionesDe(String carpinteriaId) =>
      supa.from('calificaciones').select().eq('carpinteria_id', carpinteriaId).order('created_at', ascending: false);

  // ================================================================
  // Base de conocimiento (CarpiIA)
  // ================================================================
  static Future<List<FichaConocimiento>> buscarConocimiento(String consulta, String publico, {int limite = 4}) async {
    final r = await supa.rpc(
      'buscar_conocimiento',
      params: {'p_consulta': consulta, 'p_publico': publico, 'p_limite': limite},
    );
    return (r as List).map((e) => FichaConocimiento.desde(e as Map<String, dynamic>)).toList();
  }
}
