"""Wallpaper utilities for colorscheme management."""

import colorgram
import cv2
import numpy as np
import subprocess
import shutil
from pathlib import Path
from PIL import Image
import colorsys


def _relative_luminance(rgb: tuple) -> float:
    """Return WCAG relative luminance for an sRGB color."""
    def to_linear(channel: float) -> float:
        if channel <= 0.04045:
            return channel / 12.92
        return ((channel + 0.055) / 1.055) ** 2.4

    r, g, b = [c / 255.0 for c in rgb]
    r_lin = to_linear(r)
    g_lin = to_linear(g)
    b_lin = to_linear(b)
    return 0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin


def _contrast_ratio(luma_a: float, luma_b: float) -> float:
    """Return contrast ratio between two relative luminance values."""
    hi = max(luma_a, luma_b)
    lo = min(luma_a, luma_b)
    return (hi + 0.05) / (lo + 0.05)


def _color_entry(rgb: tuple, proportion: float, index: int) -> dict:
    r, g, b = rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return {
        'rgb': rgb,
        'hue': h * 360,
        'lightness': l,
        'saturation': s,
        'proportion': proportion,
        'luma': _relative_luminance(rgb),
        'index': index,
    }


def _extract_kmeans_colors(image_path: Path, k: int = 12) -> list:
    """Extract dominant colors via k-means clustering."""
    with Image.open(image_path) as img:
        img = img.convert("RGBA")
        img.thumbnail((256, 256), Image.Resampling.LANCZOS)
        pixels = np.array(img)

    if pixels.ndim != 3 or pixels.shape[2] < 3:
        raise ValueError("Unsupported image format for palette extraction")

    if pixels.shape[2] == 4:
        alpha = pixels[:, :, 3]
        pixels = pixels[:, :, :3][alpha > 16]
    else:
        pixels = pixels[:, :, :3].reshape(-1, 3)

    if pixels.size == 0:
        raise ValueError("Image has no visible pixels")

    data = pixels.astype(np.float32)
    k = min(k, len(data))
    if k < 2:
        rgb = tuple(int(c) for c in data[0])
        return [_color_entry(rgb, 1.0, 0)]

    cv2.setRNGSeed(1)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 25, 1.0)
    _compactness, labels, centers = cv2.kmeans(
        data,
        k,
        None,
        criteria,
        5,
        cv2.KMEANS_PP_CENTERS,
    )
    counts = np.bincount(labels.flatten(), minlength=k)
    total = counts.sum()

    color_data = []
    for idx, center in enumerate(centers):
        rgb = tuple(int(round(c)) for c in center)
        proportion = counts[idx] / total if total else 0
        color_data.append(_color_entry(rgb, proportion, idx))

    return color_data


def _extract_colors_from_colorgram(image_path: Path, count: int = 32) -> list:
    """Fallback palette extraction using colorgram."""
    colors = colorgram.extract(str(image_path), count)
    return [
        _color_entry((color.rgb.r, color.rgb.g, color.rgb.b), color.proportion, idx)
        for idx, color in enumerate(colors)
    ]


def _extract_image_colors(image_path: Path) -> list:
    """Extract palette from an image with a k-means primary and colorgram fallback."""
    try:
        return _extract_kmeans_colors(image_path)
    except Exception:
        return _extract_colors_from_colorgram(image_path)


def extract_dominant_hue(image_path: Path) -> float:
    """
    Extract dominant hue from image.

    Args:
        image_path: Path to image file

    Returns:
        Hue value in 0-360 range
    """
    # Extract dominant colors
    colors = colorgram.extract(str(image_path), 5)

    if not colors:
        return 0.0

    # Convert to HSV and calculate weighted average hue
    total_weight = 0
    weighted_hue = 0

    for color in colors:
        r, g, b = color.rgb.r / 255.0, color.rgb.g / 255.0, color.rgb.b / 255.0
        h, s, v = colorsys.rgb_to_hsv(r, g, b)

        # Weight by saturation and proportion (ignore grayscale)
        if s > 0.1:
            weight = color.proportion * s
            weighted_hue += h * weight
            total_weight += weight

    if total_weight == 0:
        return 0.0

    # Return hue in 0-360 range
    return (weighted_hue / total_weight) * 360


