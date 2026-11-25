import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Describe una foto de referencia con ML Kit en el propio teléfono
/// (gratis y sin conexión). La descripción es orientativa y editable:
/// no sirve para calcular medidas ni para elegir materiales.
class DescripcionFoto {
  static const aviso = 'La foto es una referencia visual; no permite confirmar medidas ni materiales.';

  /// Etiquetas del modelo base de ML Kit → español.
  static const _es = <String, String>{
    'furniture': 'un mueble',
    'cabinetry': 'gabinetes',
    'cupboard': 'una alacena',
    'wardrobe': 'un clóset',
    'closet': 'un clóset',
    'drawer': 'cajones',
    'shelf': 'repisas',
    'bookcase': 'un librero',
    'table': 'una mesa',
    'desk': 'un escritorio',
    'chair': 'sillas',
    'couch': 'un sillón',
    'bed': 'una cama',
    'door': 'una puerta',
    'window': 'una ventana',
    'kitchen': 'una cocina',
    'countertop': 'una cubierta',
    'sink': 'una tarja',
    'room': 'una habitación',
    'bedroom': 'una recámara',
    'living room': 'una sala',
    'bathroom': 'un baño',
    'interior design': 'un espacio interior',
    'floor': 'el piso',
    'wall': 'un muro',
    'ceiling': 'el techo',
    'stairs': 'una escalera',
    'television': 'una televisión',
    'lamp': 'una lámpara',
    'plant': 'plantas',
    'curtain': 'cortinas',
    'tile': 'azulejo',
    'building': 'una construcción',
    'house': 'una casa',
    'patio': 'un patio',
    'garden': 'un jardín',
  };

  static const _materiales = <String, String>{
    'wood': 'madera',
    'hardwood': 'madera sólida',
    'plywood': 'triplay',
    'lumber': 'tablas de madera',
    'metal': 'metal',
    'glass': 'vidrio',
    'marble': 'mármol',
    'concrete': 'concreto',
    'tile': 'azulejo',
    'paint': 'pintura',
    'brick': 'ladrillo',
  };

  /// Devuelve una descripción en español o cadena vacía si no reconoce nada.
  static Future<String> describir(String rutaArchivo) async {
    final etiquetador = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.55));
    try {
      final etiquetas = await etiquetador.processImage(InputImage.fromFilePath(rutaArchivo));
      final objetos = <String>[];
      final materiales = <String>[];
      for (final e in etiquetas) {
        final k = e.label.toLowerCase();
        final mat = _materiales[k];
        if (mat != null && !materiales.contains(mat)) materiales.add(mat);
        final obj = _es[k];
        if (obj != null && !objetos.contains(obj)) objetos.add(obj);
      }
      if (objetos.isEmpty && materiales.isEmpty) return '';
      final b = StringBuffer('La imagen muestra ');
      b.write(objetos.isEmpty ? 'un espacio o mueble' : _lista(objetos.take(4).toList()));
      b.write('.');
      if (materiales.isNotEmpty) b.write(' Se aprecia ${_lista(materiales.take(3).toList())}.');
      b.write(' $aviso');
      return b.toString();
    } catch (_) {
      return '';
    } finally {
      await etiquetador.close();
    }
  }

  static String _lista(List<String> l) {
    if (l.length == 1) return l.first;
    return '${l.sublist(0, l.length - 1).join(', ')} y ${l.last}';
  }
}
