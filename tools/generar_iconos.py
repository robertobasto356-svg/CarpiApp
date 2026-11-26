"""Genera los íconos de CarpiApp (Android e iPhone) a partir de assets/logo.png.

Usa el emblema del logo (castor y pájaro carpintero) sin el texto, que no se
leería en tamaño pequeño, sobre un fondo café madera.

Uso (desde la raíz del proyecto):  python tools/generar_iconos.py
Requiere Pillow:                     pip install pillow
"""

from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
LOGO = RAIZ / "assets" / "logo.png"
RES = RAIZ / "android" / "app" / "src" / "main" / "res"
IOS = RAIZ / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

FONDO = (110, 52, 20)  # café del aro de madera
FONDO_HEX = "#6E3414"


def emblema() -> Image.Image:
    """Recorta el emblema (debajo del texto "CARPIAPP" y arriba del lema) y quita el halo blanco."""
    logo = Image.open(LOGO).convert("RGBA")
    em = logo.crop((0, 80, 315, 320))
    em = em.crop(em.getchannel("A").getbbox())
    px = em.load()
    ancho, alto = em.size
    vecinos = ((3, 0), (-3, 0), (0, 3), (0, -3), (5, 0), (-5, 0), (0, 5), (0, -5))
    for y in range(alto):
        for x in range(ancho):
            r, g, b, a = px[x, y]
            if a and min(r, g, b) > 215:
                if any(0 <= x + dx < ancho and 0 <= y + dy < alto and px[x + dx, y + dy][3] < 40 for dx, dy in vecinos):
                    px[x, y] = (r, g, b, 0)
    return em


def cuadrado(em: Image.Image, margen: float, fondo) -> Image.Image:
    """Centra el emblema en un lienzo cuadrado; margen = lado / tamaño del emblema."""
    ancho, alto = em.size
    lado = int(max(ancho, alto) * margen)
    lienzo = Image.new("RGBA", (lado, lado), fondo)
    lienzo.alpha_composite(em, ((lado - ancho) // 2, (lado - alto) // 2))
    return lienzo


def main() -> None:
    em = emblema()
    completo = cuadrado(em, 1.12, FONDO + (255,))  # ícono clásico (cuadrado lleno)
    # Ícono adaptativo: 108 dp con zona segura de 66 dp → el emblema ocupa ~61 % del lienzo.
    frente = cuadrado(em, 1.65, (0, 0, 0, 0))

    densidades = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for nombre, f in densidades.items():
        carpeta = RES / f"mipmap-{nombre}"
        carpeta.mkdir(parents=True, exist_ok=True)
        completo.resize((round(48 * f),) * 2, Image.LANCZOS).save(carpeta / "ic_launcher.png")
        frente.resize((round(108 * f),) * 2, Image.LANCZOS).save(carpeta / "ic_launcher_foreground.png")

    adaptativo = RES / "mipmap-anydpi-v26"
    adaptativo.mkdir(parents=True, exist_ok=True)
    (adaptativo / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    valores = RES / "values"
    (valores / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        f'    <color name="ic_launcher_background">{FONDO_HEX}</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )

    # iPhone: mismos archivos que ya define Contents.json, sin transparencia (App Store la rechaza).
    base = completo.convert("RGB")
    for archivo in sorted(IOS.glob("*.png")):
        lado = Image.open(archivo).size[0]
        base.resize((lado, lado), Image.LANCZOS).save(archivo)

    print("Íconos generados para Android e iPhone.")


if __name__ == "__main__":
    main()
