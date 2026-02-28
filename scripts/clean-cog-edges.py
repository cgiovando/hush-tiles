#!/usr/bin/env python3
"""
Clean near-black border pixels in a COG so nodata=0 catches them.

JPEG-compressed COGs often have compression artifacts at image edges —
near-black pixels (RGB 1-10) that aren't caught by nodata=0.
This script sets those border pixels to exact 0 using a flood-fill
from the image edges, then re-creates the COG.

Usage:
    python scripts/clean-cog-edges.py data/test-image.tif
    python scripts/clean-cog-edges.py data/test-image.tif --threshold 15
    python scripts/clean-cog-edges.py input.tif -o output.tif
"""

import argparse
import sys
from pathlib import Path

import numpy as np
import rasterio
from scipy import ndimage


def clean_edges(input_path, output_path, threshold=10):
    """Flood-fill from image edges to find connected near-black pixels and set them to 0."""
    with rasterio.open(input_path) as src:
        data = src.read()  # (bands, H, W)
        profile = src.profile.copy()
        bands, h, w = data.shape

        print(f"Input: {w}x{h}, {bands} bands, {src.dtypes[0]}")
        print(f"Threshold: {threshold} (pixels with all bands <= {threshold})")

        # Find all near-black pixels (all bands <= threshold)
        near_black = np.all(data <= threshold, axis=0)  # (H, W)
        total_near_black = near_black.sum()
        print(f"Total near-black pixels: {total_near_black:,}")

        if total_near_black == 0:
            print("No near-black pixels found, nothing to do.")
            return

        # Create edge seed mask — only pixels touching the image border
        edge_seed = np.zeros_like(near_black)
        edge_seed[0, :] = near_black[0, :]      # top row
        edge_seed[-1, :] = near_black[-1, :]     # bottom row
        edge_seed[:, 0] = near_black[:, 0]       # left column
        edge_seed[:, -1] = near_black[:, -1]     # right column

        # Flood-fill: find near-black pixels connected to the edges
        labeled, _ = ndimage.label(near_black)
        edge_labels = set(labeled[edge_seed].flat) - {0}
        border_mask = np.isin(labeled, list(edge_labels))

        border_count = border_mask.sum()
        interior_count = total_near_black - border_count
        print(f"Border near-black pixels (connected to edge): {border_count:,}")
        print(f"Interior near-black pixels (preserved): {interior_count:,}")

        # Set border near-black pixels to exact 0
        for b in range(bands):
            data[b][border_mask] = 0

        # Write cleaned file with nodata=0 (intermediate, not yet COG)
        profile.update(nodata=0)
        tmp_path = str(output_path) + ".tmp.tif"
        with rasterio.open(tmp_path, "w", **profile) as dst:
            dst.write(data)

    # Re-create as COG with internal mask band.
    # The mask is stored losslessly (DEFLATE) alongside JPEG RGB data,
    # so JPEG compression artifacts don't affect transparency.
    print(f"Writing COG with internal mask: {output_path}")
    try:
        from rio_cogeo.cogeo import cog_translate
        from rio_cogeo.profiles import cog_profiles

        cog_profile = cog_profiles.get("jpeg")
        cog_profile.update(blocksize=512)
        cog_translate(
            tmp_path, str(output_path), cog_profile,
            quiet=True, use_cog_driver=True, add_mask=True,
        )
        Path(tmp_path).unlink()
    except ImportError:
        print("rio-cogeo not available, output is a standard GeoTIFF (not COG)")
        Path(tmp_path).rename(output_path)

    print("Done.")


def main():
    parser = argparse.ArgumentParser(description="Clean near-black border pixels in a COG")
    parser.add_argument("input", help="Input COG file")
    parser.add_argument("-o", "--output", help="Output file (default: input with -clean suffix)")
    parser.add_argument("-t", "--threshold", type=int, default=10,
                        help="Near-black threshold (default: 10)")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: {input_path} not found")
        sys.exit(1)

    if args.output:
        output_path = Path(args.output)
    else:
        output_path = input_path.with_stem(input_path.stem + "-clean")

    clean_edges(input_path, output_path, args.threshold)


if __name__ == "__main__":
    main()
