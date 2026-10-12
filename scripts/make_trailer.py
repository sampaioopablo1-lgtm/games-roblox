"""Gera o trailer animado (motion graphics) do jogo: 1920x1080, 30 fps, ~24 s, MP4.

Uso: python3 scripts/make_trailer.py  → assets/trailer_1920x1080.mp4
Requer ffmpeg no PATH. Reaproveita os desenhos de make_art.py.
"""

from __future__ import annotations

import math
import os
import random
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_art as art  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "trailer_1920x1080.mp4")
FRAMES_DIR = os.path.join(os.environ.get("TRAILER_TMP", "/tmp"), "pega_bichos_frames")
W, H, FPS = 1920, 1080, 30
DARK = (20, 20, 30)


def ease_out(t: float) -> float:
    return 1 - (1 - t) ** 3


def ease_in_out(t: float) -> float:
    return 0.5 - 0.5 * math.cos(math.pi * t)


def clamp01(t: float) -> float:
    return max(0.0, min(1.0, t))


_BG_CACHE: dict = {}


def bg(top, bottom) -> Image.Image:
    key = (top, bottom)
    if key not in _BG_CACHE:
        _BG_CACHE[key] = art.gradient((W, H), top, bottom)
    return _BG_CACHE[key].copy()


def rotating_rays(img: Image.Image, t: float, color=(255, 255, 255), alpha=40, n=20):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    cx, cy, r = W // 2, H // 2 + 80, W * 1.5
    rot = t * 0.4
    for i in range(n):
        a0 = rot + (i / n) * 2 * math.pi
        a1 = rot + ((i + 0.5) / n) * 2 * math.pi
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(*color, alpha))
    img.paste(overlay, (0, 0), overlay)


def floor(img: Image.Image, y: int, color=(70, 180, 110)):
    d = ImageDraw.Draw(img)
    d.rectangle((0, y, W, H), fill=color)
    d.line((0, y, W, y), fill=DARK, width=8)


def conveyor(img: Image.Image, y: int, offset: float):
    d = ImageDraw.Draw(img)
    d.rectangle((0, y, W, y + 90), fill=(45, 45, 60), outline=DARK, width=6)
    for x in range(-200, W + 200, 160):
        xx = x + (offset % 160)
        d.rectangle((xx, y + 10, xx + 80, y + 80), fill=(255, 200, 0))


def shadow_text(img, xy, text, size, fill, width=14, anchor="mm"):
    art.outlined_text(img, xy, text, size, fill, DARK, width, anchor)


def pop(scale_t: float) -> float:
    """Escala com 'pop' (passa de 1.0 e volta)."""
    t = clamp01(scale_t)
    return 1 + 0.25 * math.sin(math.pi * t) if t < 1 else 1.0


def draw_scaled_text(img, xy, text, size, fill, scale, width=14):
    if scale <= 0.01:
        return
    shadow_text(img, xy, text, max(8, int(size * scale)), fill, max(2, int(width * scale)))


# --------------------------------------------------------------------------- cenas

