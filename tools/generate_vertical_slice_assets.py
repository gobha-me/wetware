#!/usr/bin/env python3
"""Generate a 13-tile 1664x64 (13 frames @ 128x64) isometric urban road/plaza/sidewalk
atlas (straight avenues, 90-degree curved turns, 3-way T-forks, 4-way crosswalk
intersections, Bio-Foundry compound plaza, and pedestrian sidewalks), 128x64 Under-Grid
and Spire tiles, Venice 24/32-bit pixel-art Bio-Foundry megastructure plates (256x288
intact & rubble), and 8-direction character sprite sheets (512x96, 8 frames @ 64x96).
"""

from __future__ import annotations

import math
from pathlib import Path
import struct
import subprocess
import zlib


RGBA = tuple[int, int, int, int]


def clamp8(v: float | int) -> int:
    return max(0, min(255, int(round(v))))


def hash2d(x: int, y: int, seed: int = 1337) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def read_rgba_png(path: Path) -> tuple[int, int, list[RGBA]]:
    data = path.read_bytes()
    w, h = struct.unpack(">II", data[16:24])
    raw = subprocess.check_output(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "rgba", "-"]
    )
    pixels: list[RGBA] = [
        (raw[i], raw[i + 1], raw[i + 2], raw[i + 3]) for i in range(0, len(raw), 4)
    ]
    return w, h, pixels


def write_rgba_png(path: Path, width: int, height: int, pixels: list[RGBA]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        row_start = y * width
        for x in range(width):
            r, g, b, a = pixels[row_start + x]
            raw.extend((r & 0xFF, g & 0xFF, b & 0xFF, a & 0xFF))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    path.write_bytes(png)


def crop_and_resize_nearest(
    w: int,
    h: int,
    pixels: list[RGBA],
    max_w: int,
    max_h: int,
) -> tuple[int, int, list[RGBA]]:
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        row = y * w
        for x in range(w):
            if pixels[row + x][3] >= 32:
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y
    if max_x < min_x or max_y < min_y:
        return max_w, max_h, [(0, 0, 0, 0)] * (max_w * max_h)

    cw = max_x - min_x + 1
    ch = max_y - min_y + 1
    scale = min(max_w / cw, max_h / ch)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))

    out: list[RGBA] = []
    for ny in range(nh):
        sy = min(max_y, min_y + int(ny / scale))
        row = sy * w
        for nx in range(nw):
            sx = min(max_x, min_x + int(nx / scale))
            out.append(pixels[row + sx])
    return nw, nh, out


def compute_sobel_normal_map(
    width: int,
    height: int,
    albedo: list[RGBA],
    bevel_strength: float = 2.2,
    seamless_tile: bool = False,
) -> list[RGBA]:
    def luma(x: int, y: int, fallback: float) -> float:
        cx = max(0, min(width - 1, x))
        cy = max(0, min(height - 1, y))
        r, g, b, a = albedo[cy * width + cx]
        if a < 16:
            return fallback if seamless_tile else 0.0
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

    normals: list[RGBA] = []
    for y in range(height):
        for x in range(width):
            r0, g0, b0, a0 = albedo[y * width + x]
            if a0 < 16:
                normals.append((128, 128, 255, 0))
                continue
            center_luma = (0.299 * r0 + 0.587 * g0 + 0.114 * b0) / 255.0
            gx = (
                -1.0 * luma(x - 1, y - 1, center_luma)
                - 2.0 * luma(x - 1, y, center_luma)
                - 1.0 * luma(x - 1, y + 1, center_luma)
                + 1.0 * luma(x + 1, y - 1, center_luma)
                + 2.0 * luma(x + 1, y, center_luma)
                + 1.0 * luma(x + 1, y + 1, center_luma)
            ) * bevel_strength
            gy = (
                -1.0 * luma(x - 1, y - 1, center_luma)
                - 2.0 * luma(x, y - 1, center_luma)
                - 1.0 * luma(x + 1, y - 1, center_luma)
                + 1.0 * luma(x - 1, y + 1, center_luma)
                + 2.0 * luma(x, y + 1, center_luma)
                + 1.0 * luma(x + 1, y + 1, center_luma)
            ) * bevel_strength
            gz = 1.0
            inv_len = 1.0 / math.sqrt(gx * gx + gy * gy + gz * gz)
            nx = clamp8(((-gx * inv_len) * 0.5 + 0.5) * 255.0)
            ny = clamp8(((-gy * inv_len) * 0.5 + 0.5) * 255.0)
            nz = clamp8(((gz * inv_len) * 0.5 + 0.5) * 255.0)
            normals.append((nx, ny, nz, 255))
    return normals


