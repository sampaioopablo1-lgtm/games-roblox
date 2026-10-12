"""Gera ícone (512x512) e capa (1920x1080) do jogo com Pillow.

Uso: python3 scripts/make_art.py  → escreve em assets/
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets")
os.makedirs(OUT, exist_ok=True)

FONT_PATH = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
EMOJI_FALLBACK = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except OSError:
        return ImageFont.truetype(EMOJI_FALLBACK, size)


def gradient(size: tuple[int, int], top: tuple, bottom: tuple) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def rays(img: Image.Image, center: tuple[int, int], color: tuple, count: int = 16, alpha: int = 60):
    """Raios de fundo (estilo thumbnail viral)."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    cx, cy = center
    radius = max(img.size) * 1.5
    for i in range(count):
        a0 = (i / count) * 2 * math.pi
        a1 = ((i + 0.5) / count) * 2 * math.pi
        pts = [
            (cx, cy),
            (cx + radius * math.cos(a0), cy + radius * math.sin(a0)),
            (cx + radius * math.cos(a1), cy + radius * math.sin(a1)),
        ]
        d.polygon(pts, fill=(*color, alpha))
    img.paste(overlay, (0, 0), overlay)


def critter(img: Image.Image, cx: int, cy: int, r: int, body: tuple, evil: bool = False, mask: bool = False):
    """Bicho redondo fofo (mesma linguagem visual do jogo)."""
    d = ImageDraw.Draw(img)
    # sombra
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((cx - r, cy + r * 0.75, cx + r, cy + r * 1.05), fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(r * 0.08))
    img.paste(shadow, (0, 0), shadow)
    # orelhas
    ear = tuple(min(255, int(c * 1.15)) for c in body)
    for s in (-1, 1):
        d.ellipse((cx + s * r * 0.55 - r * 0.28, cy - r * 1.05, cx + s * r * 0.55 + r * 0.28, cy - r * 0.35), fill=ear, outline=(20, 20, 30), width=max(2, r // 25))
    # corpo
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=body, outline=(20, 20, 30), width=max(3, r // 22))
    # brilho
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse((cx - r * 0.7, cy - r * 0.8, cx - r * 0.15, cy - r * 0.35), fill=(255, 255, 255, 110))
    hl = hl.filter(ImageFilter.GaussianBlur(r * 0.06))
    img.paste(hl, (0, 0), hl)
    d = ImageDraw.Draw(img)
    # máscara de pegador
    if mask:
        d.rectangle((cx - r * 0.95, cy - r * 0.35, cx + r * 0.95, cy + r * 0.1), fill=(25, 25, 35))
    # olhos
    eye_r = r * 0.22
    for s in (-1, 1):
        ex, ey = cx + s * r * 0.38, cy - r * 0.12
        d.ellipse((ex - eye_r, ey - eye_r, ex + eye_r, ey + eye_r), fill=(255, 255, 255), outline=(20, 20, 30), width=max(2, r // 30))
        pr = eye_r * 0.5
        d.ellipse((ex - pr + s * pr * 0.3, ey - pr, ex + pr + s * pr * 0.3, ey + pr), fill=(20, 20, 30))
        d.ellipse((ex - pr * 0.4 + s * pr * 0.3, ey - pr * 0.7, ex + s * pr * 0.3, ey - pr * 0.1), fill=(255, 255, 255))
        if evil:  # sobrancelha brava
            d.line((ex - eye_r * 1.1, ey - eye_r * 1.3 + (0 if s < 0 else eye_r * 0.5), ex + eye_r * 1.1, ey - eye_r * 1.3 + (eye_r * 0.5 if s < 0 else 0)), fill=(20, 20, 30), width=max(3, r // 18))
    # boca
    if evil:
        d.arc((cx - r * 0.45, cy + r * 0.05, cx + r * 0.45, cy + r * 0.6), 200, 340, fill=(20, 20, 30), width=max(3, r // 20))
        d.polygon([(cx - r * 0.2, cy + r * 0.3), (cx - r * 0.1, cy + r * 0.45), (cx, cy + r * 0.3)], fill=(255, 255, 255))
    else:
        d.arc((cx - r * 0.35, cy + r * 0.05, cx + r * 0.35, cy + r * 0.5), 20, 160, fill=(20, 20, 30), width=max(3, r // 20))
    # bochechas
    for s in (-1, 1):
        d.ellipse((cx + s * r * 0.62 - r * 0.12, cy + r * 0.18, cx + s * r * 0.62 + r * 0.12, cy + r * 0.38), fill=(255, 130, 150))


def sparkles(img: Image.Image, n: int, seed: int = 7):
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(n):
        x, y, s = rng.randint(0, w), rng.randint(0, h), rng.randint(6, 18)
        d.polygon([(x, y - s), (x + s * 0.3, y), (x, y + s), (x - s * 0.3, y)], fill=(255, 255, 255))
        d.polygon([(x - s, y), (x, y + s * 0.3), (x + s, y), (x, y - s * 0.3)], fill=(255, 255, 255))


def outlined_text(img: Image.Image, xy: tuple, text: str, size: int, fill: tuple, outline: tuple, width: int, anchor: str = "mm"):
    d = ImageDraw.Draw(img)
    f = font(size)
    d.text(xy, text, font=f, fill=outline, stroke_width=width, stroke_fill=outline, anchor=anchor)
    d.text(xy, text, font=f, fill=fill, anchor=anchor)


def coin(img: Image.Image, cx: int, cy: int, r: int):
    d = ImageDraw.Draw(img)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 200, 40), outline=(160, 110, 0), width=max(2, r // 10))
    d.ellipse((cx - r * 0.7, cy - r * 0.7, cx + r * 0.7, cy + r * 0.7), outline=(255, 235, 150), width=max(2, r // 12))
    outlined_text(img, (cx, cy + r * 0.05), "$", int(r * 1.2), (160, 110, 0), (160, 110, 0), 0)


def make_icon():
    img = gradient((512, 512), (120, 60, 220), (30, 20, 70))
    rays(img, (256, 300), (255, 255, 255), 14, 35)
    critter(img, 256, 290, 150, (90, 230, 160), evil=True, mask=True)
    coin(img, 420, 130, 52)
    coin(img, 95, 160, 40)
    sparkles(img, 25, seed=3)
    outlined_text(img, (256, 70), "PEGA", 92, (255, 220, 60), (20, 20, 30), 9)
    outlined_text(img, (256, 455), "BICHOS!", 86, (255, 255, 255), (20, 20, 30), 9)
    img.save(os.path.join(OUT, "icone_512.png"))


def make_thumbnail():
    W, H = 1920, 1080
    img = gradient((W, H), (255, 110, 40), (120, 30, 160))
    rays(img, (960, 620), (255, 255, 255), 20, 40)
    # base (chão) de um lado
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((1180, 640, 1860, 1000), 40, fill=(70, 180, 110), outline=(20, 20, 30), width=8)
    d.rounded_rectangle((1230, 690, 1810, 950), 30, fill=(110, 220, 150))
    # vítima (dono) chocado
    critter(img, 1500, 760, 120, (255, 120, 180))
    # bichos na base
    critter(img, 1300, 880, 60, (120, 200, 255))
    critter(img, 1700, 880, 60, (255, 220, 90))
    # pegador grande carregando bicho
    critter(img, 620, 640, 250, (90, 230, 160), evil=True, mask=True)
    critter(img, 620, 330, 110, (255, 180, 60))
    # cadeado
    d.rounded_rectangle((1110, 540, 1250, 660), 20, fill=(240, 60, 60), outline=(20, 20, 30), width=6)
    d.arc((1130, 470, 1230, 580), 180, 360, fill=(220, 220, 230), width=22)
    d.ellipse((1165, 580, 1195, 610), fill=(20, 20, 30))
    coin(img, 300, 250, 70)
    coin(img, 150, 900, 55)
    coin(img, 1800, 200, 50)
    sparkles(img, 60, seed=11)
    outlined_text(img, (960, 140), "PEGA BICHOS!", 150, (255, 230, 60), (20, 20, 30), 14)
    outlined_text(img, (960, 990), "PEGUE • DEFENDA • FIQUE RICO", 72, (255, 255, 255), (20, 20, 30), 10)
    # selo NOVO
    badge = Image.new("RGBA", (420, 140), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    bd.rounded_rectangle((0, 0, 420, 140), 30, fill=(255, 40, 80), outline=(20, 20, 30), width=8)
    bf = font(78)
    bd.text((210, 72), "NOVO!", font=bf, fill=(255, 255, 255), anchor="mm", stroke_width=5, stroke_fill=(20, 20, 30))
    badge = badge.rotate(12, expand=True, resample=Image.BICUBIC)
    img.paste(badge, (1440, 290), badge)
    img.save(os.path.join(OUT, "capa_1920x1080.png"))


if __name__ == "__main__":
    make_icon()
    make_thumbnail()
    print("ok:", os.listdir(OUT))
