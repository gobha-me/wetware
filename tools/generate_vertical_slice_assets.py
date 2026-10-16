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


def extract_base_character_from_sheet_or_nobg(
    nobg_path: Path | None,
    existing_albedo_path: Path,
) -> tuple[int, int, list[RGBA]]:
    if nobg_path is not None and nobg_path.exists():
        sw, sh, raw_px = read_rgba_png(nobg_path)
        cleaned_px = [clean_magenta_spill(r, g, b, a) for (r, g, b, a) in raw_px]
        return crop_and_resize_nearest(sw, sh, cleaned_px, 54, 76)

    # Extract Frame 0 character body (rows y=4..79, cols x=0..63) from existing sheet
    sw, sh, raw_px = read_rgba_png(existing_albedo_path)
    sub_w, sub_h = 64, 77
    sub_px: list[RGBA] = [(0, 0, 0, 0)] * (sub_w * sub_h)
    for y in range(sub_h):
        for x in range(sub_w):
            sub_px[y * sub_w + x] = raw_px[y * sw + x]
    return crop_and_resize_nearest(sub_w, sub_h, sub_px, 54, 76)


def process_venice_character_sheet(
    nobg_path: Path | None,
    existing_albedo_path: Path,
    archetype: str,
) -> tuple[int, int, list[RGBA], list[RGBA]]:
    """Generates a 512x384 (hframes=8 directions x vframes=4 animation rows @ 64x96) sheet.
    Row 0: Idle / Ready Stance
    Row 1: Walk/Sprint Stride Phase A (Left Boot Forward/Up, Right Boot Back, Coat Sweep +)
    Row 2: Walk/Sprint Stride Phase B (Right Boot Forward/Up, Left Boot Back, Coat Sweep -)
    Row 3: Braced Combat Fire + Muzzle Flash (or Panic Sprint for Civilians)
    """
    fw, fh = 64, 96
    hframes, vframes = 8, 4
    w, h = fw * hframes, fh * vframes

    base_w, base_h, base_px = extract_base_character_from_sheet_or_nobg(nobg_path, existing_albedo_path)

    sheet_albedo: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    sheet_emissive: list[RGBA] = [(0, 0, 0, 0)] * (w * h)

    dir_configs = [
        (False, 1.00, 1.00,  0,  1),   # 0: S
        (False, 0.94, 0.98,  1,  1),   # 1: SE
        (False, 0.88, 0.95,  1,  0),   # 2: E
        (False, 0.92, 0.88,  1, -1),   # 3: NE
        (True,  0.96, 0.82,  0, -1),   # 4: N
        (True,  0.92, 0.88, -1, -1),   # 5: NW
        (True,  0.88, 0.95, -1,  0),   # 6: W
        (True,  0.94, 0.98, -1,  1),   # 7: SW
    ]

    for row_idx in range(vframes):
        oy = row_idx * fh
        for frame_idx, (flip_x, width_scale, shade_mul, dir_x, dir_y) in enumerate(dir_configs):
            ox = frame_idx * fw
            cw = max(1, int(round(base_w * width_scale)))
            ch = base_h

            # Ground contact shadow + subtle tactical foot ring
            for y in range(78, 93):
                for x in range(8, 56):
                    sd = ((x - 31.5) / 16.0) ** 2 + ((y - 86.0) / 5.0) ** 2
                    if sd <= 1.0:
                        idx = (oy + y) * w + (ox + x)
                        if 0.78 <= sd <= 1.0:
                            if archetype.startswith("operative"):
                                sheet_albedo[idx] = (36, 210, 235, 195)
                                sheet_emissive[idx] = (36, 210, 235, 120)
                            elif archetype == "guard":
                                sheet_albedo[idx] = (235, 145, 32, 185)
                                sheet_emissive[idx] = (235, 145, 32, 110)
                            else:
                                sheet_albedo[idx] = (90, 155, 195, 125)
                        else:
                            sheet_albedo[idx] = (6, 8, 12, 180)

            px_x0 = (fw - cw) // 2
            px_y0 = 88 - ch

            # Hole-free inverse mapping over destination cell (tx, ty)
            for ty in range(max(0, px_y0 - 4), min(fh, px_y0 + ch + 4)):
                py = ty - px_y0
                y_norm = max(0.0, min(1.0, py / float(max(1, ch - 1))))
                for tx in range(max(0, px_x0 - 6), min(fw, px_x0 + cw + 6)):
                    px = tx - px_x0
                    x_norm = (px / float(max(1, cw - 1))) - 0.5  # -0.5 (left) .. +0.5 (right)

                    # Compute smooth inverse anatomical offset (off_x, off_y)
                    off_x = 0.0
                    off_y = 0.0
                    if row_idx == 1:  # Stride Phase A (Left boot lifted & forward, right boot planted)
                        off_y = 2.0  # Torso stride bob
                        off_x = float(dir_x) * (1.0 - y_norm * 0.5)
                        if 0.42 <= y_norm <= 0.78:
                            # Coat / jacket hem wind sweep
                            off_x += 2.2 * math.sin((y_norm - 0.42) / 0.36 * math.pi)
                        if y_norm > 0.54:
                            leg_t = (y_norm - 0.54) / 0.46
                            if x_norm < -0.02:
                                off_y -= 4.5 * leg_t  # Left boot lifts up
                                off_x -= 2.0 * leg_t
                            elif x_norm > 0.02:
                                off_y += 1.0 * leg_t  # Right boot planted
                                off_x += 1.5 * leg_t
                    elif row_idx == 2:  # Stride Phase B (Right boot lifted & forward, left boot planted)
                        off_y = 2.0
                        off_x = float(dir_x) * (1.0 - y_norm * 0.5)
                        if 0.42 <= y_norm <= 0.78:
                            off_x -= 2.2 * math.sin((y_norm - 0.42) / 0.36 * math.pi)
                        if y_norm > 0.54:
                            leg_t = (y_norm - 0.54) / 0.46
                            if x_norm > 0.02:
                                off_y -= 4.5 * leg_t  # Right boot lifts up
                                off_x += 2.0 * leg_t
                            elif x_norm < -0.02:
                                off_y += 1.0 * leg_t  # Left boot planted
                                off_x -= 1.5 * leg_t
                    elif row_idx == 3:  # Braced Combat Fire / Panic Sprint Crouch
                        off_y = 3.5 * (1.0 - y_norm * 0.65)
                        off_x = float(dir_x) * 1.8 * (1.0 - y_norm * 0.5)
                        if y_norm > 0.55:
                            leg_t = (y_norm - 0.55) / 0.45
                            off_x += (2.2 if x_norm > 0.0 else -2.2) * leg_t

                    src_px = px - off_x
                    src_py = int(round(py - off_y))
                    if not (0 <= src_py < ch and 0.0 <= src_px < cw):
                        continue
                    src_x = min(base_w - 1, max(0, int(src_px / width_scale)))
                    if flip_x:
                        src_x = (base_w - 1) - src_x
                    r, g, b, a = base_px[src_py * base_w + src_x]
                    if a < 64:
                        continue

                    idx = (oy + ty) * w + (ox + tx)
                    sr = clamp8(r * shade_mul)
                    sg = clamp8(g * shade_mul)
                    sb = clamp8(b * shade_mul)
                    sheet_albedo[idx] = (sr, sg, sb, 255)

                    if archetype.startswith("operative") and (
                        (r > 175 and (r - g) > 65) or (b > 195 and (b - r) > 55)
                    ):
                        sheet_emissive[idx] = (r, g, b, 235)
                    elif archetype == "guard" and r > 190 and g > 110 and b < 90:
                        sheet_emissive[idx] = (r, g, b, 225)
                    elif archetype.startswith("civilian") and b > 185 and g > 140 and (b - r) > 60:
                        sheet_emissive[idx] = (r, g, b, 190)
                    else:
                        sheet_emissive[idx] = (0, 0, 0, 0)

            # Row 3 Muzzle Flash Star for Operatives & Guards
            if row_idx == 3 and (archetype.startswith("operative") or archetype == "guard"):
                flash_cx = 32 + dir_x * 16
                flash_cy = 48 + dir_y * 6
                is_cyan = archetype == "operative_female"
                for fy in range(-6, 7):
                    for fx in range(-6, 7):
                        tx = flash_cx + fx
                        ty = flash_cy + fy
                        if not (0 <= tx < fw and 0 <= ty < fh):
                            continue
                        dist = math.hypot(fx, fy)
                        on_spike = (abs(fx) <= 1 and abs(fy) <= 6) or (abs(fy) <= 1 and abs(fx) <= 6)
                        if dist <= 2.4:
                            idx = (oy + ty) * w + (ox + tx)
                            sheet_albedo[idx] = (255, 250, 220, 255)
                            sheet_emissive[idx] = (255, 250, 220, 255)
                        elif dist <= 4.5 or on_spike:
                            idx = (oy + ty) * w + (ox + tx)
                            fc = (65, 235, 255, 245) if is_cyan else (255, 175, 48, 245)
                            sheet_albedo[idx] = fc
                            sheet_emissive[idx] = fc

    return w, h, sheet_albedo, sheet_emissive


