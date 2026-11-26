import 'package:carpiapp/core/formato.dart';
import 'package:carpiapp/ia/carpi_ia.dart';
import 'package:carpiapp/modelos/modelos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Pedido _pedido({
  String tipo = 'Clóset',
  String material = 'Melamina blanca',
  double? alto,
  double? ancho,
  double? fondo,
  String estado = 'en_cotizacion',
}) => Pedido.desde({
  'id': 24,
  'carpinteria_id': 'k1',
  'cliente_id': 7,
  'titulo': tipo,
  'tipo_mueble': tipo,
  'material_acabado': material,
  'estado': estado,
  'progreso': 0,
  'alto_cm': alto,
  'ancho_cm': ancho,
  'fondo_cm': fondo,
  'created_at': '2026-11-20T10:00:00Z',
  'updated_at': '2026-11-21T10:00:00Z',
  'clientes': {'id': 7, 'carpinteria_id': 'k1', 'nombre': 'Ana Torres'},
});

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  group('Formato', () {
    test('dinero en pesos mexicanos', () {
      expect(dinero(12800), r'$12,800.00');
      expect(dineroCorto(3500), r'$3,500');
    });

    test('plurales en cantidades y conteos', () {
      expect(cantidadCon(3, 'hoja'), '3 hojas');
      expect(cantidadCon(1, 'hoja'), '1 hoja');
      expect(cantidadCon(2.5, 'litro'), '2.5 litros');
      expect(cantidadCon(4, 'pza'), '4 pza');
      expect(cantidadCon(2, 'galón'), '2 galones');
      expect(cantidadCon(2, 'par'), '2 pares');
      expect(contar(1, 'registro'), '1 registro');
      expect(contar(3, 'reseña'), '3 reseñas');
    });

    test('convierte texto a número', () {
      expect(aNumero('1,250.50'), 1250.5);
      expect(aNumero('75,5'), 75.5);
      expect(aNumero(r'$ 3,500.00'), 3500);
      expect(aNumero('abc'), isNull);
    });

    test('iniciales y primer nombre', () {
      expect(iniciales('Ana Torres'), 'AT');
      expect(primerNombre('  Mario Alberto Andrade '), 'Mario');
    });

    test('mensajes de error legibles', () {
      expect(
        mensajeError(Exception('AuthApiException(message: Invalid login credentials, statusCode: 400)')),
        'Correo o contraseña incorrectos.',
      );
    });
  });

  group('Modelos', () {
    test('folio y medidas del pedido', () {
      final p = _pedido(alto: 75, ancho: 120, fondo: 80);
      expect(p.folio, 'P-0024');
      expect(p.tieneMedidas, isTrue);
      expect(p.medidasTexto, 'Alto 75 cm · Ancho 120 cm · Fondo 80 cm');
      expect(p.cliente?.nombre, 'Ana Torres');
    });

    test('total de la cotización como en el mockup (12,800)', () {
      final c = Cotizacion.desde({
        'id': 24,
        'pedido_id': 24,
        'carpinteria_id': 'k1',
        'costo_materiales': 8500,
        'mano_obra': 3500,
        'costos_adicionales': 800,
        'estado': 'enviada',
        'created_at': '2026-10-12T10:00:00Z',
        'cotizacion_partidas': [
          {'id': 1, 'concepto': 'Encino', 'cantidad': 2, 'unidad': 'tabla', 'precio_unitario': 4250},
        ],
      });
      expect(c.total, 12800);
      expect(c.folio, 'COT-024');
      expect(c.partidas.single.importe, 8500);
    });

    test('estados del pedido', () {
      expect(EstadoPedido.de('cotizado').etiqueta, 'Cotización enviada');
      expect(EstadoPedido.de('en_fabricacion').paso, 3);
      expect(EstadoPedido.de('desconocido').clave, 'solicitado');
    });

    test('modelo 3D según el mueble', () {
      expect(modeloMueble('Clóset'), 'closet');
      expect(modeloMueble('Mesa de comedor'), 'mesa');
      expect(modeloMueble('Mueble de TV'), 'mueble_tv');
    });
  });

  group('CarpiIA', () {
    test('normaliza acentos', () {
      expect(CarpiIA.normalizar('¿Qué MADERA resiste el comején?'), '¿que madera resiste el comejen?');
    });

    test('detecta datos faltantes del pedido', () {
      final h = CarpiIA.revisarPedido(_pedido(material: '', alto: 240), fotos: 0);
      final pendientes = h.where((x) => !x.ok).map((x) => x.texto).join(' | ');
      expect(pendientes, contains('material'));
      expect(pendientes, contains('ancho'));
      expect(pendientes, contains('fondo'));
      expect(pendientes, contains('fotos'));
    });

    test('avisa medidas poco usuales', () {
      final h = CarpiIA.revisarPedido(_pedido(alto: 240, ancho: 180, fondo: 120), fotos: 2);
      expect(h.any((x) => !x.ok && x.texto.contains('fondo')), isTrue);
    });

    test('al cliente no le confirma precios ni fechas', () async {
      final ia = CarpiIA(rol: 'cliente');
      final r = await ia.responder('¿Cuánto cuesta un clóset y cuándo me lo entregan?');
      expect(r.texto, contains('no lo puedo confirmar'));
      expect(r.texto, contains('el precio'));
      expect(r.texto, contains('la fecha de entrega'));
    });

    test('arma el borrador de solicitud paso a paso', () async {
      final ia = CarpiIA(rol: 'cliente');
      var r = await ia.responder('Quiero un mueble');
      expect(ia.armandoSolicitud, isTrue);
      r = await ia.responder('Clóset');
      r = await ia.responder('Recámara');
      r = await ia.responder('Melamina blanca');
      r = await ia.responder('Dos puertas corredizas y cajones');
      expect(ia.armandoSolicitud, isFalse);
      expect(r.borrador, isNotNull);
      expect(r.borrador!.tipo, 'Clóset');
      expect(r.borrador!.resumen, 'Clóset · Uso: recámara · Melamina blanca');
    });

    test('no vuelve a preguntar lo que el cliente ya dijo', () async {
      final ia = CarpiIA(rol: 'cliente');
      var r = await ia.responder('Quiero un librero de pino para la sala');
      expect(r.texto, contains('para sala de pino'));
      expect(r.texto, contains('cómo lo imaginas'));
      r = await ia.responder('listo');
      expect(r.borrador!.resumen, 'Librero · Uso: sala · Pino');
    });

    test('sin preferencia de material no lo deja en el resumen', () async {
      final ia = CarpiIA(rol: 'cliente');
      await ia.responder('Necesito una mesa para el comedor');
      await ia.responder('Aún no lo sé');
      final r = await ia.responder('listo');
      expect(r.borrador!.resumen, 'Mesa de comedor · Uso: comedor');
    });

    test('estima tableros para el carpintero', () async {
      final ia = CarpiIA(rol: 'carpintero');
      final r = await ia.responder('¿Cuántos tableros necesito para 10 m2?');
      expect(r.texto, contains('4 tableros'));
    });
  });
}
