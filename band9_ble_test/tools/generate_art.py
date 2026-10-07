"""Genera el arte PLACEHOLDER de "Gatos en la barra" como PNG individuales.

Herramienta de desarrollo (no se exporta). Uso:  python3 tools/generate_art.py
Cada PNG es un asset independiente: puedes reemplazar cualquiera desde Godot
(o sobrescribir el archivo) y las escenas/animaciones siguen funcionando.

Convenciones para que los reemplazos encajen:
- Partes del gato (cuerpo, cabeza, oreja, cola, pata, mancha) se dibujan en
  BLANCO/gris claro: el script las tiñe con la paleta del gato (modulate).
- Bolas de dango: ~64 px, con contorno oscuro (la bola blanca nunca se pierde).
- El origen visual de cada sprite está centrado salvo que se indique en la escena.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "art")
SS = 4  # supersampling
INK = (74, 58, 53, 255)


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def save(img, rel, w, h):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((w, h), Image.LANCZOS).save(path)


def S(*v):
    return [x * SS for x in v]


def ellipse(d, box, fill, outline=None, width=0):
    d.ellipse(S(*box), fill=fill, outline=outline, width=width * SS)


# ------------------------------------------------------------------ DANGO
def ball(rel, color, shade, outline=INK):
    w = h = 64
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    ellipse(d, (4, 4, 60, 60), shade, outline, 3)
    ellipse(d, (8, 6, 54, 50), color)
    ellipse(d, (16, 12, 30, 24), (255, 255, 255, 170))
    save(im, rel, w, h)


def sauce():
    w, h = 72, 64
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    # capa de salsa mitarashi que cubre la bola superior y gotea
    d.pieslice(S(4, 2, 68, 58), 180, 360, fill=(160, 92, 40, 230), outline=INK, width=2 * SS)
    for x, l in ((14, 16), (30, 24), (46, 14), (58, 20)):
        d.rounded_rectangle(S(x - 4, 26, x + 4, 26 + l), radius=4 * SS, fill=(160, 92, 40, 230))
    ellipse(d, (20, 8, 34, 16), (230, 180, 120, 200))
    save(im, "dango/salsa.png", w, h)


def stick():
    w, h = 16, 220
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(4, 0, 12, 220), radius=4 * SS, fill=(222, 190, 140, 255), outline=INK, width=2 * SS)
    save(im, "dango/palito.png", w, h)


def shadow():
    w, h = 64, 20
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    ellipse(d, (2, 2, 62, 18), (0, 0, 0, 70))
    save(im.filter(ImageFilter.GaussianBlur(SS * 2)), "dango/sombra.png", w, h)


# ------------------------------------------------------------------ COCINA
def tray():
    w, h = 300, 120
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(4, 20, 296, 116), radius=18 * SS, fill=(120, 70, 50, 255), outline=INK, width=3 * SS)
    d.rounded_rectangle(S(18, 30, 282, 104), radius=12 * SS, fill=(170, 105, 75, 255))
    d.rounded_rectangle(S(18, 30, 282, 44), radius=8 * SS, fill=(190, 125, 90, 255))
    save(im, "cocina/bandeja.png", w, h)


def slot():
    w = h = 64
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    ellipse(d, (6, 6, 58, 58), (255, 255, 255, 40), (255, 250, 235, 200), 3)
    save(im, "cocina/hueco.png", w, h)


def bowl():
    w, h = 120, 70
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.pieslice(S(4, -40, 116, 66), 0, 180, fill=(235, 228, 215, 255), outline=INK, width=3 * SS)
    d.line(S(14, 30, 106, 30), fill=(70, 100, 140, 255), width=4 * SS)
    ellipse(d, (6, 14, 114, 30), (205, 195, 180, 255), INK, 2)
    save(im, "cocina/cuenco.png", w, h)


def sauce_pot():
    w, h = 110, 90
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(10, 30, 100, 86), radius=14 * SS, fill=(90, 70, 65, 255), outline=INK, width=3 * SS)
    ellipse(d, (10, 20, 100, 42), (150, 85, 38, 255), INK, 2)
    d.line(S(70, 28, 96, 2), fill=(222, 190, 140, 255), width=6 * SS)
    save(im, "cocina/olla_salsa.png", w, h)


def bin_():
    w, h = 110, 120
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.polygon(S(12, 24, 98, 24, 88, 116, 22, 116), fill=(110, 140, 120, 255), outline=INK)
    for x in (34, 55, 76):
        d.line(S(x, 34, x - 2 if x < 55 else x + 2 if x > 55 else x, 108), fill=(90, 120, 100, 255), width=3 * SS)
    d.line(S(12, 24, 98, 24), fill=INK, width=3 * SS)
    save(im, "cocina/bote.png", w, h)
    im = canvas(w, 30)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(4, 8, 106, 24), radius=6 * SS, fill=(85, 110, 95, 255), outline=INK, width=3 * SS)
    d.rounded_rectangle(S(46, 0, 64, 12), radius=4 * SS, fill=(85, 110, 95, 255), outline=INK, width=2 * SS)
    save(im, "cocina/bote_tapa.png", w, 30)


def paw_hint():
    w = h = 64
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    ellipse(d, (18, 28, 46, 56), (255, 245, 230, 235), INK, 2)
    for bx, by in ((10, 14), (22, 4), (36, 4), (48, 14)):
        ellipse(d, (bx, by, bx + 12, by + 16), (255, 245, 230, 235), INK, 2)
    save(im, "cocina/huella.png", w, h)


def table():
    w, h = 1280, 140
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rectangle(S(0, 0, 1280, 140), fill=(140, 104, 78, 255))
    d.rectangle(S(0, 0, 1280, 8), fill=(110, 80, 60, 255))
    for x in range(0, 1280, 160):
        d.line(S(x, 10, x + 120, 10), fill=(155, 118, 90, 255), width=2 * SS)
    save(im, "cocina/mesa.png", w, h)


# ------------------------------------------------------------------ GATO (blanco, se tiñe)
def cat_parts():
    W = (250, 250, 250, 255)
    im = canvas(120, 80)
    d = ImageDraw.Draw(im)
    d.pieslice(S(4, 4, 116, 156), 180, 360, fill=W, outline=INK, width=3 * SS)
    save(im, "gato/cuerpo.png", 120, 80)
    im = canvas(84, 76)
    d = ImageDraw.Draw(im)
    ellipse(d, (4, 4, 80, 72), W, INK, 3)
    save(im, "gato/cabeza.png", 84, 76)
    im = canvas(36, 44)
    d = ImageDraw.Draw(im)
    d.polygon(S(2, 42, 18, 2, 34, 42), fill=W, outline=INK)
    d.line(S(2, 42, 18, 2, 34, 42), fill=INK, width=3 * SS)
    d.polygon(S(10, 38, 18, 14, 26, 38), fill=(250, 190, 200, 255))
    save(im, "gato/oreja.png", 36, 44)
    im = canvas(30, 90)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(6, 4, 24, 88), radius=9 * SS, fill=W, outline=INK, width=3 * SS)
    save(im, "gato/cola.png", 30, 90)
    im = canvas(30, 26)
    d = ImageDraw.Draw(im)
    ellipse(d, (2, 2, 28, 24), W, INK, 3)
    save(im, "gato/pata.png", 30, 26)
    im = canvas(40, 36)
    d = ImageDraw.Draw(im)
    ellipse(d, (2, 2, 38, 34), (255, 255, 255, 255))
    save(im, "gato/mancha.png", 40, 36)
    im = canvas(16, 18)
    d = ImageDraw.Draw(im)
    ellipse(d, (1, 1, 15, 17), INK)
    ellipse(d, (4, 3, 9, 8), (255, 255, 255, 255))
    save(im, "gato/ojo_abierto.png", 16, 18)
    im = canvas(18, 10)
    d = ImageDraw.Draw(im)
    d.arc(S(1, -8, 17, 9), 20, 160, fill=INK, width=3 * SS)
    save(im, "gato/ojo_cerrado.png", 18, 10)
    im = canvas(30, 22)
    d = ImageDraw.Draw(im)
    ellipse(d, (10, 0, 20, 7), (240, 140, 150, 255))
    d.arc(S(3, 2, 15, 14), 20, 160, fill=INK, width=2 * SS)
    d.arc(S(15, 2, 27, 14), 20, 160, fill=INK, width=2 * SS)
    save(im, "gato/boca.png", 30, 22)


def bubble():
    w, h = 120, 150
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(4, 4, 116, 128), radius=20 * SS, fill=(255, 251, 240, 245), outline=INK, width=3 * SS)
    d.polygon(S(50, 126, 70, 126, 60, 146), fill=(255, 251, 240, 245))
    d.line(S(50, 127, 60, 146, 70, 127), fill=INK, width=3 * SS)
    # fondo interior ligeramente tostado: la bola blanca contrasta
    d.rounded_rectangle(S(14, 14, 106, 118), radius=14 * SS, fill=(236, 222, 200, 255))
    save(im, "gato/bocadillo.png", w, h)


def cushion():
    w, h = 150, 40
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(4, 6, 146, 36), radius=14 * SS, fill=(150, 80, 110, 255), outline=INK, width=3 * SS)
    save(im, "gato/cojin.png", w, h)


# ------------------------------------------------------------------ AMBIENTE
def sky():
    w, h = 1280, 440
    im = Image.new("RGBA", (w, h))
    top, bot = (198, 226, 230), (244, 238, 222)
    for y in range(h):
        t = y / h
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        ImageDraw.Draw(im).line((0, y, w, y), fill=c + (255,))
    os.makedirs(os.path.join(ROOT, "ambiente"), exist_ok=True)
    im.save(os.path.join(ROOT, "ambiente/cielo.png"))


def mountains():
    w, h = 1280, 240
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.polygon(S(0, 140, 200, 40, 420, 130, 650, 20, 900, 120, 1100, 50, 1280, 110, 1280, 240, 0, 240), fill=(150, 185, 185, 255))
    d.polygon(S(0, 200, 300, 120, 560, 190, 820, 110, 1280, 200, 1280, 240, 0, 240), fill=(130, 168, 160, 255))
    save(im, "ambiente/montanas.png", w, h)


def tree():
    im = canvas(40, 300)
    d = ImageDraw.Draw(im)
    d.rectangle(S(8, 0, 32, 300), fill=(105, 78, 62, 255))
    save(im, "ambiente/tronco.png", 40, 300)
    im = canvas(260, 200)
    d = ImageDraw.Draw(im)
    for cx, cy, r in ((70, 110, 60), (130, 80, 70), (190, 110, 60), (110, 140, 55), (170, 145, 50)):
        ellipse(d, (cx - r, cy - r, cx + r, cy + r), (243, 196, 205, 255))
    for cx, cy in ((90, 90), (160, 70), (200, 120), (120, 150)):
        ellipse(d, (cx - 6, cy - 6, cx + 6, cy + 6), (255, 228, 234, 255))
    save(im, "ambiente/copa.png", 260, 200)


def petal():
    im = canvas(22, 16)
    d = ImageDraw.Draw(im)
    ellipse(d, (1, 1, 21, 15), (250, 190, 205, 255))
    d.polygon(S(16, 6, 22, 8, 16, 10), fill=(0, 0, 0, 0))
    save(im, "ambiente/petalo.png", 22, 16)


def steam():
    im = canvas(64, 64)
    d = ImageDraw.Draw(im)
    ellipse(d, (8, 8, 56, 56), (255, 255, 255, 160))
    save(im.filter(ImageFilter.GaussianBlur(SS * 4)), "ambiente/vapor.png", 64, 64)


def noren():
    w, h = 140, 90
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rectangle(S(0, 0, 140, 90), fill=(60, 82, 128, 255))
    d.line(S(0, 2, 140, 2), fill=(40, 55, 90, 255), width=4 * SS)
    ellipse(d, (52, 30, 88, 66), (240, 236, 225, 230))
    save(im, "ambiente/tela.png", w, h)


def lantern():
    w, h = 70, 90
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rectangle(S(24, 0, 46, 10), fill=(60, 50, 45, 255))
    ellipse(d, (4, 8, 66, 84), (232, 92, 72, 255), INK, 3)
    for y in (26, 46, 66):
        d.arc(S(6, y - 18, 64, y + 18), 20, 160, fill=(200, 70, 55, 255), width=2 * SS)
    d.rectangle(S(24, 80, 46, 90), fill=(60, 50, 45, 255))
    save(im, "ambiente/farol.png", w, h)
    im = canvas(200, 200)
    d = ImageDraw.Draw(im)
    ellipse(d, (20, 20, 180, 180), (255, 200, 120, 120))
    save(im.filter(ImageFilter.GaussianBlur(SS * 20)), "ambiente/farol_brillo.png", 200, 200)


def roof():
    w, h = 1180, 80
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rectangle(S(30, 0, 1150, 24), fill=(140, 62, 55, 255))
    d.polygon(S(0, 24, 1180, 24, 1140, 72, 40, 72), fill=(184, 82, 70, 255), outline=INK)
    for x in range(60, 1140, 60):
        d.line(S(x, 30, x, 66), fill=(160, 70, 60, 255), width=3 * SS)
    save(im, "ambiente/techo.png", w, h)
    im = canvas(18, 320)
    d = ImageDraw.Draw(im)
    d.rectangle(S(2, 0, 16, 320), fill=(115, 82, 64, 255), outline=INK, width=2 * SS)
    save(im, "ambiente/poste.png", 18, 320)


def counter():
    w, h = 1280, 180
    im = canvas(w, h)
    d = ImageDraw.Draw(im)
    d.rectangle(S(0, 0, 1280, 18), fill=(196, 150, 108, 255))
    d.rectangle(S(0, 18, 1280, 180), fill=(160, 116, 82, 255))
    for x in range(40, 1280, 110):
        d.line(S(x, 26, x, 176), fill=(140, 100, 70, 255), width=3 * SS)
    d.rectangle(S(0, 140, 1280, 180), fill=(132, 104, 86, 255))
    save(im, "ambiente/barra.png", w, h)


def water():
    # Superficie del agua: textura tileable; Agua.gdshader la ondula.
    w, h = 256, 64
    im = Image.new("RGBA", (w, h), (110, 170, 200, 255))
    d = ImageDraw.Draw(im)
    for i in range(0, w, 32):
        d.arc((i - 8, 10, i + 24, 30), 200, 340, fill=(200, 230, 245, 255), width=2)
        d.arc((i + 8, 34, i + 40, 54), 200, 340, fill=(170, 210, 232, 255), width=2)
    os.makedirs(os.path.join(ROOT, "agua"), exist_ok=True)
    im.save(os.path.join(ROOT, "agua/agua_superficie.png"))
    im = canvas(220, 90)
    d = ImageDraw.Draw(im)
    d.polygon(S(6, 10, 214, 10, 190, 86, 30, 86), fill=(140, 140, 146, 255), outline=INK)
    d.line(S(6, 10, 214, 10), fill=INK, width=3 * SS)
    save(im, "agua/cuenco_piedra.png", 220, 90)
    im = canvas(170, 26)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(2, 2, 168, 24), radius=10 * SS, fill=(120, 160, 90, 255), outline=INK, width=2 * SS)
    for x in (50, 110):
        d.line(S(x, 3, x, 23), fill=(90, 130, 70, 255), width=3 * SS)
    save(im, "agua/bambu.png", 170, 26)
    im = canvas(14, 64)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(S(3, 0, 11, 64), radius=4 * SS, fill=(190, 225, 245, 220))
    save(im, "agua/chorro.png", 14, 64)
    im = canvas(14, 20)
    d = ImageDraw.Draw(im)
    d.polygon(S(7, 0, 13, 13, 1, 13), fill=(200, 232, 250, 255))
    ellipse(d, (1, 7, 13, 19), (200, 232, 250, 255))
    save(im, "agua/gota.png", 14, 20)
    im = canvas(80, 24)
    d = ImageDraw.Draw(im)
    ellipse(d, (2, 2, 78, 22), None, (235, 248, 255, 255), 2)
    save(im, "agua/onda.png", 80, 24)


def chime():
    im = canvas(60, 150)
    d = ImageDraw.Draw(im)
    d.line(S(30, 0, 30, 16), fill=INK, width=2 * SS)
    d.pieslice(S(6, 12, 54, 70), 180, 360, fill=(180, 220, 230, 230), outline=INK, width=2 * SS)
    d.rectangle(S(6, 40, 54, 44), fill=(180, 220, 230, 230))
    ellipse(d, (18, 22, 30, 32), (240, 120, 120, 255))
    d.line(S(30, 44, 30, 90), fill=INK, width=2 * SS)
    d.rectangle(S(18, 90, 42, 146), fill=(250, 240, 220, 255), outline=INK, width=2 * SS)
    save(im, "ambiente/campanilla.png", 60, 150)
    im = canvas(110, 70)
    d = ImageDraw.Draw(im)
    d.line(S(30, 0, 20, 14), fill=INK, width=2 * SS)
    d.line(S(80, 0, 90, 14), fill=INK, width=2 * SS)
    d.rounded_rectangle(S(4, 14, 106, 66), radius=8 * SS, fill=(205, 170, 120, 255), outline=INK, width=3 * SS)
    for i, x in enumerate((36, 52, 68)):
        d.rectangle(S(x, 30, x + 8, 52), fill=INK)
    save(im, "ambiente/tablilla.png", 110, 70)


if __name__ == "__main__":
    ball("dango/bola_verde.png", (150, 205, 120, 255), (110, 170, 90, 255))
    ball("dango/bola_blanca.png", (252, 250, 244, 255), (214, 206, 192, 255))
    ball("dango/bola_rosa.png", (250, 170, 190, 255), (220, 130, 155, 255))
    sauce(); stick(); shadow()
    tray(); slot(); bowl(); sauce_pot(); bin_(); paw_hint(); table()
    cat_parts(); bubble(); cushion()
    sky(); mountains(); tree(); petal(); steam(); noren(); lantern(); roof(); counter(); water(); chime()
    print("OK ->", os.path.normpath(ROOT))
