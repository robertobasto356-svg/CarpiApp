"""Genera los modelos 3D de referencia de CarpiApp (GLB para Android, USDZ para iOS).

Cada mueble se arma con piezas rectangulares (tableros) con medidas reales en metros.
No requiere librerías externas: escribe glTF binario y USDZ (zip sin compresión,
alineado a 64 bytes) a mano.

Uso:  python tools/generar_modelos.py assets/modelos
"""
import json
import os
import struct
import sys
import zipfile

# Colores (RGB 0-1) y rugosidad
MATERIALES = {
    "madera": ((0.55, 0.36, 0.20), 0.65),
    "madera_clara": ((0.78, 0.60, 0.40), 0.6),
    "melamina": ((0.93, 0.92, 0.89), 0.5),
    "metal": ((0.25, 0.25, 0.27), 0.35),
    "cubierta": ((0.30, 0.29, 0.28), 0.4),
    "tela": ((0.90, 0.90, 0.92), 0.9),
}


def caja(piezas, mat, x0, y0, z0, x1, y1, z1):
    piezas.append((mat, (min(x0, x1), min(y0, y1), min(z0, z1)), (max(x0, x1), max(y0, y1), max(z0, z1))))


# ---------------------------------------------------------------------------
# Muebles (y hacia arriba, z hacia el frente, origen al centro del piso)
# ---------------------------------------------------------------------------
def closet():
    p, w, h, d, t = [], 1.8, 2.4, 0.6, 0.018
    caja(p, "madera", -w / 2, 0, -d / 2, w / 2, 0.08, d / 2 - 0.03)            # zoclo
    caja(p, "madera", -w / 2, 0.08, -d / 2, -w / 2 + t, h, d / 2 - 0.02)      # costado izq
    caja(p, "madera", w / 2 - t, 0.08, -d / 2, w / 2, h, d / 2 - 0.02)        # costado der
    caja(p, "madera", -w / 2, h - t, -d / 2, w / 2, h, d / 2 - 0.02)          # techo
    caja(p, "madera", -w / 2, 0.08, -d / 2, w / 2, 0.08 + t, d / 2 - 0.02)    # piso
    caja(p, "madera", -w / 2, 0.08, -d / 2, w / 2, h, -d / 2 + 0.006)         # fondo
    caja(p, "madera", -t / 2, 0.08, -d / 2, t / 2, h, d / 2 - 0.02)           # división
    for lado in (-1, 1):                                                     # puertas
        x0 = -w / 2 + 0.004 if lado < 0 else 0.002
        x1 = -0.002 if lado < 0 else w / 2 - 0.004
        caja(p, "madera_clara", x0, 0.09, d / 2 - 0.02, x1, h - 0.004, d / 2)
        hx = -0.05 if lado < 0 else 0.03
        caja(p, "metal", hx, 1.0, d / 2, hx + 0.02, 1.35, d / 2 + 0.03)       # jaladeras
    return p


def mesa():
    p, w, d, h = [], 1.6, 0.9, 0.75
    caja(p, "madera", -w / 2, h - 0.04, -d / 2, w / 2, h, d / 2)
    for sx in (-1, 1):
        for sz in (-1, 1):
            x = sx * (w / 2 - 0.08)
            z = sz * (d / 2 - 0.08)
            caja(p, "madera", x - 0.035, 0, z - 0.035, x + 0.035, h - 0.04, z + 0.035)
    caja(p, "madera", -w / 2 + 0.1, h - 0.12, -d / 2 + 0.09, w / 2 - 0.1, h - 0.04, -d / 2 + 0.11)
    caja(p, "madera", -w / 2 + 0.1, h - 0.12, d / 2 - 0.11, w / 2 - 0.1, h - 0.04, d / 2 - 0.09)
    return p