def scene_title(t: float, dur: float) -> Image.Image:
    img = bg((120, 60, 220), (30, 20, 70))
    rotating_rays(img, t)
    p = ease_out(clamp01(t / 0.6))
    r = int(260 * p)
    if r > 5:
        art.critter(img, W // 2, H // 2 + 60, r, (90, 230, 160), evil=True, mask=True)
    s = pop(clamp01((t - 0.4) / 0.6)) * ease_out(clamp01((t - 0.4) / 0.4))
    draw_scaled_text(img, (W // 2, 170), "PEGA BICHOS!", 190, (255, 230, 60), s)
    if t > 1.4:
        a = ease_out(clamp01((t - 1.4) / 0.5))
        draw_scaled_text(img, (W // 2, H - 120), "PEGUE • DEFENDA • FIQUE RICO", 80, (255, 255, 255), a, 10)
    art.sparkles(img, 40, seed=int(t * 6))
    return img


def scene_conveyor(t: float, dur: float) -> Image.Image:
    img = bg((255, 150, 60), (200, 60, 120))
    rotating_rays(img, t, alpha=30)
    floor(img, 760, (110, 200, 130))
    conveyor(img, 600, t * 260)
    colors = [(120, 200, 255), (255, 220, 90), (255, 120, 180), (170, 90, 255), (90, 230, 160), (255, 100, 100)]
    for i in range(7):
        x = int((i * 330 + t * 260) % (W + 400)) - 200
        bob = abs(math.sin(t * 6 + i)) * 25
        art.critter(img, x, 560 - int(bob), 95, colors[i % len(colors)])
    shadow_text(img, (W // 2, 150), "COMPRE BICHOS NA ESTEIRA", 110, (255, 255, 255))
    if t > 1.0:
        # dinheiro subindo
        for k in range(6):
            tt = (t * 0.8 + k * 0.17) % 1
            y = int(H - 80 - tt * 500)
            x = 260 + k * 260
            shadow_text(img, (x, y), "+$" + str((k + 1) * 10), 70, (120, 255, 120), 8)
    return img


def scene_steal(t: float, dur: float) -> Image.Image:
    img = bg((255, 110, 40), (120, 30, 160))
    rotating_rays(img, t, alpha=35)
    floor(img, 820, (70, 180, 110))
    # base da vítima (direita)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((1250, 560, 1880, 840), 40, fill=(110, 220, 150), outline=DARK, width=8)
    art.critter(img, 1700, 720, 80, (255, 220, 90))
    # vítima chocada
    shake = int(math.sin(t * 40) * 6) if t > 1.2 else 0
    art.critter(img, 1420 + shake, 700, 100, (255, 120, 180))
    # pegador corre da direita para a esquerda carregando bicho
    p = ease_in_out(clamp01(t / (dur - 0.4)))
    x = int(1500 - p * 1700)
    hop = abs(math.sin(t * 14)) * 40
    y = 640 - int(hop)
    art.critter(img, x, y, 170, (90, 230, 160), evil=True, mask=True)
    art.critter(img, x, y - 230, 85, (255, 180, 60))
    # linhas de velocidade
    for k in range(4):
        d.rounded_rectangle((x + 200, y - 60 + k * 45, x + 330 - k * 25, y - 40 + k * 45), 10, fill=(255, 255, 255))
    shadow_text(img, (W // 2, 150), "SEGURE  E  PARA PEGAR!", 120, (255, 230, 60))
    if t > 1.0:
        shadow_text(img, (1420, 470), "!!!", 110, (255, 255, 255), 8)
        shadow_text(img, (W // 2, 300), "DIRETO DA BASE DO SEU AMIGO!", 80, (255, 255, 255), 10)
    return img


def scene_defend(t: float, dur: float) -> Image.Image:
    img = bg((255, 90, 90), (100, 10, 40))
    rotating_rays(img, t, alpha=35)
    floor(img, 820, (70, 180, 110))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((200, 520, 1100, 840), 40, fill=(110, 220, 150), outline=DARK, width=8)
    art.critter(img, 400, 700, 80, (120, 200, 255))
    art.critter(img, 650, 700, 80, (255, 220, 90))
    art.critter(img, 900, 700, 80, (170, 90, 255))
    # cadeado cai e bate
    p = ease_out(clamp01(t / 0.5))
    ly = int(-300 + p * 620)
    bounce = int(abs(math.sin((t - 0.5) * 12)) * 30 * max(0, 1 - (t - 0.5))) if t > 0.5 else 0
    cx, cy, w = 650, ly - bounce, 260
    d.arc((cx - w * 0.36, cy - 230, cx + w * 0.36, cy - 20), 180, 360, fill=(220, 220, 230), width=36)
    d.rounded_rectangle((cx - w / 2, cy - 40, cx + w / 2, cy + 180), 30, fill=(240, 60, 60), outline=DARK, width=8)
    d.ellipse((cx - 26, cy + 20, cx + 26, cy + 72), fill=DARK)
    # tapa: mão grande vem da direita
    if t > 1.0:
        q = ease_out(clamp01((t - 1.0) / 0.35))
        hx = int(1900 - q * 500)
        art.critter(img, hx + 150, 640, 130, (90, 230, 160), evil=True, mask=True)
        d.ellipse((hx - 160, 560, hx, 720), fill=(255, 220, 180), outline=DARK, width=8)
        if t > 1.3:
            shadow_text(img, (hx - 80, 450), "TAPA!", 120, (255, 240, 80), 12)
            for k in range(8):
                a = k * math.pi / 4 + t * 3
                sx, sy = hx - 80 + int(math.cos(a) * 180), 640 + int(math.sin(a) * 180)
                art.star(img, sx, sy, 24, (255, 255, 255)) if hasattr(art, "star") else None
    shadow_text(img, (W // 2, 150), "TRANQUE E DEFENDA SUA BASE", 105, (255, 255, 255))
    return img


def scene_rare(t: float, dur: float) -> Image.Image:
    img = bg((20, 255, 200), (10, 60, 90))
    rotating_rays(img, t * 2, alpha=50)
    s = pop(clamp01(t / 0.7)) * ease_out(clamp01(t / 0.4))
    r = int(260 * s)
    if r > 5:
        art.critter(img, W // 2, H // 2 + 80, r, (20, 255, 200))
        d = ImageDraw.Draw(img)
        # coroa
        cx, cy = W // 2, H // 2 + 80 - r - 20
        d.polygon([(cx - 160, cy + 40), (cx - 120, cy - 80), (cx - 40, cy), (cx, cy - 120), (cx + 40, cy), (cx + 120, cy - 80), (cx + 160, cy + 40)], fill=(255, 220, 60), outline=DARK, width=8)
    draw_scaled_text(img, (W // 2, 150), "BICHOS SECRETOS", 150, (255, 255, 255), s)
    if t > 0.8:
        draw_scaled_text(img, (W // 2, H - 110), "MUTAÇÕES OURO + DIAMANTE", 85, (255, 230, 60), ease_out(clamp01((t - 0.8) / 0.4)), 10)
    art.sparkles(img, 80, seed=int(t * 10))
    return img


def scene_cta(t: float, dur: float) -> Image.Image:
    img = bg((120, 60, 220), (30, 20, 70))
    rotating_rays(img, t)
    # chuva de moedas
    rng = random.Random(3)
    for k in range(30):
        x = rng.randint(0, W)
        speed = rng.uniform(500, 900)
        y = int((rng.uniform(0, H) + t * speed) % (H + 200)) - 100
        art.coin(img, x, y, rng.randint(30, 60))
    art.critter(img, 420, 640, 220, (90, 230, 160), evil=True, mask=True)
    art.critter(img, 1500, 640, 220, (255, 120, 180))
    s = pop(clamp01(t / 0.6)) * ease_out(clamp01(t / 0.4))
    draw_scaled_text(img, (W // 2, 180), "PEGA BICHOS!", 190, (255, 230, 60), s)
    blink = 1.0 if int(t * 2) % 2 == 0 or t < 1 else 0.85
    draw_scaled_text(img, (W // 2, H - 170), "JOGUE AGORA!", 130, (120, 255, 120), ease_out(clamp01((t - 0.5) / 0.4)) * blink)
    draw_scaled_text(img, (W // 2, H - 60), "+10% de dinheiro por AMIGO no servidor", 55, (255, 255, 255), ease_out(clamp01((t - 0.9) / 0.4)), 7)
    return img


SCENES = [
    (scene_title, 3.5),
    (scene_conveyor, 4.0),
    (scene_steal, 4.5),
    (scene_defend, 4.0),
    (scene_rare, 3.5),
    (scene_cta, 4.5),
]


def transition(a: Image.Image, b: Image.Image, t: float) -> Image.Image:
    """Wipe circular rápido entre cenas."""
    mask = Image.new("L", (W, H), 0)
    r = int(ease_out(t) * W)
    ImageDraw.Draw(mask).ellipse((W // 2 - r, H // 2 - r, W // 2 + r, H // 2 + r), fill=255)
    return Image.composite(b, a, mask)


def render_frames():
    os.makedirs(FRAMES_DIR, exist_ok=True)
    for f in os.listdir(FRAMES_DIR):
        os.remove(os.path.join(FRAMES_DIR, f))
    frame = 0
    trans = 0.35
    for i, (fn, dur) in enumerate(SCENES):
        n = int(dur * FPS)
        nxt = SCENES[i + 1] if i + 1 < len(SCENES) else None
        for k in range(n):
            t = k / FPS
            img = fn(t, dur)
            if nxt and t > dur - trans:
                q = (t - (dur - trans)) / trans
                img = transition(img, nxt[0](0.0, nxt[1]), q)
            img.save(os.path.join(FRAMES_DIR, f"f{frame:05d}.jpg"), quality=92)
            frame += 1
    return frame


def encode():
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-framerate", str(FPS), "-i", os.path.join(FRAMES_DIR, "f%05d.jpg"),
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-profile:v", "high", "-level", "4.0",
        "-b:v", "12M", "-maxrate", "15M", "-bufsize", "30M", "-movflags", "+faststart",
        OUT,
    ], check=True)


if __name__ == "__main__":
    n = render_frames()
    encode()
    print(f"ok: {OUT} ({n} frames, {n / FPS:.1f}s)")
