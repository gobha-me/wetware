#!/usr/bin/env python3
"""Generate HD 24/32-bit isometric pixel-art tiles (128x64), Bio-Foundry megastructure
(256x288 intact & rubble), 8-directional character sprite sheets (512x96, 8 frames @ 64x96),
and 2.5D Sobel normal/emissive maps for the wetware Godot 4.7.2 Kowloon Bio-Foundry slice.

Designed for native 1280x720 virtual canvas (exact 2x integer scale on 2K 2560x1440,
exact 3x integer scale on 4K 3840x2160).
"""

from __future__ import annotations

import math
from pathlib import Path
import struct
import zlib


RGBA = tuple[int, int, int, int]


def clamp8(v: float | int) -> int:
    return max(0, min(255, int(round(v))))


def hash2d(x: int, y: int, seed: int = 1337) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


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


def compute_sobel_normal_map(
    width: int,
    height: int,
    albedo: list[RGBA],
    bevel_strength: float = 2.8,
) -> list[RGBA]:
    def luma(x: int, y: int) -> float:
        cx = max(0, min(width - 1, x))
        cy = max(0, min(height - 1, y))
        r, g, b, a = albedo[cy * width + cx]
        if a == 0:
            return 0.0
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

    normals: list[RGBA] = []
    for y in range(height):
        for x in range(width):
            _, _, _, a = albedo[y * width + x]
            if a == 0:
                normals.append((128, 128, 255, 0))
                continue
            gx = (
                -1.0 * luma(x - 1, y - 1)
                - 2.0 * luma(x - 1, y)
                - 1.0 * luma(x - 1, y + 1)
                + 1.0 * luma(x + 1, y - 1)
                + 2.0 * luma(x + 1, y)
                + 1.0 * luma(x + 1, y + 1)
            ) * bevel_strength
            gy = (
                -1.0 * luma(x - 1, y - 1)
                - 2.0 * luma(x, y - 1)
                - 1.0 * luma(x + 1, y - 1)
                + 1.0 * luma(x - 1, y + 1)
                + 2.0 * luma(x, y + 1)
                + 1.0 * luma(x + 1, y + 1)
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
    """Generate a 128x64 locked 2:1 isometric tile with micro-dithered surface detail."""
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

            # Isometric UV coordinates in [-1, 1] along tile edges
            u = dx + dy
            v = dy - dx
            iu = int(round((u + 1.0) * 32.0))
            iv = int(round((v + 1.0) * 32.0))
            grain = (hash2d(x, y, 101) - 0.5) * 10.0

            if mode == "undergrid":
                # Heavy steel catwalk frame + diamond grate mesh + glowing bio-coolant pipes below
                frame = dist > 0.88 or abs(u) < 0.05 or abs(v) < 0.05
                rivet = frame and ((iu % 8 == 0) and (iv % 8 == 0))
                pipe_u = abs(u - 0.35) < 0.11 or abs(u + 0.35) < 0.11
                pipe_glow = pipe_u and (dist < 0.84) and ((iu + iv) % 3 != 0)
                grate_bar = ((iu % 4 == 0) or (iv % 4 == 0))

                if rivet:
                    albedo.append((86, 98, 110, 255))
                    emissive.append((0, 0, 0, 0))
                elif frame:
                    c = clamp8(46 + grain)
                    albedo.append((c, c + 6, c + 12, 255))
                    emissive.append((0, 0, 0, 0))
                elif grate_bar:
                    c = clamp8(34 + grain * 0.7)
                    albedo.append((c, c + 5, c + 9, 255))
                    emissive.append((0, 0, 0, 0))
                elif pipe_glow:
                    pulse = int(hash2d(iu, iv, 303) * 35.0)
                    albedo.append((24, clamp8(185 + pulse), clamp8(120 + pulse // 2), 255))
                    emissive.append((32, clamp8(235 + pulse // 2), 155, 240))
                else:
                    c = clamp8(14 + grain * 0.5)
                    albedo.append((c, c + 4, c + 8, 245))
                    emissive.append((0, 0, 0, 0))

            elif mode == "spire":
                # High-altitude armored glass & titanium skybridge with magenta/cyan holo-rails
                outer_rail = dist > 0.87
                holo_guide = 0.81 < dist <= 0.87
                center_conduit = abs(u) < 0.09 and dist < 0.81
                strut = (iu % 12 == 0 or iv % 12 == 0) and dist < 0.81

                if holo_guide:
                    albedo.append((245, 68, 188, 250))
                    emissive.append((255, 92, 210, 255))
                elif outer_rail:
                    c = clamp8(72 + grain)
                    albedo.append((c, c + 14, c + 28, 255))
                    emissive.append((0, 0, 0, 0))
                elif center_conduit:
                    albedo.append((48, 220, 248, 245))
                    emissive.append((64, 245, 255, 245))
                elif strut:
                    c = clamp8(50 + grain * 0.6)
                    albedo.append((c, c + 12, c + 24, 245))
                    emissive.append((0, 0, 0, 0))
                else:
                    # Translucent armored skybridge glass panel
                    c = clamp8(26 + grain * 0.5)
                    albedo.append((c, c + 22, c + 44, 220))
                    emissive.append((16, 48, 82, 75))

            else:
                # Street: raised sidewalk border, storm drain grates, wet asphalt, neon traffic lane, rain puddles
                sidewalk = dist > 0.82
                curb_bevel = 0.78 < dist <= 0.82
                hazard_curb = curb_bevel and ((iu + iv) // 4) % 2 == 0
                center_lane = abs(u) < 0.045 and (iv % 10 < 6) and dist < 0.75
                neon_gutter = abs(abs(u) - 0.72) < 0.025 and dist < 0.77
                # Elliptical rain puddle in isometric space
                puddle_dist = ((u - 0.22) * 2.2) ** 2 + ((v + 0.18) * 2.5) ** 2
                puddle2_dist = ((u + 0.30) * 2.6) ** 2 + ((v - 0.24) * 2.2) ** 2
                in_puddle = (puddle_dist < 0.16 or puddle2_dist < 0.12) and dist < 0.72

                if hazard_curb:
                    albedo.append((195, 150, 32, 255))
                    emissive.append((80, 55, 10, 90))
                elif curb_bevel:
                    c = clamp8(54 + grain)
                    albedo.append((c, c + 4, c + 10, 255))
                    emissive.append((0, 0, 0, 0))
                elif sidewalk:
                    slab_joint = (iu % 8 == 0) or (iv % 8 == 0)
                    base = 36 if slab_joint else 46
                    c = clamp8(base + grain * 0.8)
                    albedo.append((c, c + 5, c + 12, 255))
                    emissive.append((0, 0, 0, 0))
                elif center_lane:
                    albedo.append((38, 224, 245, 255))
                    emissive.append((68, 248, 255, 255))
                elif neon_gutter:
                    albedo.append((215, 52, 145, 255))
                    emissive.append((245, 72, 175, 220))
                elif in_puddle:
                    ripple = math.sin(puddle_dist * 45.0) * 12.0
                    r = clamp8(26 + ripple * 0.5)
                    g = clamp8(52 + ripple)
                    b = clamp8(84 + ripple * 1.4)
                    albedo.append((r, g, b, 255))
                    emissive.append((28, 105, 165, 175))
                else:
                    c = clamp8(21 + grain * 0.75)
                    albedo.append((c, c + 3, c + 9, 255))
                    emissive.append((0, 0, 0, 0))

    return w, h, albedo, emissive


def generate_iso_building_facade(
    rubble: bool,
) -> tuple[int, int, list[RGBA], list[RGBA]]:
    """Generate a 256x288 3D-projected isometric Kowloon Bio-Foundry Tower (intact or collapsed rubble)."""
    w, h = 256, 288
    albedo: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    emissive: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    cx = 127.5

    if not rubble:
        # Isometric prism:
        # Roof diamond centered at (cx, 68), half-width=96, half-height=48
        # Left wall: x in [32, 127], top y = 68 + (x - 32)*0.5 - 48.. wait:
        # Let's define the 3 visible faces of an isometric box:
        # Top vertex: (128, 20)
        # Left corner: (32, 68)
        # Front corner: (128, 116)
        # Right corner: (224, 68)
        # Wall height = 152 pixels:
        # Bottom-Left: (32, 220), Bottom-Front: (128, 268), Bottom-Right: (224, 220)
        for y in range(h):
            for x in range(w):
                idx = y * w + x
                dx = x - cx
                adx = abs(dx)
                grain = (hash2d(x, y, 505) - 0.5) * 9.0

                # 1. Check Roof Diamond: |x - 128|/96 + |y - 68|/48 <= 1.0
                roof_d = adx / 96.0 + abs(y - 68.0) / 48.0
                if roof_d <= 1.0:
                    u = dx / 96.0 + (y - 68.0) / 48.0
                    v = (y - 68.0) / 48.0 - dx / 96.0
                    parapet = roof_d > 0.88
                    helipad_ring = 0.34 < math.hypot(u, v) < 0.42
                    bio_skylight = abs(u) < 0.22 and abs(v) < 0.22
                    if parapet:
                        c = clamp8(62 + grain)
                        albedo[idx] = (c, c + 8, c + 16, 255)
                    elif bio_skylight:
                        albedo[idx] = (36, 225, 168, 255)
                        emissive[idx] = (52, 255, 190, 245)
                    elif helipad_ring:
                        albedo[idx] = (210, 155, 38, 255)
                        emissive[idx] = (120, 85, 20, 110)
                    else:
                        c = clamp8(38 + grain)
                        albedo[idx] = (c, c + 5, c + 11, 255)
                    continue

                # 2. Check Left & Right Isometric Walls
                if 32 <= x <= 224:
                    y_top = 116.0 - adx * 0.5
                    y_bot = 268.0 - adx * 0.5
                    if y_top <= y <= y_bot:
                        is_left = x < 128
                        wy = y - y_top  # [0, 152] vertical position on wall
                        wx = adx        # [0, 96] horizontal distance from front spine

                        # Load-bearing corner/spine pillars & floor spandrels
                        in_spine_pillar = wx < 10.0
                        in_outer_pillar = wx > 84.0
                        in_mid_pillar = 44.0 <= wx <= 52.0
                        is_pillar = in_spine_pillar or in_outer_pillar or in_mid_pillar
                        is_base_plinth = wy > 134.0
                        is_hazard = is_pillar and (136.0 <= wy <= 148.0) and ((int(wx + wy) // 4) % 2 == 0)
                        is_floor_beam = (int(wy) % 44) < 8

                        # Upper neon signage band on left wall (14 <= wy <= 30, 18 <= wx <= 76)
                        in_neon_sign = is_left and (12.0 <= wy <= 28.0) and (18.0 <= wx <= 76.0)
                        # Cryo-vat bay windows on stories
                        in_window_y = (int(wy) % 44) in range(12, 36) and wy > 32.0 and wy < 130.0
                        in_window_x = (int(wx) % 20) in range(5, 16) and not is_pillar

                        if is_hazard:
                            albedo[idx] = (215, 165, 30, 255)
                            emissive[idx] = (95, 70, 10, 100)
                        elif in_neon_sign:
                            border = wy < 14.0 or wy > 26.0 or wx < 20.0 or wx > 74.0
                            glyph = ((int(wx) // 4 + int(wy) // 3) % 3 == 0) and (15.0 <= wy <= 25.0)
                            if border or glyph:
                                albedo[idx] = (255, 65, 175, 255)
                                emissive[idx] = (255, 85, 195, 255)
                            else:
                                albedo[idx] = (28, 16, 36, 255)
                        elif in_window_y and in_window_x:
                            # Glowing emerald/cyan cryo-vat tubes with specimen silhouette
                            mullion = (int(wy) % 11 == 0) or (int(wx) % 10 == 0)
                            bubble = ((x * 7 + y * 13) % 17 == 0)
                            if mullion:
                                albedo[idx] = (28, 44, 52, 255)
                            elif bubble:
                                albedo[idx] = (140, 255, 225, 255)
                                emissive[idx] = (160, 255, 235, 255)
                            else:
                                shade = 195 if is_left else 165
                                albedo[idx] = (32, shade, clamp8(shade * 0.78), 255)
                                emissive[idx] = (44, clamp8(shade + 40), clamp8(shade * 0.88), 245)
                        elif is_pillar or is_base_plinth or is_floor_beam:
                            base = 56 if is_left else 40
                            c = clamp8(base + grain)
                            albedo[idx] = (c, c + 6, c + 14, 255)
                        else:
                            base = 38 if is_left else 26
                            c = clamp8(base + grain)
                            albedo[idx] = (c, c + 4, c + 10, 255)
    else:
        # Collapsed Bio-Foundry Rubble Mound & Sheared Pillar Stumps inside the 2:1 isometric footprint
        for y in range(h):
            for x in range(w):
                idx = y * w + x
                dx = x - cx
                adx = abs(dx)
                grain = (hash2d(x, y, 808) - 0.5) * 18.0

                foot_d = adx / 96.0 + abs(y - 216.0) / 48.0
                edge_noise = (hash2d(x // 3, y // 3, 707) - 0.5) * 0.16
                in_mound = foot_d <= (0.98 + edge_noise)

                # Sheared isometric corner pillar stumps with 3D left/right face shading
                stump_l = 36 <= x <= 64 and (158 + abs(x - 50) * 0.5) <= y <= (222 - abs(x - 50) * 0.5)
                stump_r = 192 <= x <= 220 and (162 + abs(x - 206) * 0.5) <= y <= (222 - abs(x - 206) * 0.5)
                stump_f = 112 <= x <= 144 and (192 + abs(x - 128) * 0.5) <= y <= (264 - abs(x - 128) * 0.5)
                jagged = int(hash2d(x // 2, 1, 909) * 14.0)
                in_stump = (
                    (stump_l and y >= 164 + jagged)
                    or (stump_r and y >= 168 + jagged)
                    or (stump_f and y >= 198 + jagged)
                )

                if not (in_mound or in_stump):
                    continue

                # Isometric crater lake of ruptured cryo-biofluid with concentric depth + rim foam
                crater_r = math.hypot((x - 124.0) / 34.0, (y - 216.0) / 17.0) + (hash2d(x // 2, y // 2, 606) - 0.5) * 0.18
                # Tilted broken concrete slab blocks across the mound
                slab_block = ((x + y * 2) // 14 + (x - y * 2) // 16) % 3 == 0
                slab_bevel = ((x + y * 2) % 14 in (0, 1)) or ((x - y * 2) % 16 in (0, 1))
                # Glowing plasma-lance slag cracks radiating from center
                angle_c = math.atan2(y - 216.0, (x - 128.0) * 0.5)
                slag_crack = (
                    crater_r >= 0.92
                    and foot_d < 0.85
                    and abs(math.sin(angle_c * 5.0 + foot_d * 6.0)) < 0.11
                )
                rebar_rod = in_stump and (x % 6 == 0) and y < 192
                hazard_remnant = in_stump and (204 <= y <= 216) and ((x + y) // 4) % 2 == 0

                if crater_r < 0.92:
                    if crater_r > 0.76:
                        albedo[idx] = (130, 255, 215, 255)
                        emissive[idx] = (150, 255, 225, 255)
                    else:
                        depth = max(0.0, 1.0 - crater_r)
                        g_val = clamp8(165 + depth * 70 + grain)
                        b_val = clamp8(120 + depth * 55 + grain * 0.5)
                        albedo[idx] = (24, g_val, b_val, 255)
                        emissive[idx] = (36, clamp8(g_val + 25), clamp8(b_val + 20), 235)
                elif slag_crack:
                    hot = hash2d(x, y, 222) > 0.45
                    albedo[idx] = (255, 165 if hot else 95, 36, 255)
                    emissive[idx] = (255, 185 if hot else 115, 48, 255)
                elif rebar_rod:
                    albedo[idx] = (118, 72, 54, 255)
                elif hazard_remnant:
                    albedo[idx] = (195, 148, 28, 255)
                    emissive[idx] = (80, 58, 10, 90)
                elif in_stump:
                    stump_shade = 64 if (x % 28 < 14) else 42
                    c = clamp8(stump_shade + grain * 0.8)
                    albedo[idx] = (c, c + 4, c + 10, 255)
                else:
                    # Shaded 3D rubble mound (brighter toward upper-left light source, darker toward bottom-right)
                    slope_light = ((128.0 - x) / 96.0 + (216.0 - y) / 48.0) * 14.0
                    base = 54 if slab_bevel else (46 if slab_block else 34)
                    c = clamp8(base + slope_light + grain)
                    albedo[idx] = (c, c + 2, c + 7, 255)

    return w, h, albedo, emissive


def generate_iso8_character_sheet(
    archetype: str,
) -> tuple[int, int, list[RGBA], list[RGBA]]:
    """Generate a 512x96 8-direction (8 frames @ 64x96) 24/32-bit pixel-art character sheet
    with cylindrical 3D shading, tactical harness/coat folds, and directional weapon articulation.
    """
    fw, fh = 64, 96
    frames = 8
    w, h = fw * frames, fh
    albedo: list[RGBA] = [(0, 0, 0, 0)] * (w * h)
    emissive: list[RGBA] = [(0, 0, 0, 0)] * (w * h)

    for frame in range(frames):
        angle = frame * (math.pi / 4.0)
        dir_x = math.sin(angle)
        dir_y = math.cos(angle)  # +1 = South (front), -1 = North (back)
        ox = frame * fw
        cx = 31.5

        for y in range(fh):
            for x in range(fw):
                idx = y * w + (ox + x)
                dx = x - cx
                adx = abs(dx)
                grain = (hash2d(x + ox, y, 404) - 0.5) * 7.0

                # Ground contact shadow ellipse
                shadow_d = (dx / 15.0) ** 2 + ((y - 85.0) / 5.5) ** 2
                if shadow_d <= 1.0 and y >= 80:
                    albedo[idx] = (6, 8, 14, 155)

                # Anatomy masks
                head_r = (dx / 6.8) ** 2 + ((y - 21.5) / 7.2) ** 2
                in_head = head_r <= 1.0
                in_collar = 25 <= y <= 33 and adx <= (10.2 - (y - 25) * 0.18)
                in_shoulders = 30 <= y <= 46 and adx <= (13.2 - abs(y - 37) * 0.25)
                coat_half = 8.8 + max(0.0, (y - 38.0) * 0.19)
                in_coat = 38 <= y <= 74 and adx <= coat_half
                stride = math.sin(angle) * 1.5
                leg_sep = 3.8 + abs(dir_x) * 1.1
                in_l_boot = (69 + stride) <= y <= (85 + stride * 0.5) and abs(dx + leg_sep) <= 3.3
                in_r_boot = (69 - stride) <= y <= (85 - stride * 0.5) and abs(dx - leg_sep) <= 3.3
                in_body = in_head or in_collar or in_shoulders or in_coat or in_l_boot or in_r_boot

                # Cylindrical lighting term across width (-1 = left lit side, +1 = right shadow side)
                cyl_nx = dx / max(6.0, coat_half if in_coat else 11.0)
                cyl_light = max(-0.8, min(1.0, -cyl_nx * 0.75 + 0.25))

                # Visor optics
                visor_cx = dir_x * 3.4
                in_visor = (
                    dir_y >= -0.45
                    and 19 <= y <= 23
                    and abs(dx - visor_cx) <= (4.6 if abs(dir_x) < 0.8 else 3.0)
                )
                if in_visor and in_head:
                    if archetype == "operative":
                        albedo[idx] = (255, 42, 92, 255)
                        emissive[idx] = (255, 68, 115, 255)
                    elif archetype == "guard":
                        albedo[idx] = (255, 180, 38, 255)
                        emissive[idx] = (255, 200, 56, 255)
                    else:
                        albedo[idx] = (48, 238, 255, 255)
                        emissive[idx] = (68, 250, 255, 245)
                    continue

                # Articulated directional weapon (Minigun/Gauss carbine for operative, Pulse rifle for guard)
                wpn_cx = dir_x * 6.5 + (2.5 if dir_x >= 0 else -2.5)
                wpn_cy = 47.0 + dir_y * 2.2
                wpn_len = 13.5
                proj_along = (dx - wpn_cx) * (0.75 if dir_x >= 0 else -0.75) + (y - wpn_cy) * (0.35 * dir_y)
                proj_perp = abs((y - wpn_cy) - (dx - wpn_cx) * 0.22 * dir_y)
                in_weapon = (
                    archetype in ("operative", "guard")
                    and -4.5 <= proj_along <= wpn_len
                    and proj_perp <= (3.2 if proj_along < 4.0 else 2.2)
                )
                if in_weapon and (dir_y >= -0.35 or adx > 7.5):
                    is_muzzle = proj_along >= (wpn_len - 2.6)
                    is_coils = 4.5 <= proj_along < (wpn_len - 2.6) and int(proj_along) % 3 == 0
                    if is_muzzle or is_coils:
                        c_em = (44, 228, 255, 255) if archetype == "operative" else (255, 168, 42, 255)
                        albedo[idx] = c_em
                        emissive[idx] = c_em
                    else:
                        shade = 96 if proj_perp < 1.2 else 58
                        c = clamp8(shade + grain)
                        albedo[idx] = (c, c + 10, c + 22, 255)
                    continue

                if not in_body:
                    continue

                if archetype == "operative":
                    # Trenchcoat Cyborg Operative: popped crimson-lined collar, chrome cyber-arm, tactical harness, pleated duster coat
                    collar_edge = in_collar and (y <= 27 or adx >= 7.8)
                    chrome_arm = in_shoulders and ((dx > 6.5 and dir_x >= -0.2) or (dx < -6.5 and dir_x < -0.2))
                    harness = (34 <= y <= 48) and (abs(abs(dx) - (y - 32) * 0.45) <= 1.2) and dir_y >= -0.2
                    belt = 48 <= y <= 50 and adx <= 8.2
                    coat_fold = in_coat and y >= 51 and (int(dx + 20) % 5 == 0)
                    coat_hem = in_coat and y >= 72

                    if collar_edge:
                        albedo[idx] = (185, 36, 76, 255)
                        emissive[idx] = (140, 26, 58, 160)
                    elif chrome_arm:
                        joint = y in (36, 41)
                        base = 64 if joint else clamp8(128 + cyl_light * 38.0 + grain)
                        albedo[idx] = (base, clamp8(base + 14), clamp8(base + 28), 255)
                    elif belt:
                        buckle = adx <= 1.8 and dir_y >= 0.0
                        if buckle:
                            albedo[idx] = (44, 220, 245, 255)
                            emissive[idx] = (56, 240, 255, 210)
                        else:
                            albedo[idx] = (54, 60, 74, 255)
                    elif harness:
                        c = clamp8(58 + cyl_light * 16.0 + grain)
                        albedo[idx] = (c, c + 8, c + 18, 255)
                    elif in_l_boot or in_r_boot:
                        boot_hi = (y % 5 == 0) or (cyl_light > 0.4)
                        c = clamp8((36 if boot_hi else 20) + grain * 0.5)
                        albedo[idx] = (c, c + 4, c + 10, 255)
                    else:
                        base = 34 + cyl_light * 22.0 - (8.0 if coat_fold else 0.0) + (12.0 if coat_hem else 0.0)
                        c = clamp8(base + grain)
                        albedo[idx] = (c, c + 5, c + 15, 255)

                elif archetype == "guard":
                    # Zaibatsu Corporate Sec-Guard: segmented white/alloy carapace, amber hazard stripes, dark greaves
                    carapace = (in_shoulders or (in_coat and y < 56)) and adx < 10.2
                    visor_crest = in_head and y <= 17
                    hazard_band = carapace and (y in (37, 38, 45, 46))
                    panel_seam = carapace and (adx < 1.0 or y == 41)
                    if hazard_band or visor_crest:
                        albedo[idx] = (235, 158, 34, 255)
                        emissive[idx] = (165, 108, 22, 145)
                    elif panel_seam:
                        albedo[idx] = (48, 56, 68, 255)
                    elif carapace or in_head:
                        c = clamp8(152 + cyl_light * 36.0 + grain)
                        albedo[idx] = (c, clamp8(c + 8), clamp8(c + 16), 255)
                    else:
                        c = clamp8(38 + cyl_light * 16.0 + grain)
                        albedo[idx] = (c, c + 6, c + 14, 255)

                else:
                    # Megacity Civilian: rain-slicked cyber-poncho with glowing cyan/magenta trim
                    neon_hem = in_coat and (abs(y - 69) <= 1 or (adx >= coat_half - 1.8 and y < 60))
                    hood_trim = in_collar and y <= 28
                    if neon_hem:
                        albedo[idx] = (42, 225, 248, 255)
                        emissive[idx] = (64, 245, 255, 235)
                    elif hood_trim:
                        albedo[idx] = (235, 64, 175, 255)
                        emissive[idx] = (250, 82, 195, 210)
                    elif in_coat or in_shoulders:
                        c = clamp8(46 + cyl_light * 24.0 + grain)
                        albedo[idx] = (clamp8(c - 8), clamp8(c + 18), clamp8(c + 34), 255)
                    else:
                        c = clamp8(28 + cyl_light * 14.0 + grain)
                        albedo[idx] = (c, c + 4, c + 10, 255)

    return w, h, albedo, emissive


def save_asset_triplet(
    albedo_dir: Path,
    normals_dir: Path,
    stem: str,
    w: int,
    h: int,
    albedo: list[RGBA],
    emissive: list[RGBA],
) -> None:
    normal = compute_sobel_normal_map(w, h, albedo)
    write_rgba_png(albedo_dir / f"{stem}_albedo.png", w, h, albedo)
    write_rgba_png(albedo_dir / f"{stem}_emissive.png", w, h, emissive)
    write_rgba_png(normals_dir / f"{stem}_normal.png", w, h, normal)


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    tiles_dir = repo_root / "godot" / "assets" / "tiles"
    sprites_dir = repo_root / "godot" / "assets" / "sprites"
    normals_dir = repo_root / "godot" / "assets" / "normals"

    for mode, stem in (
        ("undergrid", "undergrid_grate"),
        ("street", "street_neon"),
        ("spire", "spire_skybridge"),
    ):
        tw, th, albedo, emissive = generate_iso_diamond_tile(mode)
        save_asset_triplet(tiles_dir, normals_dir, stem, tw, th, albedo, emissive)

    bw, bh, b_intact_a, b_intact_e = generate_iso_building_facade(rubble=False)
    save_asset_triplet(tiles_dir, normals_dir, "biofoundry_tower_intact", bw, bh, b_intact_a, b_intact_e)

    rw, rh, b_rubble_a, b_rubble_e = generate_iso_building_facade(rubble=True)
    save_asset_triplet(tiles_dir, normals_dir, "biofoundry_tower_rubble", rw, rh, b_rubble_a, b_rubble_e)

    for arch, stem in (
        ("operative", "operative_trenchcoat"),
        ("guard", "corp_sec_guard"),
        ("civilian", "megacity_civilian"),
    ):
        sw, sh, s_albedo, s_emissive = generate_iso8_character_sheet(arch)
        save_asset_triplet(sprites_dir, normals_dir, stem, sw, sh, s_albedo, s_emissive)

    print("Generated HD 128x64 3-stratum tileset, 256x288 Bio-Foundry tower states, and 512x96 iso8 character sheets.")


if __name__ == "__main__":
    main()
