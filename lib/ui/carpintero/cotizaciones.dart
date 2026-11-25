import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../../core/formato.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../modelos/modelos.dart';
import '../../pdf/cotizacion_pdf.dart';
import '../comunes/widgets.dart';
import 'pedidos_carpintero.dart';

// =====================================================================
// Lista de cotizaciones
// =====================================================================
class CotizacionesPantalla extends StatefulWidget {
  const CotizacionesPantalla({super.key});

  @override
  State<CotizacionesPantalla> createState() => _CotizacionesPantallaState();
}

class _CotizacionesPantallaState extends State<CotizacionesPantalla> {
  int _tab = 0;
  final _clave = GlobalKey<CargadorState<List<Cotizacion>>>();
  static const _tabs = ['Todas', 'Borradores', 'Enviadas', 'Aceptadas', 'Con ajustes'];
  static const _estados = [null, 'borrador', 'enviada', 'aceptada', 'ajustes'];

  @override
  Widget build(BuildContext context) => PantallaBase(
        seccion: 'Cotizaciones',
        titulo: 'Cotizaciones',
        subtitulo: 'Arma, envía y da seguimiento a tus presupuestos',
        acciones: [
          BotonCirculo(Icons.add, () async {
            final id = await nuevoPedido(context);
            if (id == null || !context.mounted) return;
            final p = await Api.pedido(id);
            if (!context.mounted) return;
            await ir(context, EditorCotizacion(pedido: p));
            _clave.currentState?.recargar();
          }, ayuda: 'Nueva cotización'),
        ],
        cuerpo: Column(children: [
          Pildoras(_tabs, _tab, (i) => setState(() => _tab = i)),
          const SizedBox(height: 10),
          Expanded(
            child: Cargador<List<Cotizacion>>(
              key: _clave,
              cargar: Api.cotizacionesCarpinteria,
              construir: (c, lista, recargar) {
                final filtro = _estados[_tab];
                final l = filtro == null ? lista : lista.where((x) => x.estado == filtro).toList();
                if (l.isEmpty) {
                  return const Vacio(Icons.request_quote_outlined, 'Sin cotizaciones aquí',
                      detalle: 'Crea una desde un pedido o con el botón +.');
                }
                return RefreshIndicator.adaptive(
                  onRefresh: recargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: l.length,
                    itemBuilder: (_, i) {
                      final q = l[i];
                      final cs = Theme.of(c).colorScheme;
                      return Tarjeta(
                        alTocar: () async {
                          await ir(c, CotizacionLista(q.id));
                          recargar();
                        },
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${q.folio} · ${q.pedido?.titulo ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(q.pedido?.cliente?.nombre ?? '', style: TextStyle(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              ChipEstado(q.estadoTexto, q.estadoColor),
                            ]),
                          ),
                          Text(dinero(q.total),
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cs.primary)),
                        ]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      );
}

// =====================================================================
// Editor de cotización · 4 pasos
// =====================================================================
class EditorCotizacion extends StatefulWidget {
  final Pedido pedido;
  final Cotizacion? cotizacion;
  const EditorCotizacion({required this.pedido, this.cotizacion, super.key});

  @override
  State<EditorCotizacion> createState() => _EditorCotizacionState();
}

class _EditorCotizacionState extends State<EditorCotizacion> {
  static const _pasos = ['Cliente', 'Proyecto', 'Costos', 'Resumen'];
  int _paso = 0;
  bool _guardando = false;

  late String _tipo = tiposMueble.contains(widget.pedido.tipoMueble) ? widget.pedido.tipoMueble : 'Otro';
  late final _material = TextEditingController(text: widget.pedido.materialAcabado);
  late final _alto = TextEditingController(text: widget.pedido.alto == null ? '' : numeroCorto(widget.pedido.alto));
  late final _ancho = TextEditingController(text: widget.pedido.ancho == null ? '' : numeroCorto(widget.pedido.ancho));
  late final _fondo = TextEditingController(text: widget.pedido.fondo == null ? '' : numeroCorto(widget.pedido.fondo));
  late final _manoObra = TextEditingController(
      text: widget.cotizacion == null ? '' : widget.cotizacion!.manoObra.toStringAsFixed(2));
  late final _adicionales = TextEditingController(
      text: widget.cotizacion == null ? '' : widget.cotizacion!.costosAdicionales.toStringAsFixed(2));
  late final _notas = TextEditingController(text: widget.cotizacion?.notas ?? '');
  late final List<Partida> _partidas = widget.cotizacion?.partidas
          .map((p) => Partida(concepto: p.concepto, cantidad: p.cantidad, unidad: p.unidad, precioUnitario: p.precioUnitario))
          .toList() ??
      [];

  double get _materiales => _partidas.fold(0, (s, p) => s + p.importe);
  double get _mo => aNumero(_manoObra.text) ?? 0;
  double get _extra => aNumero(_adicionales.text) ?? 0;

  Future<void> _guardar() async {
    if (_materiales + _mo + _extra <= 0) {
      avisar(context, 'Agrega al menos un costo.', error: true);
      setState(() => _paso = 2);
      return;
    }
    setState(() => _guardando = true);
    try {
      final p = widget.pedido;
      await Api.actualizarPedido(p.id, {
        'tipo_mueble': _tipo,
        'material_acabado': _material.text.trim(),
        'alto_cm': aNumero(_alto.text),
        'ancho_cm': aNumero(_ancho.text),
        'fondo_cm': aNumero(_fondo.text),
        if (p.medidasRegistradasAt == null && aNumero(_alto.text) != null)
          'medidas_registradas_at': DateTime.now().toUtc().toIso8601String(),
        if (['solicitado', 'cita_agendada', 'ajustes_solicitados'].contains(p.estado)) 'estado': 'en_cotizacion',
      });
      final cot = await Api.guardarCotizacion(
        id: widget.cotizacion?.id,
        pedidoId: p.id,
        manoObra: _mo,
        costosAdicionales: _extra,
        notas: _notas.text.trim(),
        partidas: _partidas,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => CotizacionLista(cot.id)));
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarPartida([Partida? existente]) async {
    final concepto = TextEditingController(text: existente?.concepto ?? '');
    final cantidad = TextEditingController(text: existente == null ? '1' : numeroCorto(existente.cantidad));
    final unidad = TextEditingController(text: existente?.unidad ?? 'pza');
    final precio = TextEditingController(text: existente == null ? '' : existente.precioUnitario.toStringAsFixed(2));
    const n = TextInputType.numberWithOptions(decimal: true);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (d) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(d).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(existente == null ? 'Agregar material' : 'Editar material',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Campo('Concepto', concepto, pista: 'Ej. Melamina blanca 16 mm'),
            Row(children: [
              Expanded(child: Campo('Cantidad', cantidad, teclado: n)),
              const SizedBox(width: 8),
              Expanded(child: Campo('Unidad', unidad)),
            ]),
            Campo('Precio unitario', precio, teclado: n, prefijo: const Icon(Icons.attach_money)),
            BotonPrincipal('Guardar', () => Navigator.pop(d, true)),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final c = aNumero(cantidad.text) ?? 0, pr = aNumero(precio.text) ?? 0;
    if (concepto.text.trim().isEmpty || c <= 0 || pr < 0) {
      if (mounted) avisar(context, 'Revisa el concepto, la cantidad y el precio.', error: true);
      return;
    }
    setState(() {
      final nueva = Partida(concepto: concepto.text.trim(), cantidad: c, unidad: unidad.text.trim().isEmpty ? 'pza' : unidad.text.trim(), precioUnitario: pr);
      if (existente == null) {
        _partidas.add(nueva);
      } else {
        _partidas[_partidas.indexOf(existente)] = nueva;
      }
    });
  }

  Future<void> _desdeInventario() async {
    final items = await Api.inventario('material');
    if (!mounted) return;
    if (items.isEmpty) {
      avisar(context, 'Tu inventario de materiales está vacío.');
      return;
    }
    final elegido = await showModalBottomSheet<ItemInventario>(
      context: context,
      builder: (d) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Elegir del inventario', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          for (final i in items)
            ListTile(
              title: Text(i.nombre),
              subtitle: Text('${numeroCorto(i.cantidad)} ${i.unidad} disponibles · ${dinero(i.costoUnitario)}/${i.unidad}'),
              onTap: () => Navigator.pop(d, i),
            ),
        ]),
      ),
    );
    if (elegido != null) {
      await _agregarPartida(Partida(concepto: elegido.nombre, unidad: elegido.unidad, precioUnitario: elegido.costoUnitario));
    }
  }

  Widget _cuerpo() {
    final p = widget.pedido;
    final cs = Theme.of(context).colorScheme;
    switch (_paso) {
      case 0:
        final c = p.cliente;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Etiqueta('Cliente'),
          Tarjeta(
            child: Row(children: [
              Avatar(c?.nombre ?? '?'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c?.nombre ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if ((c?.telefono ?? '').isNotEmpty) Text(c!.telefono),
                  if ((c?.direccion ?? '').isNotEmpty) Text(c!.direccion, style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
          const Etiqueta('Pedido'),
          Tarjeta(child: Text('${p.folio} · ${p.titulo}', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]);
      case 1:
        const n = TextInputType.numberWithOptions(decimal: true);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Seleccion<String>(
            etiqueta: 'Tipo de mueble',
            valor: _tipo,
            opciones: tiposMueble,
            texto: (x) => x,
            alCambiar: (v) => setState(() => _tipo = v ?? _tipo),
          ),
          Campo('Material y acabado', _material, pista: 'Ej. Encino · Barniz natural'),
          const Etiqueta('Medidas tomadas en la cita (cm)'),
          Row(children: [
            Expanded(child: Campo('Alto', _alto, teclado: n)),
            const SizedBox(width: 8),
            Expanded(child: Campo('Ancho', _ancho, teclado: n)),
            const SizedBox(width: 8),
            Expanded(child: Campo('Fondo', _fondo, teclado: n)),
          ]),
          if (_alto.text.isEmpty)
            const Aviso.alerta('El carpintero mide y registra las medidas tras la cita. Puedes guardar la cotización y completarlas después.'),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Etiqueta('Materiales'),
          if (_partidas.isEmpty)
            const Tarjeta(child: Text('Agrega los materiales del despiece: tableros, herrajes, tapacanto, acabados…')),
          for (final pa in _partidas)
            Tarjeta(
              alTocar: () => _agregarPartida(pa),
              relleno: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pa.concepto, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${numeroCorto(pa.cantidad)} ${pa.unidad} × ${dinero(pa.precioUnitario)}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ]),
                ),
                Text(dinero(pa.importe), style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _partidas.remove(pa)),
                ),
              ]),
            ),
          Row(children: [
            Expanded(child: BotonSecundario('Agregar material', _agregarPartida, icono: Icons.add)),
            const SizedBox(width: 8),
            Expanded(child: BotonSecundario('Del inventario', _desdeInventario, icono: Icons.inventory_outlined)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Campo('Mano de obra', _manoObra,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  prefijo: const Icon(Icons.attach_money),
                  alCambiar: (_) => setState(() {})),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Campo('Costos adicionales', _adicionales,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  prefijo: const Icon(Icons.attach_money),
                  pista: 'Herrajes, flete…',
                  alCambiar: (_) => setState(() {})),
            ),
          ]),
          Text('Materiales: ${dinero(_materiales)}  ·  Total: ${dinero(_materiales + _mo + _extra)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ResumenCostos(_materiales, _mo, _extra),
          Campo('Notas', _notas,
              lineas: 4, pista: 'Vigencia, anticipo, tiempos de entrega, garantía, qué incluye la instalación…'),
          const Aviso('Al guardar podrás revisar el PDF y enviarlo al cliente.', icono: Icons.picture_as_pdf_outlined),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) => PantallaBase(
        seccion: 'Cotizaciones',
        titulo: widget.cotizacion == null ? 'Nueva cotización' : 'Editar ${widget.cotizacion!.folio}',
        subtitulo: 'Completa los datos del proyecto',
        cuerpo: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Pasos(_pasos, _paso),
          const SizedBox(height: 18),
          _cuerpo(),
        ]),
        pie: Row(children: [
          if (_paso > 0)
            Expanded(child: BotonSecundario('Atrás', () => setState(() => _paso--))),
          if (_paso > 0) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: BotonPrincipal(
              _paso < 3 ? 'Siguiente' : 'Guardar cotización',
              _paso < 3 ? () => setState(() => _paso++) : _guardar,
              cargando: _guardando,
            ),
          ),
        ]),
      );
}

// =====================================================================
// Cotización lista: PDF, enviar e imprimir
// =====================================================================
class CotizacionLista extends StatefulWidget {
  final int cotizacionId;
  const CotizacionLista(this.cotizacionId, {super.key});

  @override
  State<CotizacionLista> createState() => _CotizacionListaState();
}

class _CotizacionListaState extends State<CotizacionLista> {
  final _clave = GlobalKey<CargadorState<Cotizacion>>();

  Future<Uint8List> _pdf(Cotizacion c) => generarPdfCotizacion(c, c.pedido!, sesion.carpinteria!);

  @override
  Widget build(BuildContext context) => PantallaBase(
        seccion: 'Cotizaciones',
        cuerpo: Cargador<Cotizacion>(
          key: _clave,
          cargar: () => Api.cotizacion(widget.cotizacionId),
          construir: (c, cot, recargar) {
            final p = cot.pedido!;
            final cs = Theme.of(c).colorScheme;
            final enviada = cot.estado != 'borrador' && cot.estado != 'ajustes';
            return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
              Text(enviada ? 'Cotización ${cot.estadoTexto.toLowerCase()}' : 'Cotización lista',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text('${cot.folio} · ${(p.cliente?.nombre ?? '').toUpperCase()}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: .4)),
              const SizedBox(height: 8),
              ChipEstado(enviada ? cot.estadoTexto : 'Lista para entregar', cot.estadoColor),
              const SizedBox(height: 14),
              Tarjeta(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Dato('Cliente', p.cliente?.nombre ?? ''),
                  Dato('Proyecto', [p.tipoMueble, p.materialAcabado].where((s) => s.isNotEmpty).join(' · ')),
                ]),
              ),
              Tarjeta(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Etiqueta('Medidas tomadas en la cita'),
                  Text(p.medidasTexto, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Registradas por el carpintero', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ),
              if (cot.partidas.isNotEmpty)
                Tarjeta(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Etiqueta('Materiales'),
                    for (final pa in cot.partidas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(child: Text('${pa.concepto} (${numeroCorto(pa.cantidad)} ${pa.unidad})')),
                          Text(dinero(pa.importe)),
                        ]),
                      ),
                  ]),
                ),
              ResumenCostos(cot.costoMateriales, cot.manoObra, cot.costosAdicionales),
              if (cot.notas.isNotEmpty) Tarjeta(child: Dato('Notas', cot.notas)),
              if (cot.estado == 'ajustes' && cot.comentarioCliente.isNotEmpty)
                Aviso.alerta('“${cot.comentarioCliente}”', titulo: 'EL CLIENTE PIDE AJUSTES'),
              if (cot.estado == 'rechazada' && cot.comentarioCliente.isNotEmpty)
                Aviso.alerta('“${cot.comentarioCliente}”', titulo: 'MOTIVO DEL RECHAZO'),
              Text(
                  enviada
                      ? 'El cliente ya tiene esta cotización en PDF${cot.enviadaAt == null ? '' : ' desde el ${fechaCorta(cot.enviadaAt!)}'}.'
                      : 'El cliente recibirá esta cotización en PDF. Puedes descargarla, enviarla o imprimirla.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 14),
              BotonSecundario('Descargar PDF', () async {
                final bytes = await _pdf(cot);
                await Printing.sharePdf(bytes: bytes, filename: 'Cotizacion-${cot.folio}.pdf');
              }, icono: Icons.download_outlined),
              const SizedBox(height: 10),
              if (!enviada || cot.estado == 'enviada')
                BotonPrincipal(enviada ? 'Reenviar PDF al cliente' : 'Enviar PDF al cliente', () async {
                  if (p.cliente?.tieneCuenta != true) {
                    final seguir = await confirmar(
                        c,
                        'Cliente sin cuenta',
                        '${p.cliente?.nombre ?? 'El cliente'} no usa CarpiApp. Se guardará la cotización como enviada; '
                            'compártele el PDF con "Descargar PDF" (WhatsApp o correo).',
                        si: 'Continuar');
                    if (!seguir) return;
                  }
                  if (!c.mounted) return;
                  final ok = await conCarga(c, () async {
                    final bytes = await _pdf(cot);
                    final ruta = await Api.subirPdfCotizacion(cot, bytes);
                    await Api.marcarCotizacionEnviada(cot, ruta);
                  }, exito: 'Cotización enviada al cliente');
                  if (ok) recargar();
                }, icono: Icons.send_outlined),
              if (!enviada) ...[
                const SizedBox(height: 10),
                BotonSecundario('Editar cotización', () async {
                  await ir(c, EditorCotizacion(pedido: p, cotizacion: cot));
                  recargar();
                }, icono: Icons.edit_outlined),
              ],
              const SizedBox(height: 10),
              BotonSecundario('Imprimir cotización', () async {
                await Printing.layoutPdf(
                  name: 'Cotizacion-${cot.folio}',
                  onLayout: (_) async => await _pdf(cot),
                );
              }, icono: Icons.print_outlined),
            ]);
          },
        ),
      );
}
