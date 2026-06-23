"""Generate world_network.jpg using real Natural Earth geographic data."""
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Polygon as MplPolygon
from matplotlib.collections import PatchCollection
import geopandas as gpd
from shapely.geometry import MultiPolygon, Polygon
from PIL import Image, ImageDraw, ImageFilter

# ── Image size ────────────────────────────────────────────────────────────────
W, H = 1920, 620
DPI  = 100
FW   = W / DPI
FH   = H / DPI

# ── App colour palette ─────────────────────────────────────────────────────────
BG        = '#060810'          # background navy
LAND_FILL = '#0E1A2E'          # continent fill (subtle blue-navy)
LAND_EDGE = '#1C3454'          # continent border
CONN_DIM  = (212, 175, 55, 38)    # RGBA regular connection
CONN_HERO = (212, 175, 55, 110)   # RGBA hero connection
DOT_COLOR = (212, 175, 55, 215)
DOT_CORE  = (255, 248, 210, 255)
GLOW_LINE = (212, 175, 55, 80)
GLOW_DOT  = (212, 175, 55, 60)

# ── Major financial cities  [lon, lat] ────────────────────────────────────────
cities_lonlat = [
    [-74.0,  40.7],   # 0  New York
    [-118.2, 34.0],   # 1  Los Angeles
    [-87.6,  41.9],   # 2  Chicago
    [-79.4,  43.7],   # 3  Toronto
    [-99.1,  19.4],   # 4  Mexico City
    [-123.1, 49.3],   # 5  Vancouver
    [-46.6, -23.5],   # 6  São Paulo
    [-58.4, -34.6],   # 7  Buenos Aires
    [-74.1,   4.7],   # 8  Bogotá
    [  -0.1, 51.5],   # 9  London
    [   2.35,48.9],   # 10 Paris
    [  13.4, 52.5],   # 11 Berlin
    [   4.9, 52.4],   # 12 Amsterdam
    [   8.7, 50.1],   # 13 Frankfurt
    [  29.0, 41.0],   # 14 Istanbul
    [  31.2, 30.1],   # 15 Cairo
    [   3.4,  6.45],  # 16 Lagos
    [  28.1,-26.2],   # 17 Johannesburg
    [  37.6, 55.75],  # 18 Moscow
    [  55.3, 25.2],   # 19 Dubai
    [  72.9, 19.1],   # 20 Mumbai
    [ 100.5, 13.75],  # 21 Bangkok
    [ 101.7,  3.15],  # 22 Kuala Lumpur
    [ 103.8,  1.35],  # 23 Singapore
    [ 116.4, 39.9],   # 24 Beijing
    [ 121.5, 31.2],   # 25 Shanghai
    [ 114.2, 22.3],   # 26 Hong Kong
    [ 127.0, 37.6],   # 27 Seoul
    [ 139.7, 35.7],   # 28 Tokyo
    [ 144.9,-37.8],   # 29 Melbourne
    [ 151.2,-33.9],   # 30 Sydney
    [   8.5, 47.4],   # 31 Zurich
    [  21.0, 52.2],   # 32 Warsaw
    [  -3.7, 40.4],   # 33 Madrid
]

connections = [
    (0,9),(0,2),(3,0),(9,10),(9,11),(9,12),(10,13),(11,18),(14,15),(15,19),
    (15,16),(16,17),(18,14),(18,32),(19,20),(20,21),(21,22),(22,23),(23,26),
    (24,25),(24,27),(25,26),(27,28),(28,25),(28,30),(6,7),(0,6),(9,18),(19,23),(9,31),
]
hero = {0, 2, 9, 17, 22, 26, 27, 28}


# ── Convert lon/lat to pixel (simple equirectangular) ─────────────────────────
def ll_to_px(lon, lat):
    x = (lon + 180) / 360 * W
    y = (90  - lat) / 180 * H
    return x, y


# ── Step 1: Draw world map with matplotlib ────────────────────────────────────
fig, ax = plt.subplots(figsize=(FW, FH), dpi=DPI)
fig.patch.set_facecolor(BG)
ax.set_facecolor(BG)
ax.set_xlim(-180, 180)
ax.set_ylim(-90, 90)
ax.axis('off')
fig.subplots_adjust(left=0, right=1, top=1, bottom=0)

# Load natural earth land polygons (built into geopandas)
import geodatasets
world = gpd.read_file(geodatasets.get_path('naturalearth.land'))

world.plot(
    ax=ax,
    color=LAND_FILL,
    edgecolor=LAND_EDGE,
    linewidth=0.6,
)

# Save matplotlib figure to PIL image
from io import BytesIO
buf = BytesIO()
fig.savefig(buf, format='png', dpi=DPI, bbox_inches='tight',
            pad_inches=0, facecolor=BG)