def generate_iso_diamond_tile(
    mode: str,
) -> tuple[int, int, list[RGBA], list[RGBA]]:
    """Generate a 128x64 locked 2:1 isometric tile for Under-Grid or Spire."""
    w, h = 128, 64
    albedo: list[RGBA] = []
    emissive: list[RGBA] = []
    cx, cy = 63.5, 31.5

    for y in range(h):
        for x in range(w):
            dx = (x - cx) / 64.0
            dy = (y - cy) / 32.0
            dist = abs(dx) + abs(dy)
            if dist > 1.0:
                albedo.append((0, 0, 0, 0))
                emissive.append((0, 0, 0, 0))
                continue

            u = dx + dy
            v = dy - dx
            iu = int(round((u + 1.0) * 32.0))
            iv = int(round((v + 1.0) * 32.0))
            grain = (hash2d(x, y, 101) - 0.5) * 6.0

            if mode == "undergrid":
                frame = dist > 0.90 or abs(u) < 0.04 or abs(v) < 0.04
                pipe_u = abs(u - 0.36) < 0.07
                pipe_glow = pipe_u and (dist < 0.82) and ((iu + iv) % 4 == 0)
                grate_bar = ((iu % 4 == 0) or (iv % 4 == 0))

                if frame:
                    c = clamp8(32 + grain)
                    albedo.append((c, c + 5, c + 10, 255))
                    emissive.append((0, 0, 0, 0))
                elif grate_bar:
                    c = clamp8(24 + grain * 0.6)
                    albedo.append((c, c + 4, c + 8, 255))
                    emissive.append((0, 0, 0, 0))
                elif pipe_glow:
                    albedo.append((22, 135, 92, 255))
                    emissive.append((24, 160, 110, 85))
                else:
                    c = clamp8(12 + grain * 0.4)
                    albedo.append((c, c + 3, c + 6, 240))
                    emissive.append((0, 0, 0, 0))
            else:
                holo_rail = 0.89 < dist <= 0.94
                outer_rail = dist > 0.94
                strut = (iu % 16 == 0 or iv % 16 == 0) and dist <= 0.89

                if holo_rail:
                    albedo.append((175, 48, 135, 240))
                    emissive.append((195, 58, 155, 110))
                elif outer_rail:
                    c = clamp8(44 + grain)
                    albedo.append((c, c + 8, c + 16, 255))
                    emissive.append((0, 0, 0, 0))
                elif strut:
                    c = clamp8(30 + grain * 0.5)
                    albedo.append((c, c + 6, c + 14, 240))
                    emissive.append((0, 0, 0, 0))
                else:
                    c = clamp8(18 + grain * 0.4)
                    albedo.append((c, c + 6, c + 14, 225))
                    emissive.append((0, 0, 0, 0))

    return w, h, albedo, emissive