def generate_isometric_tenement_block(facade_path: Path) -> tuple[int, int, list[RGBA], list[RGBA]]:
    """Projects the 32-bit Kowloon tenement facade onto a locked 2:1 isometric prism (256x256)."""
    w, h = 256, 256
    albedo: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    emissive: list[RGBA] = [(0, 0, 0, 0)] * (w * h)

    sw, sh, raw_px = read_rgba_png(facade_path)
    cleaned_px = [clean_magenta_spill(r, g, b, a) for (r, g, b, a) in raw_px]
    fw, fh, fac_px = crop_and_resize_nearest(sw, sh, cleaned_px, 224, 140)

    # Isometric footprint centered at (128, 196), half-width=104, half-depth=52, wall_h=126
    cx, cy = 128, 242
    hw, hd = 104, 52
    wall_h = 128

    # 1. Left Isometric Wall (x in cx-hw .. cx) & Right Isometric Wall (x in cx .. cx+hw)
    for x in range(cx - hw, cx + hw):
        if x < cx:
            t = (x - (cx - hw)) / float(hw)  # 0..1 along SW wall
            y_bot = int(round((cy - hd) + t * hd))
            shade = 0.96
            src_x = min(fw - 1, int(t * (fw * 0.52)))
        else:
            t = (x - cx) / float(hw)  # 0..1 along SE wall
            y_bot = int(round(cy - t * hd))
            shade = 0.72
            src_x = min(fw - 1, int((0.48 + t * 0.52) * (fw - 1)))

        y_top = y_bot - wall_h
        for y in range(max(0, y_top), min(h, y_bot)):
            vt = (y - y_top) / float(wall_h)
            src_y = min(fh - 1, max(0, int(vt * (fh - 1))))
            r, g, b, a = fac_px[src_y * fw + src_x]
            if a < 80:
                r, g, b = 32, 40, 48
            idx = y * w + x
            sr = clamp8(r * shade)
            sg = clamp8(g * shade)
            sb = clamp8(b * shade)
            # Corner pillar bevel at x == cx
            if abs(x - cx) <= 2:
                sr, sg, sb = clamp8(sr * 1.22), clamp8(sg * 1.22), clamp8(sb * 1.22)
            albedo[idx] = (sr, sg, sb, 255)

            # Warm amber apartment windows & red neon Kanji signage emissive mask
            is_warm_win = (r > 195 and g > 120 and (r - b) > 75)
            is_red_sign = (r > 185 and (r - g) > 70 and g < 110)
            if is_warm_win or is_red_sign:
                emissive[idx] = (r, g, b, 225)

    # 2. 2:1 Isometric Roof Diamond centered at (cx, cy - hd - wall_h) = (128, 62)
    rcx, rcy = cx, cy - hd - wall_h
    for y in range(max(0, rcy - hd - 4), min(h, rcy + hd + 4)):
        for x in range(max(0, rcx - hw - 4), min(w, rcx + hw + 4)):
            dx = (x - rcx) / float(hw)
            dy = (y - rcy) / float(hd)
            md = abs(dx) + abs(dy)
            if md <= 1.0:
                idx = y * w + x
                if md >= 0.90:
                    # Raised concrete roof parapet
                    albedo[idx] = (54, 64, 76, 255)
                else:
                    # Tar-gravel rooftop with grid seams
                    u = dx + dy
                    v = dy - dx
                    seam = abs((u * 4.0) - round(u * 4.0)) < 0.06 or abs((v * 4.0) - round(v * 4.0)) < 0.06
                    base_c = 28 if seam else 36
                    albedo[idx] = (base_c, base_c + 6, base_c + 14, 255)

    # 3. Rooftop HVAC Cooling Units & Warning Beacons on Roof
    for hx, hy in ((102, 54), (126, 46), (148, 58), (118, 70)):
        for y in range(hy - 8, hy + 8):
            for x in range(hx - 11, hx + 11):
                if 0 <= x < w and 0 <= y < h:
                    idx = y * w + x
                    if y < hy - 3:
                        albedo[idx] = (68, 78, 90, 255)
                    else:
                        dist = math.hypot(x - hx, (y - hy) * 1.4)
                        if dist < 5.2:
                            albedo[idx] = (20, 26, 34, 255)
                        else:
                            albedo[idx] = (52, 62, 74, 255)
    # Red rooftop aviation warning beacons
    for bx, by in ((128, 12), (32, 62), (224, 62)):
        for y in range(by - 2, by + 3):
            for x in range(bx - 2, bx + 3):
                if 0 <= x < w and 0 <= y < h:
                    idx = y * w + x
                    albedo[idx] = (255, 58, 48, 255)
                    emissive[idx] = (255, 58, 48, 240)

    return w, h, albedo, emissive


