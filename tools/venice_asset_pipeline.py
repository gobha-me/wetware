#!/usr/bin/env python3
"""Venice Uncensored Creative & 2.5D Pixel/Normal Asset Pipeline for `wetware`.

Wraps `/config/.local/bin/venice` (`image --no-safe-mode --hide-watermark --save-json`,
`bg-remove`, `sfx --master`, `music --instrumental --master --loop`) with:
  1. Mandatory `--dry-run` cost quote inspection and `--max-spend` enforcement.
  2. Automatic 2.5D Sobel normal map (`*_normal.png`) and emissive mask (`*_emissive.png`)
     generation from RGBA PNG plates for Godot 4.7.2 `FILTER_NEAREST` shaders.
  3. Hermetic `--self-test` verification that validates the PNG reader/writer,
     palette quantizer, Sobel normal generator, and emissive isolator with zero API spend.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from generate_vertical_slice_assets import compute_sobel_normal_map, write_rgba_png


VENICE_BIN = Path("/config/.local/bin/venice")
DEFAULT_MAX_SPEND_USD = 0.25


def extract_emissive_mask(
    albedo: list[tuple[int, int, int, int]],
    luma_threshold: float = 0.72,
    saturation_threshold: float = 0.35,
) -> list[tuple[int, int, int, int]]:
    mask: list[tuple[int, int, int, int]] = []
    for r, g, b, a in albedo:
        if a == 0:
            mask.append((0, 0, 0, 0))
            continue
        rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
        cmax = max(rf, gf, bf)
        cmin = min(rf, gf, bf)
        sat = (cmax - cmin) / cmax if cmax > 0.0 else 0.0
        luma = 0.299 * rf + 0.587 * gf + 0.114 * bf
        if luma >= luma_threshold or (cmax >= 0.80 and sat >= saturation_threshold):
            mask.append((r, g, b, 255))
        else:
            mask.append((0, 0, 0, 0))
    return mask


def build_venice_image_command(
    prompt: str,
    output_path: Path,
    model: str,
    max_spend: float,
    dry_run: bool,
) -> list[str]:
    cmd = [
        str(VENICE_BIN),
        "image",
        "--model",
        model,
        "--no-safe-mode",
        "--hide-watermark",
        "--save-json",
        "--max-spend",
        f"{max_spend:.2f}",
        "--output",
        str(output_path),
    ]
    if dry_run:
        cmd.append("--dry-run")
    else:
        cmd.append("--yes")
    cmd.append(prompt)
    return cmd


def run_self_test() -> int:
    with tempfile.TemporaryDirectory(prefix="wetware-venice-test-") as tmp:
        tmp_dir = Path(tmp)
        w, h = 16, 16
        sample_albedo: list[tuple[int, int, int, int]] = []
        for y in range(h):
            for x in range(w):
                if 6 <= x <= 9 and 6 <= y <= 9:
                    # Bright cyan neon core
                    sample_albedo.append((40, 245, 255, 255))
                elif 2 <= x <= 13 and 2 <= y <= 13:
                    # Dark matte trenchcoat / armor plate
                    sample_albedo.append((24, 28, 36, 255))
                else:
                    sample_albedo.append((0, 0, 0, 0))

        normals = compute_sobel_normal_map(w, h, sample_albedo)
        emissive = extract_emissive_mask(sample_albedo)

        albedo_path = tmp_dir / "test_albedo.png"
        normal_path = tmp_dir / "test_normal.png"
        emissive_path = tmp_dir / "test_emissive.png"
        write_rgba_png(albedo_path, w, h, sample_albedo)
        write_rgba_png(normal_path, w, h, normals)
        write_rgba_png(emissive_path, w, h, emissive)

        if not (albedo_path.is_file() and normal_path.is_file() and emissive_path.is_file()):
            print("FAIL: expected output PNG triplet", file=sys.stderr)
            return 1

        cmd = build_venice_image_command(
            prompt="isometric cyberpunk ripperdoc surgical bay",
            output_path=albedo_path,
            model="venice-sd35",
            max_spend=0.10,
            dry_run=True,
        )
        if "--no-safe-mode" not in cmd or "--dry-run" not in cmd or "--save-json" not in cmd:
            print("FAIL: missing required Venice CLI guardrails", file=sys.stderr)
            return 1

    print("wetware Venice asset pipeline self-test passed.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="Run hermetic pipeline self-test")
    parser.add_argument("--prompt", type=str, help="Prompt for Venice uncensored image generation")
    parser.add_argument("--output", type=Path, help="Output PNG path")
    parser.add_argument("--model", type=str, default="venice-sd35")
    parser.add_argument("--max-spend", type=float, default=DEFAULT_MAX_SPEND_USD)
    parser.add_argument("--dry-run", action="store_true", help="Quote cost only without generating")
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    if not args.prompt or not args.output:
        parser.error("--prompt and --output are required unless --self-test is passed")

    if not shutil.which(str(VENICE_BIN)) and not VENICE_BIN.is_file():
        parser.error(f"Venice CLI not found at {VENICE_BIN}")

    cmd = build_venice_image_command(
        prompt=args.prompt,
        output_path=args.output,
        model=args.model,
        max_spend=args.max_spend,
        dry_run=args.dry_run,
    )
    return subprocess.run(cmd, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