plt.close(fig)
buf.seek(0)
base = Image.open(buf).convert('RGBA').resize((W, H), Image.LANCZOS)


# ── Step 2: Draw network overlay with PIL ─────────────────────────────────────
canvas = base.copy()

# Glow layer (thick + blurred = soft halo effect)
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gd   = ImageDraw.Draw(glow)

for i, (a, b) in enumerate(connections):
    lx, ly = ll_to_px(*cities_lonlat[a])
    rx, ry = ll_to_px(*cities_lonlat[b])
    h = i in hero
    gd.line([(lx, ly), (rx, ry)],
            fill=(212, 175, 55, 100 if h else 45),
            width=(10 if h else 6))

for lon, lat in cities_lonlat:
    x, y = ll_to_px(lon, lat)
    r = 18
    gd.ellipse([x-r, y-r, x+r, y+r], fill=(212, 175, 55, 65))

glow_b = glow.filter(ImageFilter.GaussianBlur(radius=10))
canvas = Image.alpha_composite(canvas, glow_b)

# Tighter secondary glow for hero routes
glow2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gd2   = ImageDraw.Draw(glow2)
for i, (a, b) in enumerate(connections):
    if i in hero:
        lx, ly = ll_to_px(*cities_lonlat[a])
        rx, ry = ll_to_px(*cities_lonlat[b])
        gd2.line([(lx, ly), (rx, ry)], fill=(230, 195, 80, 75), width=5)
glow2 = glow2.filter(ImageFilter.GaussianBlur(radius=4))
canvas = Image.alpha_composite(canvas, glow2)

# Sharp lines + dots
sharp = Image.new('RGBA', (W, H), (0, 0, 0, 0))
sd    = ImageDraw.Draw(sharp)

for i, (a, b) in enumerate(connections):
    lx, ly = ll_to_px(*cities_lonlat[a])
    rx, ry = ll_to_px(*cities_lonlat[b])
    h = i in hero
    sd.line([(lx, ly), (rx, ry)],
            fill=(212, 175, 55, 130 if h else 50),
            width=(2 if h else 1))
    # static data-flow dots along hero routes
    if h:
        for t in [0.3, 0.65]:
            dx = int(lx + (rx-lx)*t)
            dy = int(ly + (ry-ly)*t)
            sd.ellipse([dx-4, dy-4, dx+4, dy+4], fill=(255, 230, 120, 210))

for lon, lat in cities_lonlat:
    x, y = ll_to_px(lon, lat)
    sd.ellipse([x-5, y-5, x+5, y+5], fill=(212, 175, 55, 200))
    sd.ellipse([x-2, y-2, x+2, y+2], fill=(255, 248, 210, 255))

canvas = Image.alpha_composite(canvas, sharp)

# ── Step 3: Vignette + fades ─────────────────────────────────────────────────
yy, xx = np.ogrid[:H, :W]
vig      = np.zeros((H, W, 4), dtype=np.uint8)
vig_dist = np.clip(np.sqrt(((xx-W/2)/(W*0.52))**2 + ((yy-H/2)/(H*0.52))**2), 0, 1)
vig[:, :, 0] = 6;  vig[:, :, 1] = 8;  vig[:, :, 2] = 14
vig[:, :, 3] = (vig_dist * 185).astype(np.uint8)
canvas = Image.alpha_composite(canvas, Image.fromarray(vig, 'RGBA'))

# Bottom fade
fade      = np.zeros((H, W, 4), dtype=np.uint8)
t_arr     = np.clip((yy / H - 0.58) / 0.42, 0, 1)
fade[:, :, 0] = 6;  fade[:, :, 1] = 8;  fade[:, :, 2] = 14
fade[:, :, 3] = (t_arr * 220).astype(np.uint8)
canvas = Image.alpha_composite(canvas, Image.fromarray(fade, 'RGBA'))

# Top fade (nav-bar readability)
top_fade      = np.zeros((H, W, 4), dtype=np.uint8)
t_top         = np.clip(1 - yy / H / 0.10, 0, 1)
top_fade[:, :, 0] = 6;  top_fade[:, :, 1] = 8;  top_fade[:, :, 2] = 14
top_fade[:, :, 3] = (t_top * 150).astype(np.uint8)
canvas = Image.alpha_composite(canvas, Image.fromarray(top_fade, 'RGBA'))

# ── Step 4: Save ──────────────────────────────────────────────────────────────
out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'images', 'world_network.jpg')
canvas.convert('RGB').save(out, 'JPEG', quality=93, optimize=True)
print(f'Done: {os.path.abspath(out)} ({W}x{H})')