def calculate_hue_from_variant(variant: dict) -> float:
    """
    Calculate average hue from variant's ANSI colors.

    Args:
        variant: Variant dictionary with ANSI color definitions

    Returns:
        Hue value in 0-360 range
    """
    # ANSI color keys to sample (exclude black/white)
    color_keys = ['ansi_1', 'ansi_2', 'ansi_3', 'ansi_4', 'ansi_5', 'ansi_6']

    hues = []
    for key in color_keys:
        if key in variant:
            hex_color = variant[key].lstrip('#')
            r = int(hex_color[0:2], 16) / 255.0
            g = int(hex_color[2:4], 16) / 255.0
            b = int(hex_color[4:6], 16) / 255.0

            h, s, v = colorsys.rgb_to_hsv(r, g, b)

            # Only include colors with some saturation
            if s > 0.1:
                hues.append(h * 360)

    if not hues:
        return 0.0

    return sum(hues) / len(hues)


def hue_shift_image(input_path: Path, output_path: Path, hue_offset: float):
    """
    Apply hue shift to image.

    Args:
        input_path: Source image path
        output_path: Destination image path
        hue_offset: Hue offset in degrees (0-360)
    """
    # Load image
    img = cv2.imread(str(input_path))

    if img is None:
        raise ValueError(f"Failed to load image: {input_path}")

    # Convert BGR to HSV
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # OpenCV uses 0-179 for hue, convert offset from 0-360
    hue_offset_cv = (hue_offset / 360.0) * 179

    # Apply hue shift
    hsv[:, :, 0] = (hsv[:, :, 0].astype(float) + hue_offset_cv) % 180
    hsv[:, :, 0] = hsv[:, :, 0].astype(np.uint8)

    # Convert back to BGR
    result = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)

    # Save result
    cv2.imwrite(str(output_path), result)