def render_street_tile_pixel(
    frame_idx: int,
    u: float,
    v: float,
    iu: int,
    iv: int,
    grain: float,
) -> tuple[RGBA, RGBA]:
    """Render a single pixel in (u, v) in [-1, 1]^2 for one of the 13 Street Atlas frames:
    0: Bio-Foundry Compound Plaza (dark reinforced ferro-concrete slabs + hazard border)
    1: Outer Sidewalk & Tech-Plaza Pavement (slate sidewalk blocks + utility hatches)
    2: Straight Road along gx (up=1, un=1, vp=0, vn=0)
    3: Straight Road along gy (up=0, un=0, vp=1, vn=1)
    4: 4-Way Cross Intersection (up=1, un=1, vp=1, vn=1) with 4 zebra crosswalks
    5: T-Fork +v (up=1, un=1, vp=1, vn=0)
    6: T-Fork -v (up=1, un=1, vp=0, vn=1)
    7: T-Fork +u (up=1, un=0, vp=1, vn=1)
    8: T-Fork -u (up=0, un=1, vp=1, vn=1)
    9: 90-deg Curved Turn (+u, +v)
    10: 90-deg Curved Turn (-u, +v)
    11: 90-deg Curved Turn (+u, -v)
    12: 90-deg Curved Turn (-u, -v)
    """
    au, av = abs(u), abs(v)

    # Frame 0: Bio-Foundry Compound Plaza (clean dark ferro-concrete compound slabs, no repeating yellow stripes)
    if frame_idx == 0:
        slab_seam = (iu % 16 == 0) or (iv % 16 == 0)
        sub_seam = (iu % 8 == 0) or (iv % 8 == 0)
        rivet = (iu % 16 in (2, 14)) and (iv % 16 in (2, 14))
        if rivet:
            return (36, 41, 50, 255), (0, 0, 0, 0)
        base = 20 if slab_seam else (24 if sub_seam else 27)
        c = clamp8(base + grain * 0.45)
        return (c, c + 3, c + 8, 255), (0, 0, 0, 0)

    # Frame 1: Outer Pedestrian Sidewalk & Building Apron (clean dark slate pavers, no repeating manholes)
    if frame_idx == 1:
        paver_seam = (iu % 8 == 0) or (iv % 8 == 0)
        border_seam = (iu % 32 == 0) or (iv % 32 == 0)
        base = 21 if border_seam else (25 if paver_seam else 30)
        c = clamp8(base + grain * 0.45)
        return (c, c + 4, c + 9, 255), (0, 0, 0, 0)

    road_w = 0.56
    curb_w = 0.65

    # Frames 9..12: Smooth 90-degree Curved Asphalt Corner Turns
    if frame_idx in (9, 10, 11, 12):
        su = 1.0 if frame_idx in (9, 11) else -1.0
        sv = 1.0 if frame_idx in (9, 10) else -1.0
        r_curve = math.hypot(u - su, v - sv)
        r_inner = 1.0 - road_w       # 0.44
        r_outer = 1.0 + road_w       # 1.56
        in_asphalt = r_inner <= r_curve <= r_outer
        in_curb = (r_inner - 0.09 <= r_curve < r_inner) or (r_outer < r_curve <= r_outer + 0.09)

        if in_curb:
            c = clamp8(66 + grain * 0.6)
            return (c, c + 7, c + 14, 255), (0, 0, 0, 0)
        if not in_asphalt:
            paver_seam = (iu % 8 == 0) or (iv % 8 == 0)
            base = 24 if paver_seam else 30
            c = clamp8(base + grain * 0.45)
            return (c, c + 4, c + 9, 255), (0, 0, 0, 0)

        angle_deg = math.degrees(math.atan2(abs(v - sv), abs(u - su)))
        center_dash = abs(r_curve - 1.0) < 0.038 and (int(angle_deg // 9) % 2 == 0)
        edge_line = abs(r_curve - (r_inner + 0.05)) < 0.026 or abs(r_curve - (r_outer - 0.05)) < 0.026

        if center_dash:
            return (215, 158, 38, 255), (150, 105, 20, 80)
        if edge_line:
            return (96, 108, 124, 255), (0, 0, 0, 0)
        c = clamp8(13 + grain * 0.45)
        return (c, c + 2, c + 5, 255), (0, 0, 0, 0)

    # Connectivity for Straight (2, 3), 4-Way (4), and T-Forks (5, 6, 7, 8)
    conn_map = {
        2: (True, True, False, False),   # Straight along gx (u)
        3: (False, False, True, True),   # Straight along gy (v)
        4: (True, True, True, True),     # 4-Way Cross Intersection
        5: (True, True, True, False),    # T-Fork +v
        6: (True, True, False, True),    # T-Fork -v
        7: (True, False, True, True),    # T-Fork +u
        8: (False, True, True, True),    # T-Fork -u
    }
    up, un, vp, vn = conn_map[frame_idx]

    in_hub = (au < road_w) and (av < road_w)
    in_up = up and (u >= 0.0 and av < road_w)
    in_un = un and (u <= 0.0 and av < road_w)
    in_vp = vp and (v >= 0.0 and au < road_w)
    in_vn = vn and (v <= 0.0 and au < road_w)
    in_road = in_hub or in_up or in_un or in_vp or in_vn

    in_curb_box = (au < curb_w and av < curb_w)
    in_curb_up = up and (u >= 0.0 and av < curb_w)
    in_curb_un = un and (u <= 0.0 and av < curb_w)
    in_curb_vp = vp and (v >= 0.0 and au < curb_w)
    in_curb_vn = vn and (v <= 0.0 and au < curb_w)
    in_curb = (in_curb_box or in_curb_up or in_curb_un or in_curb_vp or in_curb_vn) and not in_road

    if in_curb:
        c = clamp8(66 + grain * 0.6)
        return (c, c + 7, c + 14, 255), (0, 0, 0, 0)

    if not in_road:
        paver_seam = (iu % 8 == 0) or (iv % 8 == 0)
        base = 24 if paver_seam else 30
        c = clamp8(base + grain * 0.45)
        return (c, c + 4, c + 9, 255), (0, 0, 0, 0)

    # Inside asphalt roadbed:
    is_junction = (up or un) and (vp or vn)

    # Zebra crosswalks on branching arms of T-Forks and 4-Way Intersections
    if is_junction:
        cw_up = up and (0.58 <= u <= 0.78) and (av < 0.48) and (iv % 4 in (1, 2))
        cw_un = un and (-0.78 <= u <= -0.58) and (av < 0.48) and (iv % 4 in (1, 2))
        cw_vp = vp and (0.58 <= v <= 0.78) and (au < 0.48) and (iu % 4 in (1, 2))
        cw_vn = vn and (-0.78 <= v <= -0.58) and (au < 0.48) and (iu % 4 in (1, 2))
        if cw_up or cw_un or cw_vp or cw_vn:
            c = clamp8(138 + grain * 0.5)
            return (c, c + 6, c + 12, 255), (0, 0, 0, 0)

        stop_up = up and (0.52 <= u <= 0.55) and (av < 0.50)
        stop_un = un and (-0.55 <= u <= -0.52) and (av < 0.50)
        stop_vp = vp and (0.52 <= v <= 0.55) and (au < 0.50)
        stop_vn = vn and (-0.55 <= v <= -0.52) and (au < 0.50)
        if stop_up or stop_un or stop_vp or stop_vn:
            return (104, 114, 128, 255), (0, 0, 0, 0)

        if math.hypot(u, v) < 0.12:
            return (34, 38, 46, 255), (0, 0, 0, 0)

    # Dashed amber centerline on active road arms (outside junction box)
    outside_box = not (is_junction and au < 0.55 and av < 0.55)
    dash_u = ((up and u >= 0.0) or (un and u <= 0.0)) and (av < 0.038) and (iu % 8 in (2, 3, 4, 5)) and outside_box
    dash_v = ((vp and v >= 0.0) or (vn and v <= 0.0)) and (au < 0.038) and (iv % 8 in (2, 3, 4, 5)) and outside_box
    if dash_u or dash_v:
        return (215, 158, 38, 255), (150, 105, 20, 80)

    # White shoulder edge lines on straight segments
    edge_u = ((up and u >= 0.0) or (un and u <= 0.0)) and (0.49 <= av <= 0.52) and (not is_junction or au >= 0.56)
    edge_v = ((vp and v >= 0.0) or (vn and v <= 0.0)) and (0.49 <= au <= 0.52) and (not is_junction or av >= 0.56)
    if edge_u or edge_v:
        return (96, 108, 124, 255), (0, 0, 0, 0)

    # Curb storm drain grates
    drain_u = not is_junction and (up and un) and (0.52 < av < 0.56) and (iu in (18, 19, 44, 45))
    drain_v = not is_junction and (vp and vn) and (0.52 < au < 0.56) and (iv in (18, 19, 44, 45))
    if drain_u or drain_v:
        return (8, 10, 14, 255), (0, 0, 0, 0)

    c = clamp8(13 + grain * 0.45)
    return (c, c + 2, c + 5, 255), (0, 0, 0, 0)


def generate_street_atlas_sheet() -> tuple[int, int, list[RGBA], list[RGBA]]:
    """Generate a 1664x64 (13 frames @ 128x64) isometric street/road/plaza/sidewalk tile atlas."""
    fw, fh = 128, 64
    frames = 13
    w, h = fw * frames, fh
    albedo: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    emissive: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    cx, cy = 63.5, 31.5

    for frame_idx in range(frames):
        ox = frame_idx * fw
        for y in range(fh):
            for x in range(fw):
                dx = (x - cx) / 64.0
                dy = (y - cy) / 32.0
                dist = abs(dx) + abs(dy)
                if dist > 1.0:
                    continue
                u = dx + dy
                v = dy - dx
                iu = int(round((u + 1.0) * 32.0))
                iv = int(round((v + 1.0) * 32.0))
                grain = (hash2d(x + ox, y, 101) - 0.5) * 6.0

                alb, emi = render_street_tile_pixel(frame_idx, u, v, iu, iv, grain)
                idx = y * w + (ox + x)
                albedo[idx] = alb
                emissive[idx] = emi

    return w, h, albedo, emissive


def clean_magenta_spill(r: int, g: int, b: int, a: int) -> RGBA:
    if a < 32:
        return (0, 0, 0, 0)
    if r > 150 and b > 110 and g < 110 and (r + b) > (g * 2 + 120):
        return (0, 0, 0, 0)
    if r > 120 and b > 100 and (r - g) > 45 and (b - g) > 35:
        avg = (r + g + b) // 3
        return (clamp8(avg * 0.7), clamp8(avg * 0.75), clamp8(avg * 0.85), 255)
    return (r, g, b, 255)


def process_venice_building(
    nobg_path: Path,
    target_w: int,
    target_h: int,
    is_rubble: bool,
) -> tuple[list[RGBA], list[RGBA]]:
    sw, sh, raw_px = read_rgba_png(nobg_path)
    cleaned_px = [clean_magenta_spill(r, g, b, a) for (r, g, b, a) in raw_px]
    nw, nh, resized_px = crop_and_resize_nearest(sw, sh, cleaned_px, target_w - 8, target_h - 8)

    albedo: list[RGBA] = [(0, 0, 0, 0)] * (target_w * target_h)
    emissive: list[RGBA] = [(0, 0, 0, 0)] * (target_w * target_h)
    ox = (target_w - nw) // 2
    oy = target_h - nh - 4

    for py in range(nh):
        for px in range(nw):
            cr, cg, cb, ca = resized_px[py * nw + px]
            if ca == 0:
                continue
            idx = (oy + py) * target_w + (ox + px)
            albedo[idx] = (cr, cg, cb, 255)

            is_emerald_glow = cg > 150 and (cg - cr) > 45
            is_orange_slag = is_rubble and cr > 195 and cg > 85 and cb < 90
            is_yellow_beacon = not is_rubble and cr > 195 and cg > 155 and cb < 70
            if is_emerald_glow:
                emissive[idx] = (cr, cg, cb, 210)
            elif is_orange_slag:
                emissive[idx] = (cr, cg, cb, 225)
            elif is_yellow_beacon:
                emissive[idx] = (cr, cg, cb, 120)

    return albedo, emissive


def process_venice_character_sheet(
    nobg_path: Path,
    archetype: str,
) -> tuple[int, int, list[RGBA], list[RGBA]]:
    fw, fh = 64, 96
    frames = 8
    w, h = fw * frames, fh

    sw, sh, raw_px = read_rgba_png(nobg_path)
    cleaned_px = [clean_magenta_spill(r, g, b, a) for (r, g, b, a) in raw_px]
    base_w, base_h, base_px = crop_and_resize_nearest(sw, sh, cleaned_px, fw - 10, 76)

    sheet_albedo: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    sheet_emissive: list[RGBA] = [(0, 0, 0, 0)] * (w * h)

    dir_configs = [
        (False, 1.00, 1.00),   # 0: S
        (False, 0.94, 0.98),   # 1: SE
        (False, 0.88, 0.95),   # 2: E
        (False, 0.92, 0.88),   # 3: NE
        (True,  0.96, 0.82),   # 4: N
        (True,  0.92, 0.88),   # 5: NW
        (True,  0.88, 0.95),   # 6: W
        (True,  0.94, 0.98),   # 7: SW
    ]

    for frame_idx, (flip_x, width_scale, shade_mul) in enumerate(dir_configs):
        ox = frame_idx * fw
        cw = max(1, int(round(base_w * width_scale)))
        ch = base_h

        for y in range(78, 93):
            for x in range(8, 56):
                sd = ((x - 31.5) / 16.0) ** 2 + ((y - 86.0) / 5.0) ** 2
                if sd <= 1.0:
                    idx = y * w + (ox + x)
                    if 0.78 <= sd <= 1.0:
                        if archetype == "operative":
                            sheet_albedo[idx] = (36, 210, 235, 195)
                            sheet_emissive[idx] = (36, 210, 235, 120)
                        elif archetype == "guard":
                            sheet_albedo[idx] = (235, 145, 32, 185)
                            sheet_emissive[idx] = (235, 145, 32, 110)
                        else:
                            sheet_albedo[idx] = (90, 155, 195, 140)
                    else:
                        sheet_albedo[idx] = (6, 8, 12, 175)

        px_x0 = (fw - cw) // 2
        px_y0 = 88 - ch

        for py in range(ch):
            for px in range(cw):
                src_x = min(base_w - 1, int(px / width_scale))
                if flip_x:
                    src_x = (base_w - 1) - src_x
                r, g, b, a = base_px[py * base_w + src_x]
                if a < 64:
                    continue
                tx = px_x0 + px
                ty = px_y0 + py
                if not (0 <= tx < fw and 0 <= ty < fh):
                    continue
                idx = ty * w + (ox + tx)

                sr = clamp8(r * shade_mul)
                sg = clamp8(g * shade_mul)
                sb = clamp8(b * shade_mul)
                sheet_albedo[idx] = (sr, sg, sb, 255)

                if archetype == "operative" and r > 175 and (r - g) > 65:
                    sheet_emissive[idx] = (r, g, b, 230)
                elif archetype == "guard" and r > 190 and g > 110 and b < 90:
                    sheet_emissive[idx] = (r, g, b, 220)
                elif archetype == "civilian" and b > 185 and g > 140 and (b - r) > 60:
                    sheet_emissive[idx] = (r, g, b, 210)
                else:
                    sheet_emissive[idx] = (0, 0, 0, 0)

    return w, h, sheet_albedo, sheet_emissive


def save_asset_triplet(
    albedo_dir: Path,
    normals_dir: Path,
    stem: str,
    w: int,
    h: int,
    albedo: list[RGBA],
    emissive: list[RGBA],
    seamless_tile: bool = False,
) -> None:
    normal = compute_sobel_normal_map(w, h, albedo, seamless_tile=seamless_tile)
    write_rgba_png(albedo_dir / f"{stem}_albedo.png", w, h, albedo)
    write_rgba_png(albedo_dir / f"{stem}_emissive.png", w, h, emissive)
    write_rgba_png(normals_dir / f"{stem}_normal.png", w, h, normal)


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    tiles_dir = repo_root / "godot" / "assets" / "tiles"
    sprites_dir = repo_root / "godot" / "assets" / "sprites"
    normals_dir = repo_root / "godot" / "assets" / "normals"
    venice_dir = Path("/tmp/venice_buildings")

    for mode, stem in (
        ("undergrid", "undergrid_grate"),
        ("spire", "spire_skybridge"),
    ):
        tw, th, albedo, emissive = generate_iso_diamond_tile(mode)
        save_asset_triplet(tiles_dir, normals_dir, stem, tw, th, albedo, emissive, seamless_tile=True)

    sw_atlas, sh_atlas, s_alb, s_emi = generate_street_atlas_sheet()
    save_asset_triplet(tiles_dir, normals_dir, "street_neon", sw_atlas, sh_atlas, s_alb, s_emi, seamless_tile=True)

    if (venice_dir / "biofoundry_intact_nobg.png").exists():
        b_intact_a, b_intact_e = process_venice_building(
            venice_dir / "biofoundry_intact_nobg.png", 256, 288, is_rubble=False
        )
        save_asset_triplet(tiles_dir, normals_dir, "biofoundry_tower_intact", 256, 288, b_intact_a, b_intact_e)

    if (venice_dir / "biofoundry_rubble_nobg.png").exists():
        b_rubble_a, b_rubble_e = process_venice_building(
            venice_dir / "biofoundry_rubble_nobg.png", 256, 288, is_rubble=True
        )
        save_asset_triplet(tiles_dir, normals_dir, "biofoundry_tower_rubble", 256, 288, b_rubble_a, b_rubble_e)

    for arch, stem, src_name in (
        ("operative", "operative_trenchcoat", "operative_nobg.png"),
        ("guard", "corp_sec_guard", "guard_nobg.png"),
        ("civilian", "megacity_civilian", "civilian_nobg.png"),
    ):
        src_path = venice_dir / src_name
        if src_path.exists():
            sw, sh, s_albedo, s_emissive = process_venice_character_sheet(src_path, arch)
            save_asset_triplet(sprites_dir, normals_dir, stem, sw, sh, s_albedo, s_emissive)

    print("Generated 13-tile 1664x64 Street Road/Fork/Turn/Plaza Atlas and Venice 32-bit sprites.")


if __name__ == "__main__":
    main()