def generate_isometric_corp_block(src_path: Path) -> tuple[int, int, list[RGBA], list[RGBA]]:
    """Crops the upper isometric tower from city_corp_nobg.png and trims its base to a 2:1 isometric diamond."""
    w, h = 256, 256
    sw, sh, raw_px = read_rgba_png(src_path)
    crop_h = int(sh * 0.80)
    trimmed: list[RGBA] = [(0, 0, 0, 0)] * (sw * crop_h)
    for y in range(crop_h):
        for x in range(int(sw * 0.21), int(sw * 0.79)):
            r, g, b, a = clean_magenta_spill(*raw_px[y * sw + x])
            trimmed[y * sw + x] = (r, g, b, a)

    cw, ch, c_px = crop_and_resize_nearest(sw, crop_h, trimmed, 204, 236)
    albedo: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    emissive: list[RGBA] = [(0, 0, 0, 0)] * (w * h)

    x0 = (w - cw) // 2
    y0 = 244 - ch
    cx, cy = 128, 242
    for y in range(ch):
        ty = y0 + y
        for x in range(cw):
            tx = x0 + x
            # Clip bottom edge along 2:1 isometric V-curb (y_bot = cy - abs(tx - cx) * 0.5)
            y_bot = int(round(cy - abs(tx - cx) * 0.5))
            if ty > y_bot:
                continue
            r, g, b, a = c_px[y * cw + x]
            if a < 64:
                continue
            idx = ty * w + tx
            if ty >= y_bot - 3:
                # Reinforced concrete street plinth at base of tower
                albedo[idx] = (46, 56, 68, 255)
            else:
                albedo[idx] = (r, g, b, 255)
                if b > 185 and g > 150 and (b - r) > 55:
                    emissive[idx] = (r, g, b, 220)

    return w, h, albedo, emissive