def escritorio():
    p, w, d, h = [], 1.2, 0.6, 0.75
    caja(p, "madera_clara", -w / 2, h - 0.03, -d / 2, w / 2, h, d / 2)
    caja(p, "madera", -w / 2, 0, -d / 2, -w / 2 + 0.025, h - 0.03, d / 2)
    caja(p, "madera", w / 2 - 0.42, 0, -d / 2, w / 2, h - 0.03, d / 2 - 0.02)
    for i in range(3):
        y0 = 0.03 + i * 0.235
        caja(p, "madera_clara", w / 2 - 0.415, y0, d / 2 - 0.02, w / 2 - 0.005, y0 + 0.225, d / 2)
        caja(p, "metal", w / 2 - 0.26, y0 + 0.15, d / 2, w / 2 - 0.16, y0 + 0.165, d / 2 + 0.025)
    caja(p, "madera", -w / 2 + 0.025, h - 0.45, -d / 2, w / 2 - 0.42, h - 0.03, -d / 2 + 0.018)
    return p


def librero():
    p, w, h, d, t = [], 0.9, 1.8, 0.3, 0.018
    caja(p, "madera", -w / 2, 0, -d / 2, -w / 2 + t, h, d / 2)
    caja(p, "madera", w / 2 - t, 0, -d / 2, w / 2, h, d / 2)
    caja(p, "madera", -w / 2, 0, -d / 2, w / 2, h, -d / 2 + 0.006)
    for i in range(6):
        y = 0.06 + i * (h - 0.06 - t) / 5
        caja(p, "madera", -w / 2 + t, y, -d / 2, w / 2 - t, y + t, d / 2 - 0.01)
    caja(p, "madera", -w / 2 + t, 0, d / 2 - 0.03, w / 2 - t, 0.06, d / 2)
    return p


def cocina():
    p, w = [], 2.4
    caja(p, "melamina", -w / 2, 0.1, -0.29, w / 2, 0.86, 0.27)               # gabinetes bajos
    caja(p, "metal", -w / 2, 0, -0.29, w / 2, 0.1, 0.22)                     # zoclo
    caja(p, "cubierta", -w / 2 - 0.02, 0.86, -0.3, w / 2 + 0.02, 0.9, 0.32)  # cubierta
    caja(p, "melamina", -w / 2, 1.45, -0.3, w / 2, 2.15, 0.03)              # gabinetes altos
    for i in range(6):                                                       # frentes bajos
        x0 = -w / 2 + i * w / 6 + 0.003
        caja(p, "madera_clara", x0, 0.11, 0.27, x0 + w / 6 - 0.006, 0.85, 0.29)
        caja(p, "metal", x0 + 0.04, 0.78, 0.29, x0 + w / 6 - 0.04, 0.795, 0.31)
    for i in range(4):                                                       # frentes altos
        x0 = -w / 2 + i * w / 4 + 0.003
        caja(p, "madera_clara", x0, 1.455, 0.03, x0 + w / 4 - 0.006, 2.145, 0.05)
        caja(p, "metal", x0 + 0.05, 1.5, 0.05, x0 + w / 4 - 0.05, 1.515, 0.07)
    return p


def cama():
    p = []
    caja(p, "madera", -0.73, 0, -1.0, 0.73, 0.32, 1.0)
    caja(p, "tela", -0.7, 0.32, -0.97, 0.7, 0.54, 0.98)
    caja(p, "madera", -0.78, 0, -1.06, 0.78, 1.1, -1.0)
    caja(p, "tela", -0.6, 0.54, -0.9, -0.05, 0.66, -0.55)
    caja(p, "tela", 0.05, 0.54, -0.9, 0.6, 0.66, -0.55)
    return p


def puerta():
    p, w, h = [], 0.9, 2.1
    caja(p, "madera", -w / 2 - 0.08, 0, -0.07, -w / 2, h + 0.08, 0.07)
    caja(p, "madera", w / 2, 0, -0.07, w / 2 + 0.08, h + 0.08, 0.07)
    caja(p, "madera", -w / 2 - 0.08, h, -0.07, w / 2 + 0.08, h + 0.08, 0.07)
    caja(p, "madera_clara", -w / 2 + 0.003, 0.01, -0.02, w / 2 - 0.003, h - 0.003, 0.02)
    caja(p, "metal", w / 2 - 0.14, 0.98, 0.02, w / 2 - 0.06, 1.0, 0.07)
    caja(p, "metal", w / 2 - 0.14, 0.98, -0.07, w / 2 - 0.06, 1.0, -0.02)
    return p


