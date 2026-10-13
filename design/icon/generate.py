"""Generates the Tangelo app icon as SVG: a citrus wedge that doubles as a play button.

Run via scripts/make-icon.sh, which renders it and fills the asset catalog.
Usage: python3 -I design/icon/generate.py <output.svg>
"""
import math
import sys

S = 1024  # canvas
C = 512   # center
WEDGE_RADIUS = 560
WEDGE_HALF_ANGLE = 30
# Optical centering: the wedge's bounding box sits this far right of center. The pointed apex makes
# the shape feel left-light, so pure box-centering looks off; 36px was picked by eye at Dock size.
BBOX_OFFSET = 36


def squircle(cx=C, cy=C, a=412, n=5.0, steps=360):
    """macOS-style continuous-corner tile (superellipse) on the 824px icon grid."""
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        pts.append(f"{cx + a * math.copysign(abs(ct) ** (2 / n), ct):.1f},"
                   f"{cy + a * math.copysign(abs(st) ** (2 / n), st):.1f}")
    return "M" + " L".join(pts) + " Z"


def wedge_path(ax, ay, R, half_deg, r_apex, r_back):
    """Wedge pointing right with its apex at (ax, ay), a curved back, and softened corners."""
    h = math.radians(half_deg)
    p1 = (ax - R * math.cos(h), ay - R * math.sin(h))
    p2 = (ax - R * math.cos(h), ay + R * math.sin(h))

    def toward(a, b, d):
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy)
        return (a[0] + dx / length * d, a[1] + dy / length * d)

    d = r_apex / math.tan(h)
    e1, e2 = toward((ax, ay), p1, d), toward((ax, ay), p2, d)
    b1, b2 = toward(p1, (ax, ay), r_back), toward(p2, (ax, ay), r_back)
    da = r_back / R
    c1 = (ax - R * math.cos(h + da), ay - R * math.sin(h + da))
    c2 = (ax - R * math.cos(h + da), ay + R * math.sin(h + da))
    f = lambda p: f"{p[0]:.1f},{p[1]:.1f}"
    return (f"M{f(e1)} L{f(b1)} Q{f(p1)} {f(c1)} A{R},{R} 0 0 0 {f(c2)} "
            f"Q{f(p2)} {f(b2)} L{f(e2)} Q{ax:.1f},{ay:.1f} {f(e1)} Z")


def icon():
    body = squircle()
    R, half = WEDGE_RADIUS, WEDGE_HALF_ANGLE
    ax, ay = C + BBOX_OFFSET + R / 2, C + 4  # box spans ax - R .. ax, so its center is ax - R/2
    rind = wedge_path(ax, ay, R, half, r_apex=54, r_back=26)
    flesh = wedge_path(ax, ay, R - 64, half, r_apex=54, r_back=12)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
<defs>
  <filter id="tileShadow" x="-20%" y="-20%" width="140%" height="150%">
    <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#000" flood-opacity="0.28"/>
  </filter>
  <clipPath id="tile"><path d="{body}"/></clipPath>
  <linearGradient id="tileFill" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ff9c3a"/><stop offset="0.55" stop-color="#ff6a1a"/><stop offset="1" stop-color="#df430e"/>
  </linearGradient>
  <radialGradient id="tileGlow" cx="0.3" cy="0.2" r="0.8">
    <stop offset="0" stop-color="#ffd9a0" stop-opacity="0.5"/><stop offset="1" stop-color="#ffd9a0" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.35"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.7"/><stop offset="1" stop-color="#000" stop-opacity="0.12"/>
  </linearGradient>
  <linearGradient id="rindFill" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#fff0e2"/>
  </linearGradient>
  <linearGradient id="fleshFill" x1="1" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffc463"/><stop offset="1" stop-color="#ff8f2e"/>
  </linearGradient>
  <linearGradient id="fleshHighlight" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.28"/><stop offset="0.45" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
  <filter id="wedgeShadow" x="-30%" y="-30%" width="160%" height="170%">
    <feDropShadow dx="0" dy="22" stdDeviation="24" flood-color="#7a2200" flood-opacity="0.4"/>
  </filter>
</defs>
<path d="{body}" fill="#000" filter="url(#tileShadow)"/>
<g clip-path="url(#tile)">
  <path d="{body}" fill="url(#tileFill)"/>
  <path d="{body}" fill="url(#sheen)" opacity="0.5"/>
  <path d="{body}" fill="url(#tileGlow)"/>
  <g filter="url(#wedgeShadow)"><path d="{rind}" fill="url(#rindFill)"/></g>
  <path d="{flesh}" fill="url(#fleshFill)"/>
  <path d="{flesh}" fill="url(#fleshHighlight)"/>
</g>
<path d="{body}" fill="none" stroke="url(#rim)" stroke-width="3" opacity="0.6"/>
</svg>
'''


if __name__ == "__main__":
    with open(sys.argv[1], "w") as fh:
        fh.write(icon())
