#!/usr/bin/env python3
"""Generate 24/32-bit isometric pixel-art tiles, trenchcoat operative sprites,
and 2.5D Sobel normal/emissive maps for the wetware Godot 4.7.2 vertical slice.

Also acts as the normal/emissive map bevel pipeline for assets produced via
`venice image --no-safe-mode` / `venice bg-remove`.
"""

from __future__ import annotations

import math
from pathlib import Path
import struct
import zlib


def write_rgba_png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # Filter type 0 (None)
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
    albedo: list[tuple[int, int, int, int]],
    bevel_strength: float = 2.5,
) -> list[tuple[int, int, int, int]]:
    def luma(x: int, y: int) -> float:
        cx = max(0, min(width - 1, x))
        cy = max(0, min(height - 1, y))
        r, g, b, a = albedo[cy * width + cx]
        if a == 0:
            return 0.0
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

    normals: list[tuple[int, int, int, int]] = []
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
            nx = int(round(((-gx * inv_len) * 0.5 + 0.5) * 255.0))
            ny = int(round(((-gy * inv_len) * 0.5 + 0.5) * 255.0))
            nz = int(round(((gz * inv_len) * 0.5 + 0.5) * 255.0))
            normals.append((max(0, min(255, nx)), max(0, min(255, ny)), max(0, min(255, nz)), 255))
    return normals


def generate_iso_street_tile() -> tuple[int, int, list[tuple[int, int, int, int]], list[tuple[int, int, int, int]]]:
    w, h = 64, 32
    albedo: list[tuple[int, int, int, int]] = []
    emissive: list[tuple[int, int, int, int]] = []
    cx, cy = 31.5, 15.5
    for y in range(h):
        for x in range(w):
            dx = abs(x - cx) / 32.0
            dy = abs(y - cy) / 16.0
            if dx + dy <= 1.0:
                edge = dx + dy > 0.90
                puddle = ((x * 7 + y * 13) % 19 == 0) and (dx + dy < 0.75)
                neon_lane = abs((x - 2 * y) - 0) <= 1 and (dx + dy < 0.8)
                if neon_lane:
                    albedo.append((36, 210, 235, 255))
                    emissive.append((64, 245, 255, 255))
                elif puddle:
                    albedo.append((28, 38, 56, 255))
                    emissive.append((20, 90, 140, 180))
                elif edge:
                    albedo.append((42, 48, 60, 255))
                    emissive.append((0, 0, 0, 0))
                else:
                    albedo.append((22, 25, 34, 255))
                    emissive.append((0, 0, 0, 0))
            else:
                albedo.append((0, 0, 0, 0))
                emissive.append((0, 0, 0, 0))
    return w, h, albedo, emissive


def generate_iso_operative_sprite() -> tuple[int, int, list[tuple[int, int, int, int]], list[tuple[int, int, int, int]]]:
    w, h = 32, 48
    albedo: list[tuple[int, int, int, int]] = []
    emissive: list[tuple[int, int, int, int]] = []
    for y in range(h):
        for x in range(w):
            dx = abs(x - 15.5)
            # Matte-black cybernetic trenchcoat silhouette with glowing visor + Gauss barrel
            in_head = 6 <= y <= 12 and dx <= 3.5
            in_visor = 8 <= y <= 9 and 14 <= x <= 18
            in_shoulders = 13 <= y <= 20 and dx <= 6.5
            in_coat = 21 <= y <= 38 and dx <= (5.5 + (y - 21) * 0.12)
            in_boots = 39 <= y <= 45 and (11 <= x <= 14 or 17 <= x <= 20)
            in_weapon = 20 <= y <= 24 and 18 <= x <= 27

            if in_visor:
                albedo.append((255, 50, 90, 255))
                emissive.append((255, 64, 110, 255))
            elif in_weapon:
                albedo.append((70, 95, 120, 255))
                emissive.append((40, 200, 255, 220) if x >= 25 else (0, 0, 0, 0))
            elif in_head or in_shoulders or in_coat or in_boots:
                rim = dx >= 4.5
                shade = 38 if rim else 18
                albedo.append((shade, shade + 2, shade + 8, 255))
                emissive.append((0, 0, 0, 0))
            else:
                albedo.append((0, 0, 0, 0))
                emissive.append((0, 0, 0, 0))
    return w, h, albedo, emissive


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    tiles_dir = repo_root / "godot" / "assets" / "tiles"
    sprites_dir = repo_root / "godot" / "assets" / "sprites"
    normals_dir = repo_root / "godot" / "assets" / "normals"

    tw, th, tile_albedo, tile_emissive = generate_iso_street_tile()
    tile_normal = compute_sobel_normal_map(tw, th, tile_albedo)
    write_rgba_png(tiles_dir / "street_neon_albedo.png", tw, th, tile_albedo)
    write_rgba_png(tiles_dir / "street_neon_emissive.png", tw, th, tile_emissive)
    write_rgba_png(normals_dir / "street_neon_normal.png", tw, th, tile_normal)

    sw, sh, op_albedo, op_emissive = generate_iso_operative_sprite()
    op_normal = compute_sobel_normal_map(sw, sh, op_albedo)
    write_rgba_png(sprites_dir / "operative_trenchcoat_albedo.png", sw, sh, op_albedo)
    write_rgba_png(sprites_dir / "operative_trenchcoat_emissive.png", sw, sh, op_emissive)
    write_rgba_png(normals_dir / "operative_trenchcoat_normal.png", sw, sh, op_normal)

    print("Generated 24/32-bit isometric tiles, operative sprites, and 2.5D Sobel normal/emissive maps.")


if __name__ == "__main__":
    main()
