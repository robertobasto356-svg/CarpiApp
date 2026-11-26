import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/ui.dart';
import 'widgets.dart';

/// Vista previa del PDF dentro de la app (sin depender del navegador del teléfono).
/// Incluye compartir/descargar e imprimir.
class VisorPdf extends StatefulWidget {
  final String titulo;
  final String archivo;
  final Future<Uint8List> Function() cargar;
  const VisorPdf({required this.titulo, required this.archivo, required this.cargar, super.key});

  @override
  State<VisorPdf> createState() => _VisorPdfState();
}

class _VisorPdfState extends State<VisorPdf> {
  late Future<Uint8List> _pdf = widget.cargar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PantallaBase(
      seccion: 'Cotización',
      titulo: widget.titulo,
      cuerpo: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (c, s) {
          if (s.hasError) return ErrorCarga(s.error!, () => setState(() => _pdf = widget.cargar()));
          if (!s.hasData) return const Cargando();
          return PdfPreview(
            build: (PdfPageFormat _) async => s.data!,
            pdfFileName: widget.archivo,
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            maxPageWidth: 720,
            scrollViewDecoration: BoxDecoration(color: cs.surfaceContainerHighest),
            pdfPreviewPageDecoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            loadingWidget: const Cargando(),
          );
        },
      ),
    );
  }
}
