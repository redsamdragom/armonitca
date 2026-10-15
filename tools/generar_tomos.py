#!/usr/bin/env python3
"""Genera src/shared/Data/TomeArt.luau a partir de assets/tomos/*.png.

Uso (desde la raíz del repositorio): python3 tools/generar_tomos.py
Cada imagen se reduce a 96×96 con una paleta de 127 colores más el transparente (índice 0).
Los archivos deben llamarse tomo-NN-<IdDelTomo>.png.
"""
import base64
import glob
import os

from PIL import Image

SIZE = 96


def encode(path):
    im = Image.open(path).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
    alpha = im.getchannel("A").load()
    rgb = Image.new("RGB", im.size, (0, 0, 0))
    rgb.paste(im.convert("RGB"))
    q = rgb.quantize(colors=127, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palette = q.getpalette()[: 127 * 3]
    palette += [0] * (127 * 3 - len(palette))
    indices = q.load()
    pixels = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            pixels.append(0 if alpha[x, y] < 128 else indices[x, y] + 1)
    return base64.b64encode(bytes([0, 0, 0] + palette)).decode(), base64.b64encode(bytes(pixels)).decode()


def main():
    lines = [
        "-- Generado a partir de assets/tomos/ (96×96, paleta de 128 colores; índice 0 = transparente).",
        "-- Se usa cuando el tomo no tiene ID en Data/Images o su imagen no carga en Roblox: el cliente",
        "-- la dibuja con un EditableImage, sin necesidad de subirla. No editar a mano: se regenera con",
        "-- python3 tools/generar_tomos.py",
        "",
        "return {",
        "\tsize = %d," % SIZE,
        "\ttomes = {",
    ]
    for path in sorted(glob.glob("assets/tomos/tomo-*.png")):
        tome_id = os.path.basename(path)[:-4].split("-")[2]
        palette, pixels = encode(path)
        lines.append('\t\t%s = { palette = "%s", pixels = "%s" },' % (tome_id, palette, pixels))
    lines += ["\t},", "}", ""]
    with open("src/shared/Data/TomeArt.luau", "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
