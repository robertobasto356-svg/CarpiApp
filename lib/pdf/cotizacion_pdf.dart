import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formato.dart';
import '../modelos/modelos.dart';

/// Genera el PDF de la cotización (el mismo que recibe el cliente).
Future<Uint8List> generarPdfCotizacion(Cotizacion c, Pedido p, Carpinteria k) async {
  final doc = pw.Document(title: 'Cotización ${c.folio}', author: k.nombre, creator: 'CarpiApp');
  pw.MemoryImage? logo;
  try {
    logo = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List());
  } catch (_) {}

  const terracota = PdfColor.fromInt(0xFFA8461D);
  const arena = PdfColor.fromInt(0xFFF4E8DC);
  const gris = PdfColor.fromInt(0xFF7A6E66);
  final fecha = c.enviadaAt ?? DateTime.now();

  pw.Widget etiqueta(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3, top: 10),
    child: pw.Text(
      t.toUpperCase(),
      style: pw.TextStyle(fontSize: 8.5, color: gris, fontWeight: pw.FontWeight.bold, letterSpacing: .6),
    ),
  );

  pw.Widget fila(String a, String b, {bool negrita = false, double tam = 10}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            a,
            style: pw.TextStyle(fontSize: tam, fontWeight: negrita ? pw.FontWeight.bold : null),
          ),
        ),
        pw.Text(
          b,
          style: pw.TextStyle(fontSize: tam, fontWeight: negrita ? pw.FontWeight.bold : null),
        ),
      ],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 36),
      header: (_) => pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) pw.Container(width: 70, height: 70, child: pw.Image(logo)),
              if (logo != null) pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      k.nombre,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: terracota),
                    ),
                    if (k.direccion.isNotEmpty) pw.Text(k.direccion, style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      [k.telefono, k.correo].where((s) => s.isNotEmpty).join('  ·  '),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(k.ciudad, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('COTIZACIÓN', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    c.folio,
                    style: pw.TextStyle(fontSize: 12, color: terracota, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(fechaLarga(fecha), style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Pedido ${p.folio}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: terracota, thickness: 1.4),
        ],
      ),
      footer: (ctx) => pw.Row(
        children: [
          pw.Text('Generado con CarpiApp', style: const pw.TextStyle(fontSize: 8, color: gris)),
          pw.Spacer(),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: gris)),
        ],
      ),
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  etiqueta('Cliente'),
                  pw.Text(p.cliente?.nombre ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  if ((p.cliente?.telefono ?? '').isNotEmpty)
                    pw.Text(p.cliente!.telefono, style: const pw.TextStyle(fontSize: 10)),
                  if ((p.cliente?.direccion ?? '').isNotEmpty)
                    pw.Text(p.cliente!.direccion, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  etiqueta('Proyecto'),
                  pw.Text(p.titulo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    [p.tipoMueble, p.materialAcabado].where((s) => s.isNotEmpty).join(' · '),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        etiqueta('Medidas tomadas en la cita'),
        pw.Text(p.medidasTexto, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text('Registradas por el carpintero', style: const pw.TextStyle(fontSize: 8.5, color: gris)),
        if (p.descripcion.isNotEmpty) ...[
          etiqueta('Descripción'),
          pw.Text(p.descripcion, style: const pw.TextStyle(fontSize: 10)),
        ],
        if (c.partidas.isNotEmpty) ...[
          etiqueta('Materiales'),
          pw.TableHelper.fromTextArray(
            headers: ['Concepto', 'Cantidad', 'Precio unitario', 'Importe'],
            data: [
              for (final pa in c.partidas)
                [pa.concepto, cantidadCon(pa.cantidad, pa.unidad), dinero(pa.precioUnitario), dinero(pa.importe)],
            ],
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: terracota),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
            border: null,
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5)),
            ),
          ),
        ],
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(color: arena, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            children: [
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'RESUMEN DE COTIZACIÓN',
                  style: pw.TextStyle(fontSize: 8.5, color: gris, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              fila('Materiales', dinero(c.costoMateriales)),
              fila('Mano de obra', dinero(c.manoObra)),
              fila('Costos adicionales', dinero(c.costosAdicionales)),
              pw.Divider(color: PdfColors.grey400),
              fila('TOTAL', dinero(c.total), negrita: true, tam: 14),
            ],
          ),
        ),
        if (c.notas.isNotEmpty) ...[etiqueta('Notas'), pw.Text(c.notas, style: const pw.TextStyle(fontSize: 10))],
        pw.SizedBox(height: 18),
        pw.Text(
          'Precios en pesos mexicanos. Esta cotización la elaboró ${k.nombre} con las medidas verificadas en la cita. '
          'Para aceptarla, pedir ajustes o rechazarla, responde desde CarpiApp o contacta a la carpintería.',
          style: const pw.TextStyle(fontSize: 8.5, color: gris),
        ),
      ],
    ),
  );
  return doc.save();
}