def generate_isometric_block_rubble() -> tuple[int, int, list[RGBA], list[RGBA]]:
    """Generates a 256x256 locked 2:1 isometric collapsed building ruin with jagged concrete walls, rebar, and glowing slag."""
    w, h = 256, 256
    albedo: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    emissive: list[RGBA] = [(0, 0, 0, 0)] * (w * h)

    cx, cy = 128, 242
    hw, hd = 104, 52

    # 1. Isometric Rubble Pile Base & Crater Interior
    for y in range(cy - hd * 2 - 16, cy + 4):
        for x in range(cx - hw - 4, cx + hw + 4):
            if not (0 <= x < w and 0 <= y < h):
                continue
            dx = (x - cx) / float(hw)
            dy = (y - (cy - hd)) / float(hd)
            md = abs(dx) + abs(dy)
            if md <= 1.04:
                n1 = hash2d(x // 3, y // 2, 701)
                n2 = hash2d(x, y, 709)
                idx = y * w + x
                if md < 0.48 and n1 > 0.36:
                    # Glowing molten slag & fire fissures inside the collapsed core
                    if n2 > 0.62:
                        albedo[idx] = (255, 148, 36, 255)
                        emissive[idx] = (255, 148, 36, 235)
                    elif n2 > 0.38:
                        albedo[idx] = (210, 68, 24, 255)
                        emissive[idx] = (220, 78, 28, 195)
                    else:
                        c = clamp8(26 + n2 * 18)
                        albedo[idx] = (c + 8, c + 4, c, 255)
                else:
                    # Broken ferro-concrete chunks & charred debris
                    chunk = int(n1 * 4.0)
                    base_c = 28 + chunk * 11 + int((n2 - 0.5) * 10)
                    r = clamp8(base_c)
                    g = clamp8(base_c + 4)
                    b = clamp8(base_c + 10)
                    albedo[idx] = (r, g, b, 255)
                    if n1 > 0.86 and n2 > 0.78 and md < 0.82:
                        albedo[idx] = (245, 112, 28, 255)
                        emissive[idx] = (245, 112, 28, 210)

    # 2. Sheared 1-Story Jagged Perimeter Walls & Exposed Bent Rebar
    for x in range(cx - hw, cx + hw):
        if x < cx:
            t = (x - (cx - hw)) / float(hw)
            y_bot = int(round((cy - hd) + t * hd))
            shade = 0.94
        else:
            t = (x - cx) / float(hw)
            y_bot = int(round(cy - t * hd))
            shade = 0.72

        col_hash = hash2d(x // 4, 17, 811)
        fine_hash = hash2d(x, 31, 823)
        jagged_h = int(18 + col_hash * 26 + fine_hash * 8)
        # Deep breach gap near the center of each wall
        if 0.35 < t < 0.65:
            jagged_h = max(8, jagged_h - 16)
        y_top = y_bot - jagged_h

        for y in range(max(0, y_top), min(h, y_bot)):
            idx = y * w + x
            gn = (hash2d(x, y, 839) - 0.5) * 14.0
            if y < y_top + 3:
                # Fractured concrete lip
                c = clamp8((62 + gn) * shade)
            else:
                c = clamp8((44 + gn) * shade)
            albedo[idx] = (c, clamp8(c + 5), clamp8(c + 11), 255)
            # Glowing ember cracks near the sheared wall lip
            if y_top + 2 <= y <= y_top + 5 and hash2d(x // 2, y // 2, 853) > 0.82:
                albedo[idx] = (245, 110, 28, 255)
                emissive[idx] = (245, 110, 28, 215)

        # Exposed rebar spikes sticking up from fractured wall columns
        if x % 9 == 0 and col_hash > 0.35:
            rebar_h = 6 + int(col_hash * 8)
            for ry in range(max(0, y_top - rebar_h), y_top):
                rx = min(w - 1, max(0, x + (1 if ry < y_top - rebar_h // 2 else 0)))
                albedo[ry * w + rx] = (92, 68, 54, 255)

    return w, h, albedo, emissive


def process_venice_landmark(
    nobg_path: Path,
    target_w: int,
    target_h: int,
    is_rubble: bool,
    organ_kind: str,
) -> tuple[list[RGBA], list[RGBA]]:
    """Processes a 256x288 City Organ Landmark (intact or collapsed rubble) with district-specific emissive masks."""
    sw, sh, raw_px = read_rgba_png(nobg_path)
    cleaned_px = [clean_magenta_spill(r, g, b, a) for (r, g, b, a) in raw_px]
    nw, nh, resized_px = crop_and_resize_nearest(sw, sh, cleaned_px, target_w - 8, target_h - 8)

    albedo: list[RGBA] = [(0, 0, 0, 0)] * (target_w * target_h)
    emissive: list[RGBA] = [(0, 0, 0, 0)] * (target_w * target_h)
    ox = (target_w - nw) // 2
    oy = target_h - nh - 4

    for py in range(nh):
        y_frac = py / float(max(1, nh - 1))
        for px in range(nw):
            cr, cg, cb, ca = resized_px[py * nw + px]
            if ca < 32:
                continue

            tx = ox + px
            ty = oy + py

            if is_rubble:
                # Shear the upper 38%..48% of the tower along a jagged collapse contour so rubble is unmistakably lower
                x_dist = abs((px / float(max(1, nw - 1))) - 0.5) * 2.0
                col_n = hash2d(tx // 4, 19, 911)
                fine_n = hash2d(tx, 37, 929)
                cut_frac = 0.36 + x_dist * 0.14 + col_n * 0.10 + fine_n * 0.03
                if y_frac < cut_frac:
                    # Leave occasional bent rebar rods protruding just above the shear line
                    if tx % 7 == 0 and (cut_frac - y_frac) < 0.055 and col_n > 0.4:
                        idx = ty * target_w + tx
                        albedo[idx] = (88, 66, 52, 255)
                    continue

                # Darken/char the surviving lower ruin and inject glowing fracture embers near the shear line
                soot = 0.68 if (y_frac - cut_frac) > 0.04 else 0.82
                cr = clamp8(cr * soot)
                cg = clamp8(cg * soot)
                cb = clamp8(cb * soot)

                if (y_frac - cut_frac) < 0.055 and hash2d(tx // 2, ty // 2, 947) > 0.58:
                    cr, cg, cb = 255, 132, 32

            idx = ty * target_w + tx
            albedo[idx] = (cr, cg, cb, 255)

            # District-specific emissive mask extraction
            is_fire_slag = cr > 190 and cg > 75 and cb < 95 and (cr - cb) > 105
            is_cyan_arc = cb > 180 and cg > 135 and (cb - cr) > 45
            is_magenta_neon = cr > 165 and cb > 145 and cg < 115
            is_gold_amber = cr > 180 and cg > 120 and cb < 105 and (cr - cb) > 85

            if is_rubble and is_fire_slag:
                emissive[idx] = (255, max(110, cg), 32, 235)
            elif organ_kind == "broadcast_spire" and (is_cyan_arc or is_magenta_neon):
                emissive[idx] = (cr, cg, cb, 220 if not is_rubble else 165)
            elif organ_kind == "monorail_hub" and (is_cyan_arc or is_magenta_neon or is_gold_amber):
                emissive[idx] = (cr, cg, cb, 215 if not is_rubble else 160)
            elif organ_kind == "ordinance_foundry" and (is_fire_slag or is_gold_amber):
                emissive[idx] = (cr, cg, cb, 235)
            elif organ_kind == "power_subgrid" and (is_cyan_arc or is_fire_slag):
                emissive[idx] = (cr, cg, cb, 230 if not is_rubble else 185)
            elif organ_kind == "clearinghouse" and (is_gold_amber or is_fire_slag):
                emissive[idx] = (cr, cg, cb, 215 if not is_rubble else 175)

    return albedo, emissive


def save_portrait_square(src_path: Path, dst_path: Path, size: int = 256) -> None:
    sw, sh, raw_px = read_rgba_png(src_path)
    cw, ch, c_px = crop_and_resize_nearest(sw, sh, raw_px, size, size)
    out: list[RGBA] = [(8, 12, 18, 255)] * (size * size)
    x0 = (size - cw) // 2
    y0 = (size - ch) // 2
    for y in range(ch):
        for x in range(cw):
            r, g, b, a = c_px[y * cw + x]
            if a > 16:
                out[(y0 + y) * size + (x0 + x)] = (r, g, b, 255)
    write_rgba_png(dst_path, size, size, out)


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
    venice_m7_dir = Path("/tmp/venice_m7")
    venice_m9_dir = Path("/tmp/venice_m9")

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

    # 5 Remaining District City Organ Landmarks (intact & collapsed rubble)
    landmark_specs = [
        ("broadcast_spire", "broadcast_spire_intact_nobg.png", "broadcast_spire_rubble_nobg.png"),
        ("monorail_hub", "monorail_hub_intact_nobg.png", "monorail_hub_rubble_nobg.png"),
        ("ordinance_foundry", "ordinance_foundry_intact_nobg.png", "ordinance_foundry_rubble_nobg.png"),
        # Use power_subgrid_intact_nobg.png for the sheared rubble state so the 3-Tesla-coil architecture matches!
        ("power_subgrid", "power_subgrid_intact_nobg.png", "power_subgrid_intact_nobg.png"),
        ("clearinghouse", "clearinghouse_intact_nobg.png", "clearinghouse_rubble_nobg.png"),
    ]
    for organ_kind, intact_file, rubble_file in landmark_specs:
        intact_src = venice_m9_dir / intact_file
        if intact_src.exists():
            la, le = process_venice_landmark(intact_src, 256, 288, is_rubble=False, organ_kind=organ_kind)
            save_asset_triplet(tiles_dir, normals_dir, f"{organ_kind}_intact", 256, 288, la, le)
        rubble_src = venice_m9_dir / rubble_file
        if rubble_src.exists():
            ra, re = process_venice_landmark(rubble_src, 256, 288, is_rubble=True, organ_kind=organ_kind)
            save_asset_triplet(tiles_dir, normals_dir, f"{organ_kind}_rubble", 256, 288, ra, re)

    if (venice_m7_dir / "city_tenement_nobg.png").exists():
        tw, th, t_alb, t_emi = generate_isometric_tenement_block(venice_m7_dir / "city_tenement_nobg.png")
        save_asset_triplet(tiles_dir, normals_dir, "city_block_tenement", tw, th, t_alb, t_emi)

    if (venice_m7_dir / "city_corp_nobg.png").exists():
        cw, ch, c_alb, c_emi = generate_isometric_corp_block(venice_m7_dir / "city_corp_nobg.png")
        save_asset_triplet(tiles_dir, normals_dir, "city_block_corp", cw, ch, c_alb, c_emi)

    rw, rh, r_alb, r_emi = generate_isometric_block_rubble()
    save_asset_triplet(tiles_dir, normals_dir, "city_block_rubble", rw, rh, r_alb, r_emi)

    for arch, stem, nobg_candidate in (
        ("operative", "operative_trenchcoat", venice_dir / "operative_nobg.png"),
        ("operative_female", "operative_female", venice_m7_dir / "operative_female_nobg.png"),
        ("guard", "corp_sec_guard", venice_dir / "guard_nobg.png"),
        ("civilian", "megacity_civilian", venice_dir / "civilian_nobg.png"),
        ("civilian_f", "megacity_civilian_f", venice_m7_dir / "civilian_female_nobg.png"),
    ):
        existing_alb = sprites_dir / f"{stem}_albedo.png"
        if nobg_candidate.exists() or existing_alb.exists():
            sw, sh, s_albedo, s_emissive = process_venice_character_sheet(
                nobg_candidate if nobg_candidate.exists() else None,
                existing_alb,
                arch,
            )
            save_asset_triplet(sprites_dir, normals_dir, stem, sw, sh, s_albedo, s_emissive)

    for p_src, p_dst in (
        (venice_m7_dir / "portrait_cryo_f2.png", sprites_dir / "portrait_cryo_f2.png"),
        (venice_m7_dir / "portrait_cryo_m3.png", sprites_dir / "portrait_cryo_m3.png"),
    ):
        if p_src.exists():
            save_portrait_square(p_src, p_dst, 256)

    print("Generated all 6 district landmarks (intact & rubble), city_block_rubble, character sheets, and cryo portraits.")


if __name__ == "__main__":
    main()