def mueble_tv():
    p, w, h, d = [], 1.8, 0.5, 0.4
    caja(p, "madera", -w / 2, 0.12, -d / 2, w / 2, h + 0.12, d / 2 - 0.02)
    for i in range(3):
        x0 = -w / 2 + i * w / 3 + 0.003
        caja(p, "madera_clara", x0, 0.13, d / 2 - 0.02, x0 + w / 3 - 0.006, h + 0.11, d / 2)
        caja(p, "metal", x0 + 0.15, h - 0.02, d / 2, x0 + w / 3 - 0.15, h - 0.005, d / 2 + 0.02)
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (w / 2 - 0.08), sz * (d / 2 - 0.07)
            caja(p, "metal", x - 0.015, 0, z - 0.015, x + 0.015, 0.12, z + 0.015)
    return p


MUEBLES = {
    "closet": closet,
    "mesa": mesa,
    "escritorio": escritorio,
    "librero": librero,
    "cocina": cocina,
    "cama": cama,
    "puerta": puerta,
    "mueble_tv": mueble_tv,
}

# Caras: (normal, eje u, eje v) con u x v = normal -> vértices en sentido antihorario
CARAS = [
    ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
    ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    ((0, 1, 0), (0, 0, 1), (1, 0, 0)),
    ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
    ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
    ((0, 0, -1), (0, 1, 0), (1, 0, 0)),
]


def geometria(mn, mx):
    c = [(mn[i] + mx[i]) / 2 for i in range(3)]
    hsz = [(mx[i] - mn[i]) / 2 for i in range(3)]
    pts, nor = [], []
    for n, u, v in CARAS:
        for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            pts.append(tuple(c[i] + n[i] * hsz[i] + su * u[i] * hsz[i] + sv * v[i] * hsz[i] for i in range(3)))
            nor.append(n)
    return pts, nor


def agrupar(piezas):
    grupos = {}
    for mat, mn, mx in piezas:
        grupos.setdefault(mat, []).append((mn, mx))
    return grupos


