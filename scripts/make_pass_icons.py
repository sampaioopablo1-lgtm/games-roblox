"""Gera ícones 512x512 para os 6 Game Passes e 6 Developer Products.

Uso: python3 scripts/make_pass_icons.py  → escreve em assets/passes/ e assets/produtos/
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_PATH = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
S = 512
DARK = (20, 20, 30)


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_PATH, size)


def gradient(top: tuple, bottom: tuple) -> Image.Image:
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(S):
            px[x, y] = c
    return img


def rays(img: Image.Image, alpha: int = 45):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    cx, cy, n, r = S // 2, S // 2 + 30, 14, S * 1.5
    for i in range(n):
        a0, a1 = (i / n) * 2 * math.pi, ((i + 0.5) / n) * 2 * math.pi
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 255, 255, alpha))
    img.paste(overlay, (0, 0), overlay)


def text(img: Image.Image, xy, s: str, size: int, fill=(255, 255, 255), stroke=DARK, width=8, anchor="mm"):
    d = ImageDraw.Draw(img)
    f = font(size)
    d.text(xy, s, font=f, fill=fill, stroke_width=width, stroke_fill=stroke, anchor=anchor)


def shadow_ellipse(img: Image.Image, box, blur=10, alpha=120):
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse(box, fill=(0, 0, 0, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    img.paste(sh, (0, 0), sh)


def critter(img, cx, cy, r, body, evil=False, mask=False):
    d = ImageDraw.Draw(img)
    shadow_ellipse(img, (cx - r, cy + r * 0.75, cx + r, cy + r * 1.05), r * 0.08)
    ear = tuple(min(255, int(c * 1.15)) for c in body)
    for s_ in (-1, 1):
        d.ellipse((cx + s_ * r * 0.55 - r * 0.28, cy - r * 1.05, cx + s_ * r * 0.55 + r * 0.28, cy - r * 0.35), fill=ear, outline=DARK, width=max(2, r // 25))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=body, outline=DARK, width=max(3, r // 22))
    d = ImageDraw.Draw(img)
    if mask:
        d.rectangle((cx - r * 0.95, cy - r * 0.35, cx + r * 0.95, cy + r * 0.1), fill=(25, 25, 35))
    eye_r = r * 0.22
    for s_ in (-1, 1):
        ex, ey = cx + s_ * r * 0.38, cy - r * 0.12
        d.ellipse((ex - eye_r, ey - eye_r, ex + eye_r, ey + eye_r), fill=(255, 255, 255), outline=DARK, width=max(2, r // 30))
        pr = eye_r * 0.5
        d.ellipse((ex - pr, ey - pr, ex + pr, ey + pr), fill=DARK)
        if evil:
            d.line((ex - eye_r * 1.1, ey - eye_r * 1.3 + (0 if s_ < 0 else eye_r * 0.5), ex + eye_r * 1.1, ey - eye_r * 1.3 + (eye_r * 0.5 if s_ < 0 else 0)), fill=DARK, width=max(3, r // 18))
    if evil:
        d.arc((cx - r * 0.45, cy + r * 0.05, cx + r * 0.45, cy + r * 0.6), 200, 340, fill=DARK, width=max(3, r // 20))
    else:
        d.arc((cx - r * 0.35, cy + r * 0.05, cx + r * 0.35, cy + r * 0.5), 20, 160, fill=DARK, width=max(3, r // 20))
    for s_ in (-1, 1):
        d.ellipse((cx + s_ * r * 0.62 - r * 0.12, cy + r * 0.18, cx + s_ * r * 0.62 + r * 0.12, cy + r * 0.38), fill=(255, 130, 150))


def coin(img, cx, cy, r):
    d = ImageDraw.Draw(img)
    shadow_ellipse(img, (cx - r, cy - r + r * 0.15, cx + r, cy + r + r * 0.15), r * 0.1)
    d = ImageDraw.Draw(img)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 200, 40), outline=(150, 100, 0), width=max(3, r // 10))
    d.ellipse((cx - r * 0.72, cy - r * 0.72, cx + r * 0.72, cy + r * 0.72), outline=(255, 235, 150), width=max(2, r // 12))
    text(img, (cx, cy + r * 0.05), "$", int(r * 1.2), (150, 100, 0), (150, 100, 0), 0)


def star(img, cx, cy, r, fill=(255, 220, 60)):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    ImageDraw.Draw(img).polygon(pts, fill=fill, outline=DARK, width=max(3, r // 12))


def padlock(img, cx, cy, w, color=(240, 60, 60), open_=False):
    d = ImageDraw.Draw(img)
    h = w * 0.85
    shadow_ellipse(img, (cx - w * 0.6, cy + h * 0.3, cx + w * 0.6, cy + h * 0.7), 10)
    d = ImageDraw.Draw(img)
    # alça
    ox = w * 0.35 if open_ else 0
    d.arc((cx - w * 0.36 + ox, cy - h * 1.05, cx + w * 0.36 + ox, cy - h * 0.1), 180, 360, fill=(220, 220, 230), width=int(w * 0.14))
    if not open_:
        d.line((cx - w * 0.36 + w * 0.07, cy - h * 0.55, cx - w * 0.36 + w * 0.07, cy - h * 0.1), fill=(220, 220, 230), width=int(w * 0.14))
        d.line((cx + w * 0.36 - w * 0.07, cy - h * 0.55, cx + w * 0.36 - w * 0.07, cy - h * 0.1), fill=(220, 220, 230), width=int(w * 0.14))
    d.rounded_rectangle((cx - w / 2, cy - h * 0.2, cx + w / 2, cy + h * 0.6), int(w * 0.12), fill=color, outline=DARK, width=8)
    d.ellipse((cx - w * 0.1, cy + h * 0.05, cx + w * 0.1, cy + h * 0.25), fill=DARK)
    d.rectangle((cx - w * 0.04, cy + h * 0.2, cx + w * 0.04, cy + h * 0.42), fill=DARK)


def badge(img, label: str, color=(255, 40, 80)):
    """Faixa inferior com o nome do item."""
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((24, S - 118, S - 24, S - 30), 28, fill=color, outline=DARK, width=7)
    size = 54 if len(label) <= 12 else 44
    text(img, (S // 2, S - 74), label, size, (255, 255, 255), DARK, 6)


# ----------------------------------------------------------------------------- passes

def vip():
    img = gradient((255, 180, 40), (170, 80, 10))
    rays(img)
    star(img, S // 2, 215, 165)
    text(img, (S // 2, 225), "VIP", 120, (255, 255, 255), DARK, 10)
    badge(img, "2x DINHEIRO", (120, 40, 200))
    return img


def auto_collect():
    img = gradient((80, 220, 130), (20, 110, 70))
    rays(img)
    coin(img, 180, 200, 95)
    coin(img, 330, 240, 95)
    # raio
    d = ImageDraw.Draw(img)
    d.polygon([(290, 60), (210, 210), (265, 210), (225, 330), (330, 160), (275, 160)], fill=(255, 240, 80), outline=DARK, width=7)
    badge(img, "AUTO COLETA", (20, 90, 60))
    return img


def extra_slots():
    img = gradient((100, 160, 255), (30, 60, 170))
    rays(img)
    d = ImageDraw.Draw(img)
    # 4 pads
    for i, (x, y) in enumerate([(130, 140), (280, 140), (130, 270), (280, 270)]):
        d.rounded_rectangle((x, y, x + 115, y + 95), 18, fill=(255, 230, 120), outline=DARK, width=6)
        text(img, (x + 57, y + 50), "+", 70, DARK, DARK, 0)
    critter(img, 420, 230, 60, (255, 120, 180))
    badge(img, "+4 VAGAS", (30, 50, 150))
    return img


def super_lock():
    img = gradient((255, 90, 90), (140, 20, 40))
    rays(img)
    padlock(img, S // 2, 230, 220, (240, 60, 60))
    text(img, (S // 2, 265), "120s", 64, (255, 255, 255), DARK, 6)
    badge(img, "SUPER CADEADO", (120, 10, 30))
    return img


def lucky():
    img = gradient((90, 230, 160), (20, 120, 80))
    rays(img)
    d = ImageDraw.Draw(img)
    # trevo de 4 folhas
    cx, cy, r = S // 2, 215, 70
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        d.ellipse((cx + dx * r - r, cy + dy * r - r, cx + dx * r + r, cy + dy * r + r), fill=(40, 190, 90), outline=DARK, width=7)
    d.line((cx, cy + r * 0.5, cx + 25, cy + r * 2.4), fill=DARK, width=16)
    d.line((cx, cy + r * 0.5, cx + 25, cy + r * 2.4), fill=(40, 190, 90), width=8)
    # diamante
    d.polygon([(400, 90), (470, 90), (500, 140), (435, 220), (370, 140)], fill=(120, 240, 255), outline=DARK, width=6)
    badge(img, "SORTUDO", (10, 100, 60))
    return img


def fast_thief():
    img = gradient((170, 90, 255), (60, 20, 130))
    rays(img)
    d = ImageDraw.Draw(img)
    for i, y in enumerate((170, 215, 260)):
        d.rounded_rectangle((40, y, 150 - i * 20, y + 22), 11, fill=(255, 255, 255))
    critter(img, 320, 230, 120, (90, 230, 160), evil=True, mask=True)
    critter(img, 320, 80, 50, (255, 180, 60))
    badge(img, "PEGADOR VELOZ", (80, 20, 170))
    return img


# ----------------------------------------------------------------------------- produtos

def cash_pack(n_coins: int, label: str, top, bottom):
    img = gradient(top, bottom)
    rays(img)
    d = ImageDraw.Draw(img)
    if n_coins == 1:
        # saco
        d.polygon([(256, 110), (190, 200), (150, 330), (362, 330), (322, 200)], fill=(200, 140, 70), outline=DARK, width=7)
        d.rounded_rectangle((150, 300, 362, 360), 40, fill=(200, 140, 70), outline=DARK, width=7)
        d.rounded_rectangle((218, 95, 294, 130), 15, fill=(160, 100, 40), outline=DARK, width=6)
        text(img, (256, 250), "$", 110, (255, 220, 60), DARK, 8)
    elif n_coins == 2:
        # cofre
        d.rounded_rectangle((110, 150, 400, 360), 24, fill=(90, 100, 130), outline=DARK, width=8)
        d.ellipse((205, 205, 305, 305), fill=(60, 70, 95), outline=DARK, width=6)
        d.ellipse((235, 235, 275, 275), fill=(255, 220, 60), outline=DARK, width=5)
        coin(img, 400, 150, 50)
        coin(img, 110, 350, 45)
    else:
        # banco
        d.polygon([(256, 70), (90, 160), (422, 160)], fill=(230, 230, 240), outline=DARK, width=7)
        for x in (120, 200, 280, 360):
            d.rectangle((x, 170, x + 36, 320), fill=(230, 230, 240), outline=DARK, width=5)
        d.rectangle((90, 320, 422, 360), fill=(230, 230, 240), outline=DARK, width=7)
        text(img, (256, 240), "$", 120, (255, 220, 60), DARK, 8)
        coin(img, 420, 100, 45)
        coin(img, 90, 110, 40)
    badge(img, label, (20, 90, 60))
    return img


def server_luck():
    img = gradient((60, 230, 180), (10, 110, 110))
    rays(img)
    d = ImageDraw.Draw(img)
    # globo
    d.ellipse((126, 90, 386, 350), fill=(80, 170, 255), outline=DARK, width=8)
    d.arc((126, 90, 386, 350), 0, 360, fill=DARK, width=4)
    d.ellipse((190, 90, 322, 350), outline=DARK, width=5)
    d.line((126, 220, 386, 220), fill=DARK, width=5)
    text(img, (256, 225), "x2", 110, (255, 240, 80), DARK, 9)
    star(img, 420, 110, 45)
    star(img, 90, 330, 35)
    badge(img, "SORTE SERVER", (10, 90, 90))
    return img


def mythic_drop():
    img = gradient((255, 90, 140), (80, 10, 90))
    rays(img)
    d = ImageDraw.Draw(img)
    for x, y, r in ((110, 110, 22), (400, 90, 18), (440, 300, 16)):
        star(img, x, y, r, (255, 255, 255))
    critter(img, 256, 220, 120, (255, 60, 90))
    # coroa
    d.polygon([(176, 110), (196, 60), (236, 100), (256, 40), (276, 100), (316, 60), (336, 110)], fill=(255, 220, 60), outline=DARK, width=6)
    badge(img, "CHUVA MÍTICA", (120, 10, 80))
    return img


def instant_lock():
    img = gradient((255, 140, 60), (150, 50, 20))
    rays(img)
    padlock(img, S // 2, 230, 200, (240, 60, 60))
    d = ImageDraw.Draw(img)
    d.polygon([(420, 60), (360, 190), (405, 190), (370, 290), (460, 150), (415, 150)], fill=(255, 240, 80), outline=DARK, width=6)
    badge(img, "TRANCA JÁ", (130, 30, 10))
    return img


ITEMS = {
    "passes": {
        "1_vip": vip,
        "2_coleta_automatica": auto_collect,
        "3_mais4_vagas": extra_slots,
        "4_super_cadeado": super_lock,
        "5_sortudo": lucky,
        "6_pegador_veloz": fast_thief,
    },
    "produtos": {
        "1_saco_de_moedas": lambda: cash_pack(1, "SACO MOEDAS", (120, 220, 120), (20, 110, 60)),
        "2_cofre_de_moedas": lambda: cash_pack(2, "COFRE MOEDAS", (100, 200, 140), (20, 100, 80)),
        "3_banco_de_moedas": lambda: cash_pack(3, "BANCO MOEDAS", (80, 190, 160), (10, 90, 90)),
        "4_sorte_do_servidor": server_luck,
        "5_chuva_mitica": mythic_drop,
        "6_cadeado_instantaneo": instant_lock,
    },
}

if __name__ == "__main__":
    for folder, items in ITEMS.items():
        out = os.path.join(ROOT, "assets", folder)
        os.makedirs(out, exist_ok=True)
        for name, fn in items.items():
            fn().save(os.path.join(out, name + ".png"))
        print(folder, sorted(os.listdir(out)))
