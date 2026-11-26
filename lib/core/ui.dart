// Punto único de importación de los widgets de Flutter.
//
// Flutter 3.47+ marca `package:flutter/material.dart` como obsoleto en favor
// del paquete independiente `material_ui`. Los paquetes que usa CarpiApp
// (printing, model_viewer_plus, image_picker…) todavía dependen de
// `flutter/material`, y mezclar ambas copias rompe los temas y el árbol de
// Material. Por eso la app sigue en `flutter/material` desde este archivo;
// cuando esos paquetes migren, solo hay que cambiar estas dos líneas.
// ignore: deprecated_member_use
export 'package:flutter/material.dart';
// ignore: deprecated_member_use
export 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoIcons;