def set_wallpaper(image_path: Path, tile: bool = False):
    """
    Set desktop wallpaper with proper tiling support on macOS.

    Args:
        image_path: Path to wallpaper image
        tile: Whether to tile the wallpaper
    """
    abs_path = str(image_path.resolve())
    escaped_path = abs_path.replace('"', '\\"')

    def run_osascript(script: str):
        result = subprocess.run(
            ["osascript", "-e", script],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return True, ""
        error = result.stderr.strip() or result.stdout.strip()
        return False, error

    # Preferred: System Events sets all desktops/spaces reliably.
    system_events_script = f'''
    tell application "System Events"
        set picture of every desktop to (POSIX file "{escaped_path}") as alias
    end tell
    '''
    ok, error = run_osascript(system_events_script)

    # Fallback: Finder (sometimes more permissive on newer macOS releases).
    if not ok:
        finder_script = f'''
        tell application "Finder"
            set desktop picture to POSIX file "{escaped_path}"
        end tell
        '''
        ok, error = run_osascript(finder_script)

    # Fallback: desktoppr if installed.
    if not ok:
        desktoppr = shutil.which("desktoppr")
        if desktoppr:
            result = subprocess.run([desktoppr, abs_path], check=False, capture_output=True, text=True)
            ok = result.returncode == 0
            if not ok:
                error = result.stderr.strip() or result.stdout.strip()

    if not ok:
        raise RuntimeError(
            f"Failed to set wallpaper: {error or 'unknown error'}\n"
            "Note: You may need to grant System Events permission in System Settings > "
            "Privacy & Security > Automation."
        )

    # Note: Tiling requires manual configuration in System Preferences
    # Automatic tiling via defaults write requires Dock restart which is disruptive
    # Users should configure tiling manually if needed


def should_tile(image_path: Path) -> bool:
    """
    Determine if image should be tiled based on dimensions.

    Args:
        image_path: Path to image file

    Returns:
        True if image should be tiled (small pattern)
    """
    try:
        with Image.open(image_path) as img:
            width, height = img.size
            return width < 512 or height < 512
    except Exception:
        return False


def upscale_to_4k(input_path: Path, output_path: Path) -> Path:
    """
    Upscale image to 4K (3840x2160) if smaller, preserving aspect ratio.

    Args:
        input_path: Source image path
        output_path: Destination path for upscaled image

    Returns:
        Path to output image (same as output_path)
    """
    TARGET_WIDTH = 3840
    TARGET_HEIGHT = 2160

    with Image.open(input_path) as img:
        width, height = img.size

        # Check if already 4K or larger
        if width >= TARGET_WIDTH and height >= TARGET_HEIGHT:
            # Just copy the file
            if input_path != output_path:
                import shutil
                shutil.copy2(input_path, output_path)
            return output_path

        # Calculate scaling to fill 4K
        scale_w = TARGET_WIDTH / width
        scale_h = TARGET_HEIGHT / height
        scale = max(scale_w, scale_h)

        new_width = int(width * scale)
        new_height = int(height * scale)

        # Upscale using high-quality Lanczos resampling
        upscaled = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

        # Save as PNG for quality
        upscaled.save(output_path, "PNG")

    return output_path


def extract_color_palette(image_path: Path, variant_light: str = None, variant_dark: str = None) -> dict:
    """
    Extract color palette from image and map to ANSI colors.

    Args:
        image_path: Path to image file
        variant_light: Name of light variant (for extended palette)
        variant_dark: Name of dark variant (for extended palette)

    Returns:
        Dictionary with 'light_toml', 'dark_toml', 'light_extended', 'dark_extended' keys
    """
    color_data = _extract_image_colors(image_path)

    if not color_data:
        raise ValueError("No usable colors found in image")

    # Find darkest and lightest by weighting proportion and saturation
    # We want prominent, vibrant colors for better representation

    # Score colors for darkness (prefer prominent, saturated, dark colors)
    dark_candidates = [c for c in color_data if c['luma'] <= 0.35]
    if not dark_candidates:
        dark_candidates = color_data
    darkest_color = max(
        dark_candidates,
        key=lambda c: c['proportion'] * (0.6 + 0.4 * c['saturation']) * (1 - c['luma']),
    )

    # Score colors for lightness (prefer prominent, saturated, light colors)
    light_candidates = [c for c in color_data if c['luma'] >= 0.65]
    if not light_candidates:
        light_candidates = color_data
    lightest_color = max(
        light_candidates,
        key=lambda c: c['proportion'] * (0.6 + 0.4 * c['saturation']) * c['luma'],
    )

    # Create very dark version while preserving hue
    r, g, b = darkest_color['rgb']
    r, g, b = r / 255.0, g / 255.0, b / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if l < 0.04:
        l = 0.04
    if l > 0.18:
        l = 0.18
    if s > 0.7:
        s *= 0.8
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    darkest = (int(r * 255), int(g * 255), int(b * 255))

    # Create very light version while preserving hue
    r, g, b = lightest_color['rgb']
    r, g, b = r / 255.0, g / 255.0, b / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if l < 0.82:
        l = 0.82
    if l > 0.96:
        l = 0.96
    if s > 0.7:
        s *= 0.8
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    lightest = (int(r * 255), int(g * 255), int(b * 255))

    # Sort by hue for color mapping
    saturated_colors = [
        c for c in color_data
        if c['saturation'] > 0.12 and _contrast_ratio(c['luma'], _relative_luminance(darkest)) >= 1.3
    ]
    if not saturated_colors:
        saturated_colors = color_data

    # Map colors to ANSI slots based on hue ranges
    ansi_map = {
        'ansi_1': None,  # Red (0-30, 330-360)
        'ansi_2': None,  # Green (90-150)
        'ansi_3': None,  # Yellow (30-90)
        'ansi_4': None,  # Blue (210-270)
        'ansi_5': None,  # Magenta (270-330)
        'ansi_6': None,  # Cyan (150-210)
    }

    def assign_color_to_slot(hue):
        """Map hue to ANSI color slot."""
        if hue < 30 or hue >= 330:
            return 'ansi_1'
        elif 30 <= hue < 90:
            return 'ansi_3'
        elif 90 <= hue < 150:
            return 'ansi_2'
        elif 150 <= hue < 210:
            return 'ansi_6'
        elif 210 <= hue < 270:
            return 'ansi_4'
        else:
            return 'ansi_5'

    # Assign colors to slots and boost saturation
    def boost_saturation(rgb, min_sat=0.25, max_sat=0.85, min_l=0.25, max_l=0.75):
        """Normalize saturation/lightness without crushing the source color."""
        r, g, b = rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0
        h, l, s = colorsys.rgb_to_hls(r, g, b)

        if s < min_sat:
            s = min_sat
        if s > max_sat:
            s = max_sat
        if l < min_l:
            l = min_l
        if l > max_l:
            l = max_l

        r, g, b = colorsys.hls_to_rgb(h, l, s)
        return (int(r * 255), int(g * 255), int(b * 255))

    def color_score(color):
        mid_light = 1 - abs(color['lightness'] - 0.5)
        return color['proportion'] * (0.5 + 0.5 * color['saturation']) * (0.6 + 0.4 * mid_light)

    slot_groups = {slot: [] for slot in ansi_map}
    for color in saturated_colors:
        slot_groups[assign_color_to_slot(color['hue'])].append(color)

    used_indices = set()
    for slot, candidates in slot_groups.items():
        if candidates:
            best = max(candidates, key=color_score)
            ansi_map[slot] = boost_saturation(best['rgb'])
            used_indices.add(best['index'])

    # Fill any missing slots with fallbacks
    slot_centers = {
        'ansi_1': 0,
        'ansi_3': 60,
        'ansi_2': 120,
        'ansi_6': 180,
        'ansi_4': 240,
        'ansi_5': 300,
    }

    def hue_distance(a, b):
        d = abs(a - b)
        return min(d, 360 - d)

    for slot, center in slot_centers.items():
        if ansi_map[slot] is None:
            candidates = [c for c in saturated_colors if c['index'] not in used_indices]
            if not candidates:
                candidates = saturated_colors
            best = min(
                candidates,
                key=lambda c: (hue_distance(c['hue'], center), -color_score(c)),
            )
            ansi_map[slot] = boost_saturation(best['rgb'])
            used_indices.add(best['index'])

    # Create bright variants (increase lightness)
    def brighten_color(rgb, amount=0.15):
        """Increase lightness of RGB color."""
        r, g, b = rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        l = min(1.0, l + amount)
        r, g, b = colorsys.hls_to_rgb(h, l, s)
        return (int(r * 255), int(g * 255), int(b * 255))

    # Generate TOML for dark variant
    def rgb_to_hex(rgb):
        return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"

    # Build ANSI color array for dark variant
    dark_ansi = [
        rgb_to_hex(darkest),
        rgb_to_hex(ansi_map['ansi_1']),
        rgb_to_hex(ansi_map['ansi_2']),
        rgb_to_hex(ansi_map['ansi_3']),
        rgb_to_hex(ansi_map['ansi_4']),
        rgb_to_hex(ansi_map['ansi_5']),
        rgb_to_hex(ansi_map['ansi_6']),
        rgb_to_hex(lightest),
        rgb_to_hex(brighten_color(darkest, 0.2)),
        rgb_to_hex(brighten_color(ansi_map['ansi_1'])),
        rgb_to_hex(brighten_color(ansi_map['ansi_2'])),
        rgb_to_hex(brighten_color(ansi_map['ansi_3'])),
        rgb_to_hex(brighten_color(ansi_map['ansi_4'])),
        rgb_to_hex(brighten_color(ansi_map['ansi_5'])),
        rgb_to_hex(brighten_color(ansi_map['ansi_6'])),
        rgb_to_hex(lightest),
    ]

    # Create a semi-transparent selection background (use a muted version of blue)
    sel_bg = ansi_map['ansi_4']
    r, g, b = sel_bg[0] / 255.0, sel_bg[1] / 255.0, sel_bg[2] / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = 0.3  # Darker for better contrast
    s = 0.5  # Medium saturation
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    selection_bg = (int(r * 255), int(g * 255), int(b * 255))

    dark_toml = f"""foreground = '{rgb_to_hex(lightest)}'
background = '{rgb_to_hex(darkest)}'
cursor = '{rgb_to_hex(lightest)}'
selection_background = '{rgb_to_hex(selection_bg)}'
selection_foreground = '{rgb_to_hex(lightest)}'
ansi = [
  '{dark_ansi[0]}',
  '{dark_ansi[1]}',
  '{dark_ansi[2]}',
  '{dark_ansi[3]}',
  '{dark_ansi[4]}',
  '{dark_ansi[5]}',
  '{dark_ansi[6]}',
  '{dark_ansi[7]}',
  '{dark_ansi[8]}',
  '{dark_ansi[9]}',
  '{dark_ansi[10]}',
  '{dark_ansi[11]}',
  '{dark_ansi[12]}',
  '{dark_ansi[13]}',
  '{dark_ansi[14]}',
  '{dark_ansi[15]}',
]
"""

    # Light variant: swap background/foreground, darken colors
    def darken_color(rgb, amount=0.15):
        """Decrease lightness of RGB color."""
        r, g, b = rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        l = max(0.0, l - amount)
        r, g, b = colorsys.hls_to_rgb(h, l, s)
        return (int(r * 255), int(g * 255), int(b * 255))

    # Build ANSI color array for light variant
    light_ansi = [
        rgb_to_hex(lightest),
        rgb_to_hex(darken_color(ansi_map['ansi_1'])),
        rgb_to_hex(darken_color(ansi_map['ansi_2'])),
        rgb_to_hex(darken_color(ansi_map['ansi_3'])),
        rgb_to_hex(darken_color(ansi_map['ansi_4'])),
        rgb_to_hex(darken_color(ansi_map['ansi_5'])),
        rgb_to_hex(darken_color(ansi_map['ansi_6'])),
        rgb_to_hex(darkest),
        rgb_to_hex(darken_color(lightest, 0.1)),
        rgb_to_hex(ansi_map['ansi_1']),
        rgb_to_hex(ansi_map['ansi_2']),
        rgb_to_hex(ansi_map['ansi_3']),
        rgb_to_hex(ansi_map['ansi_4']),
        rgb_to_hex(ansi_map['ansi_5']),
        rgb_to_hex(ansi_map['ansi_6']),
        rgb_to_hex(darkest),
    ]

    # Create selection background for light variant
    sel_bg_light = ansi_map['ansi_4']
    r, g, b = sel_bg_light[0] / 255.0, sel_bg_light[1] / 255.0, sel_bg_light[2] / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = 0.7  # Lighter for light variant
    s = 0.4  # Medium saturation
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    selection_bg_light = (int(r * 255), int(g * 255), int(b * 255))

    light_toml = f"""foreground = '{rgb_to_hex(darkest)}'
background = '{rgb_to_hex(lightest)}'
cursor = '{rgb_to_hex(darkest)}'
selection_background = '{rgb_to_hex(selection_bg_light)}'
selection_foreground = '{rgb_to_hex(darkest)}'
ansi = [
  '{light_ansi[0]}',
  '{light_ansi[1]}',
  '{light_ansi[2]}',
  '{light_ansi[3]}',
  '{light_ansi[4]}',
  '{light_ansi[5]}',
  '{light_ansi[6]}',
  '{light_ansi[7]}',
  '{light_ansi[8]}',
  '{light_ansi[9]}',
  '{light_ansi[10]}',
  '{light_ansi[11]}',
  '{light_ansi[12]}',
  '{light_ansi[13]}',
  '{light_ansi[14]}',
  '{light_ansi[15]}',
]
"""

    # Generate extended palette for better nvim UI contrast
    # For dark variant
    def adjust_lightness_for_bg_dim(bg_rgb, amount=0.05):
        """Create bg_dim by slightly lightening background."""
        r, g, b = bg_rgb[0] / 255.0, bg_rgb[1] / 255.0, bg_rgb[2] / 255.0
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        l = min(1.0, l + amount)
        r, g, b = colorsys.hls_to_rgb(h, l, s)
        return (int(r * 255), int(g * 255), int(b * 255))

    def adjust_lightness_for_fg_dim(fg_rgb, amount=-0.15):
        """Create fg_dim by dimming foreground."""
        r, g, b = fg_rgb[0] / 255.0, fg_rgb[1] / 255.0, fg_rgb[2] / 255.0
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        l = max(0.0, min(1.0, l + amount))
        r, g, b = colorsys.hls_to_rgb(h, l, s)
        return (int(r * 255), int(g * 255), int(b * 255))

    # Dark variant extended colors
    dark_bg_dim = adjust_lightness_for_bg_dim(darkest, 0.08)
    dark_fg_dim = adjust_lightness_for_fg_dim(lightest, -0.25)

    dark_extended = f"""
[variants.{variant_dark}.extended]
none = 'NONE'
bg_main = '{rgb_to_hex(darkest)}'
bg_dim = '{rgb_to_hex(dark_bg_dim)}'
fg_main = '{rgb_to_hex(lightest)}'
fg_dim = '{rgb_to_hex(dark_fg_dim)}'
border = '{rgb_to_hex(dark_fg_dim)}'
"""

    # Light variant extended colors
    light_bg_dim = adjust_lightness_for_bg_dim(lightest, -0.05)
    light_fg_dim = adjust_lightness_for_fg_dim(darkest, 0.25)

    light_extended = f"""
[variants.{variant_light}.extended]
none = 'NONE'
bg_main = '{rgb_to_hex(lightest)}'
bg_dim = '{rgb_to_hex(light_bg_dim)}'
fg_main = '{rgb_to_hex(darkest)}'
fg_dim = '{rgb_to_hex(light_fg_dim)}'
border = '{rgb_to_hex(light_fg_dim)}'
"""

    return {
        'light_toml': light_toml,
        'dark_toml': dark_toml,
        'light_extended': light_extended,
        'dark_extended': dark_extended
    }
