'''Generate UMBRA application icons from the original logo geometry.

Renders the UMBRA mark (hex shield + eclipse umbra + claw marks) with
supersampling, then exports every size the Electron client needs.
'''

import math
from pathlib import Path

from PIL import Image, ImageDraw

SS = 4
CANVAS = 128
SIZE = CANVAS * SS

TEAL_LIGHT = (126, 245, 216)
TEAL_MID = (63, 191, 166)
TEAL_DARK = (31, 127, 146)
BACKDROP = (11, 11, 11)

OUT_DIR = Path(__file__).resolve().parent.parent / 'public'
PNG_SIZES = [16, 32, 48, 128, 256, 512, 1024]
ICO_SIZES = [16, 32, 48, 128, 256]


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient_at(t):
    t = max(0.0, min(1.0, t))
    if t < 0.55:
        return lerp(TEAL_LIGHT, TEAL_MID, t / 0.55)
    return lerp(TEAL_MID, TEAL_DARK, (t - 0.55) / 0.45)


def hex_points(cx, cy, r):
    pts = []
    for i in range(6):
        ang = math.radians(-90 + i * 60)
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    return pts


def draw_gradient_ring(draw, box, width, samples=720):
    x0, y0, x1, y1 = box
    step = 360 / samples
    for i in range(samples):
        a0 = i * step
        t = (math.cos(math.radians(a0)) + math.sin(math.radians(a0)) + 2) / 4
        draw.arc(
            [x0, y0, x1, y1],
            start=a0,
            end=a0 + step * 1.6,
            fill=gradient_at(t),
            width=int(round(width)),
        )


def draw_hex_gradient(draw, pts, width):
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        seg = math.hypot(x1 - x0, y1 - y0)
        steps = max(2, int(seg / 2))
        for s in range(steps):
            t0 = s / steps
            t1 = min((s + 1.6) / steps, 1.0)
            ax = x0 + (x1 - x0) * t0
            ay = y0 + (y1 - y0) * t0
            bx = x0 + (x1 - x0) * t1
            by = y0 + (y1 - y0) * t1
            gt = ((ax + ay) / (2 * SIZE)) * 1.6
            draw.line([ax, ay, bx, by], fill=gradient_at(gt), width=int(round(width)))
        draw.ellipse(
            [x1 - width / 2, y1 - width / 2, x1 + width / 2, y1 + width / 2],
            fill=gradient_at(((x1 + y1) / (2 * SIZE)) * 1.6),
        )


def render_logo(bg=True):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = SIZE / CANVAS

    if bg:
        draw.rounded_rectangle(
            [0, 0, SIZE - 1, SIZE - 1], radius=22 * s, fill=BACKDROP
        )

    cx = cy = SIZE / 2
    pts = hex_points(cx, cy, 58 * s)
    draw_hex_gradient(draw, pts, 3 * s)

    ring_r = 30 * s
    draw_gradient_ring(
        draw, (cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r), 3 * s
    )

    disc_r = 30 * s
    crescent = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(crescent)
    for y in range(int(cy - disc_r), int(cy + disc_r) + 1):
        t = (y - (cy - disc_r)) / (2 * disc_r)
        cdraw.line([(cx, y), (cx + disc_r, y)], fill=(*gradient_at(t), 235))
    fade = max(1, int(6 * s))
    for i in range(fade):
        alpha = int(235 * (1 - i / fade))
        cdraw.line(
            [(cx - i, cy - disc_r), (cx - i, cy + disc_r)],
            fill=(*TEAL_MID, alpha),
        )
    img.alpha_composite(crescent)

    core_r = 12 * s
    draw.ellipse([cx - core_r, cy - core_r, cx + core_r, cy + core_r], fill=BACKDROP)

    claws = [
        ((40, 104), (48, 94)),
        ((56, 106), (62, 97)),
        ((72, 106), (78, 97)),
        ((88, 104), (80, 94)),
    ]
    for (ax, ay), (bx, by) in claws:
        draw.line(
            [ax * s, ay * s, bx * s, by * s],
            fill=(*TEAL_MID, 190),
            width=int(round(2.5 * s)),
        )

    return img


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    master = render_logo(True)

    bbox = master.getbbox()
    if bbox:
        master = master.crop(bbox)
    side = max(master.size)
    square = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    square.paste(master, ((side - master.width) // 2, (side - master.height) // 2))
    master = square

    plate = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    ImageDraw.Draw(plate).rounded_rectangle(
        [0, 0, side - 1, side - 1], radius=int(side * 0.17), fill=(*BACKDROP, 255)
    )
    master = Image.alpha_composite(plate, master)

    written = []
    for size in PNG_SIZES:
        name = 'icon_%dx%d.png' % (size, size)
        master.resize((size, size), Image.LANCZOS).save(
            OUT_DIR / name, 'PNG', optimize=True
        )
        written.append(name)

    master.resize((256, 256), Image.LANCZOS).save(
        OUT_DIR / 'favicon.png', 'PNG', optimize=True
    )
    written.append('favicon.png')

    def save_ico(path, sizes):
        base = master.resize((max(sizes), max(sizes)), Image.LANCZOS)
        base.save(path, format='ICO', sizes=[(x, x) for x in sizes])

    save_ico(OUT_DIR / 'icon.ico', ICO_SIZES)
    written.append('icon.ico')
    for x in ICO_SIZES:
        save_ico(OUT_DIR / ('icon_%d.ico' % x), [x])
        written.append('icon_%d.ico' % x)

    print('UMBRA icons written to %s' % OUT_DIR)
    for name in written:
        p = OUT_DIR / name
        print('  %-22s %8d bytes' % (name, p.stat().st_size))


if __name__ == '__main__':
    main()