# ---------------------------------------------------------------------------
# GLB
# ---------------------------------------------------------------------------
def escribir_glb(piezas, ruta):
    binario = bytearray()
    vistas, accesores, primitivas, materiales = [], [], [], []

    def vista(datos, objetivo):
        while len(binario) % 4:
            binario.append(0)
        vistas.append({"buffer": 0, "byteOffset": len(binario), "byteLength": len(datos), "target": objetivo})
        binario.extend(datos)
        return len(vistas) - 1

    for mat, cajas in agrupar(piezas).items():
        pts, nor, idx = [], [], []
        for mn, mx in cajas:
            base = len(pts)
            p, n = geometria(mn, mx)
            pts += p
            nor += n
            for f in range(6):
                b = base + f * 4
                idx += [b, b + 1, b + 2, b, b + 2, b + 3]
        vp = vista(b"".join(struct.pack("<3f", *q) for q in pts), 34962)
        vn = vista(b"".join(struct.pack("<3f", *q) for q in nor), 34962)
        vi = vista(struct.pack("<%dI" % len(idx), *idx), 34963)
        mins = [min(q[i] for q in pts) for i in range(3)]
        maxs = [max(q[i] for q in pts) for i in range(3)]
        accesores.append({"bufferView": vp, "componentType": 5126, "count": len(pts), "type": "VEC3", "min": mins, "max": maxs})
        accesores.append({"bufferView": vn, "componentType": 5126, "count": len(nor), "type": "VEC3"})
        accesores.append({"bufferView": vi, "componentType": 5125, "count": len(idx), "type": "SCALAR"})
        color, rug = MATERIALES[mat]
        materiales.append({
            "name": mat,
            "pbrMetallicRoughness": {
                "baseColorFactor": [*color, 1.0],
                "metallicFactor": 0.6 if mat == "metal" else 0.0,
                "roughnessFactor": rug,
            },
        })
        a = len(accesores)
        primitivas.append({"attributes": {"POSITION": a - 3, "NORMAL": a - 2}, "indices": a - 1, "material": len(materiales) - 1})

    while len(binario) % 4:
        binario.append(0)
    gltf = {
        "asset": {"version": "2.0", "generator": "CarpiApp generar_modelos.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "Mueble"}],
        "meshes": [{"primitives": primitivas}],
        "materials": materiales,
        "accessors": accesores,
        "bufferViews": vistas,
        "buffers": [{"byteLength": len(binario)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(binario)
    with open(ruta, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binario), 0x004E4942) + bytes(binario))


# ---------------------------------------------------------------------------
# USDZ (USDA dentro de un zip sin compresión alineado a 64 bytes)
# ---------------------------------------------------------------------------
def usda(piezas):
    t = lambda v: "(%s)" % ", ".join("%.4f" % x for x in v)
    lineas = [
        "#usda 1.0",
        "(",
        '    defaultPrim = "Mueble"',
        "    metersPerUnit = 1",
        '    upAxis = "Y"',
        ")",
        "",
        'def Xform "Mueble" (',
        '    kind = "component"',
        ")",
        "{",
        '    def Scope "Materiales"',
        "    {",
    ]
    for mat, (color, rug) in MATERIALES.items():
        lineas += [
            '        def Material "%s"' % mat,
            "        {",
            "            token outputs:surface.connect = </Mueble/Materiales/%s/Superficie.outputs:surface>" % mat,
            '            def Shader "Superficie"',
            "            {",
            '                uniform token info:id = "UsdPreviewSurface"',
            "                color3f inputs:diffuseColor = %s" % t(color),
            "                float inputs:metallic = %s" % ("0.6" if mat == "metal" else "0"),
            "                float inputs:roughness = %.2f" % rug,
            "                token outputs:surface",
            "            }",
            "        }",
        ]
    lineas.append("    }")
    for i, (mat, cajas) in enumerate(agrupar(piezas).items()):
        pts, nor, idx = [], [], []
        for mn, mx in cajas:
            base = len(pts)
            p, n = geometria(mn, mx)
            pts += p
            for f in range(6):
                nor += [n[f * 4]] * 4
                idx += [base + f * 4 + k for k in range(4)]
        mins = [min(q[j] for q in pts) for j in range(3)]
        maxs = [max(q[j] for q in pts) for j in range(3)]
        lineas += [
            "",
            '    def Mesh "Piezas_%d" (' % i,
            '        prepend apiSchemas = ["MaterialBindingAPI"]',
            "    )",
            "    {",
            "        float3[] extent = [%s, %s]" % (t(mins), t(maxs)),
            "        int[] faceVertexCounts = [%s]" % ", ".join(["4"] * (len(idx) // 4)),
            "        int[] faceVertexIndices = [%s]" % ", ".join(map(str, idx)),
            "        point3f[] points = [%s]" % ", ".join(t(q) for q in pts),
            "        normal3f[] normals = [%s] (" % ", ".join(t(q) for q in nor),
            '            interpolation = "faceVarying"',
            "        )",
            '        uniform token subdivisionScheme = "none"',
            "        rel material:binding = </Mueble/Materiales/%s>" % mat,
            "    }",
        ]
    lineas.append("}")
    return ("\n".join(lineas) + "\n").encode()


def escribir_usdz(piezas, ruta):
    datos = usda(piezas)
    nombre = "mueble.usda"
    # Relleno en el campo "extra" para que los datos empiecen en múltiplo de 64.
    encabezado = 30 + len(nombre)
    relleno = (64 - (encabezado + 4) % 64) % 64
    extra = struct.pack("<HH", 0x1986, relleno) + b"\0" * relleno
    info = zipfile.ZipInfo(nombre, date_time=(2026, 11, 24, 0, 0, 0))
    info.compress_type = zipfile.ZIP_STORED
    info.extra = extra
    with zipfile.ZipFile(ruta, "w", zipfile.ZIP_STORED) as z:
        z.writestr(info, datos)
    with open(ruta, "rb") as f:
        contenido = f.read()
    desplazamiento = 30 + len(nombre) + len(extra)
    assert desplazamiento % 64 == 0, "USDZ sin alinear"
    assert contenido[desplazamiento:desplazamiento + 6] == b"#usda ", "USDZ mal formado"


def main():
    destino = sys.argv[1] if len(sys.argv) > 1 else "assets/modelos"
    os.makedirs(destino, exist_ok=True)
    for nombre, fn in MUEBLES.items():
        piezas = fn()
        escribir_glb(piezas, os.path.join(destino, nombre + ".glb"))
        escribir_usdz(piezas, os.path.join(destino, nombre + ".usdz"))
        print("%-12s %3d piezas" % (nombre, len(piezas)))


if __name__ == "__main__":
    main()
