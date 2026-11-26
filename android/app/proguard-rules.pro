# CarpiApp · reglas de R8 para la versión de publicación.

# ML Kit (etiquetado de imágenes en el teléfono, sin internet ni costo).
# Sus componentes se registran por reflexión; si R8 los quita, el plugin falla al iniciar.
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_image_labeling.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**
