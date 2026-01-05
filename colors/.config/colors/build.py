#!/usr/bin/env python3
"""Generate color artifacts from a single palette source."""

from __future__ import annotations

import sys
import os
import socket
from pathlib import Path

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover - fallback for older Pythons
    tomllib = None

ROOT = Path(__file__).resolve().parent.parent.parent.parent  # dotfiles root
PALETTE_FILE = Path(__file__).resolve().parent / "palette.toml"  # same dir as build.py
PALETTES_DIR = Path(__file__).resolve().parent / "palettes"
GHOSTTY_THEME_DIR = ROOT / "ghostty" / ".config" / "ghostty" / "themes"
NVIM_PALETTE_MODULE = ROOT / "nvim" / ".config" / "nvim" / "lua" / "phajas" / "colors" / "palette.lua"
NVIM_COLORSCHEME_FILE = ROOT / "nvim" / ".config" / "nvim" / "colors" / "phajas_palette.lua"
RANGER_CONFIG_DIR = ROOT / "ranger" / ".config" / "ranger"
RANGER_COLORSCHEME_DIR = RANGER_CONFIG_DIR / "colorschemes"
RANGER_RC_FILE = RANGER_CONFIG_DIR / "rc.conf"


class PaletteError(Exception):
    """Raised when the palette file is malformed."""


def _strip_quotes(value: str) -> str:
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        return value[1:-1]
    return value


def parse_simple_toml(text: str) -> dict:
    """Minimal TOML parser that covers the palette file structure."""
    data: dict = {}
    lines = text.splitlines()
    idx = 0
    current = data

    while idx < len(lines):
        raw_line = lines[idx]
        idx += 1
        line = raw_line.strip()

        if not line or line.startswith("#"):
            continue

        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            target = data
            for part in section.split("."):
                target = target.setdefault(part, {})
            current = target
            continue

        if "=" not in line:
            raise PaletteError(f"Invalid line in palette (missing '='): {raw_line}")

        key, value = map(str.strip, line.split("=", 1))

        # Handle multi-line arrays
        if value.startswith("[") and not value.rstrip().endswith("]"):
            parts = [value]
            while idx < len(lines):
                continuation = lines[idx].strip()
                idx += 1
                if not continuation or continuation.startswith("#"):
                    continue
                parts.append(continuation)
                if continuation.rstrip().endswith("]"):
                    break
            value = " ".join(parts)

        parsed = value
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            items = []
            if inner:
                for item in inner.split(","):
                    piece = item.strip()
                    if not piece:
                        continue
                    items.append(_strip_quotes(piece))
            parsed = items
        else:
            parsed = _strip_quotes(value)

        current[key] = parsed

    return data


def _load_toml(path: Path) -> dict:
    raw_text = path.read_text()
    return tomllib.loads(raw_text) if tomllib else parse_simple_toml(raw_text)


def load_palette() -> dict:
    """Load and validate palette data from the TOML source."""
    if not PALETTE_FILE.exists():
        raise PaletteError(f"Palette file missing: {PALETTE_FILE}")

    data = _load_toml(PALETTE_FILE)
    families = data.get("families", {})
    variants = data.get("variants", {})

    if PALETTES_DIR.exists():
        for path in sorted(PALETTES_DIR.glob("*.toml")):
            fragment = _load_toml(path)
            extra_keys = set(fragment.keys()) - {"families", "variants"}
            if extra_keys:
                raise PaletteError(
                    f"Palette fragment {path} contains unsupported keys: {', '.join(sorted(extra_keys))}"
                )

            frag_families = fragment.get("families", {})
            for name, payload in frag_families.items():
                if name in families and families[name] != payload:
                    raise PaletteError(f"Family {name} redefined in {path}")
                families[name] = payload

            frag_variants = fragment.get("variants", {})
            for name, payload in frag_variants.items():
                if name in variants and variants[name] != payload:
                    raise PaletteError(f"Variant {name} redefined in {path}")
                variants[name] = payload

    if not isinstance(variants, dict) or not variants:
        raise PaletteError("Palette must define at least one [variants] table.")

    default_variant = data.get("default_variant")
    data["families"] = families
    data["variants"] = variants

    for name, payload in variants.items():
        if not isinstance(payload, dict):
            raise PaletteError(f"Variant {name} must be a table.")

        required_keys = {
            "flavor",
            "foreground",
            "background",
            "cursor",
            "selection_background",
            "selection_foreground",
            "ansi",
        }
        missing = required_keys - set(payload)
        if missing:
            raise PaletteError(f"Variant {name} is missing keys: {', '.join(sorted(missing))}")

        ansi = payload["ansi"]
        if not isinstance(ansi, list) or len(ansi) != 16:
            raise PaletteError(f"Variant {name} must define 16 ANSI colors.")

    if default_variant and default_variant not in variants:
        raise PaletteError(f"default_variant '{default_variant}' not found in variants.")

    # Validate families
    families = data.get("families", {})
    for family_name, family_data in families.items():
        required = {"name", "license", "light_variant", "dark_variant"}
        missing = required - set(family_data)
        if missing:
            raise PaletteError(f"Family {family_name} missing: {', '.join(missing)}")

    # Validate variant family references
    for variant_name, variant_data in variants.items():
        family = variant_data.get("family")
        if family and family not in families:
            raise PaletteError(f"Variant {variant_name} references unknown family: {family}")

    return {
        "default_variant": default_variant,
        "default_family": data.get("default_family"),
        "variants": variants,
        "families": families,
        "hosts": data.get("hosts", {}),
    }


def apply_host_override(palette: dict) -> dict:
    """Override default variant based on host-specific settings in the palette."""
    host_overrides = palette.get("hosts") or {}
    host_name = os.environ.get("COLOR_HOST") or socket.gethostname()
    override = host_overrides.get(host_name)
    if not override:
        return palette

    desired_default = override.get("default_variant")
    if desired_default:
        if desired_default not in palette["variants"]:
            raise PaletteError(
                f"Host override default_variant '{desired_default}' for host '{host_name}' not found in variants."
            )
        palette["default_variant"] = desired_default
    return palette


def write_if_changed(path: Path, content: str) -> bool:
    """Write content to path if it changed; return True if updated."""
    current = path.read_text() if path.exists() else None
    if current == content:
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    return True


def get_license_header(variant_name: str, variant: dict, families: dict) -> str:
    """Generate appropriate license header based on variant family."""
    family_name = variant.get("family", "modus")
    family_data = families.get(family_name, {})
    license_type = family_data.get("license", "GPL v3")

    family_label = family_data.get("name", family_name)
    if family_name == "catppuccin":
        return "\n".join([
            "# Generated by colors/build.py from colors/palette.toml",
            f"# Palette variant: {variant_name} (Catppuccin family)",
            "# License: MIT (see https://github.com/catppuccin/catppuccin/blob/main/LICENSE)",
            "# Catppuccin © 2021-present Catppuccin Org",
        ])
    if family_name == "modus":
        license_note = "# License: GPL v3 (palette derives from Modus; see colors/LICENSE)"
    elif family_name.startswith("ef_"):
        license_note = "# License: GPL v3 (palette derives from Ef themes; see colors/LICENSE)"
    else:
        license_note = "# License: GPL v3 (see colors/LICENSE)"
    if family_name in {"modus", "ef_melissa"}:
        return "\n".join([
            "# Generated by colors/build.py from colors/palette.toml",
            f"# Palette variant: {variant_name} ({family_label} family)",
            license_note,
        ])
    else:
        return "\n".join([
            "# Generated by colors/build.py from colors/palette.toml",
            f"# Palette variant: {variant_name} ({family_label} family)",
            license_note,
        ])


def render_ghostty_variant(file_name: str, variant_name: str, variant: dict, families: dict) -> str:
    header_lines = get_license_header(variant_name, variant, families).split('\n')
    lines = header_lines + [
        f"# Theme file: {file_name}",
        "",
    ]
    lines.extend(f"palette = {i}={color}" for i, color in enumerate(variant["ansi"]))
    lines.extend(
        [
            f"background = {variant['background']}",
            f"foreground = {variant['foreground']}",
            f"cursor-color = {variant['cursor']}",
            f"selection-background = {variant['selection_background']}",
            f"selection-foreground = {variant['selection_foreground']}",
            "",
        ]
    )
    return "\n".join(lines)

def ghostty_theme_name(variant_name: str, variant: dict, families: dict) -> str:
    family = variant.get("family", "phajas")
    flavor = (variant.get("flavor") or "").lower()
    family_data = families.get(family, {})
    light_default = family_data.get("light_variant")
    dark_default = family_data.get("dark_variant")
    if flavor == "light":
        if variant_name == light_default:
            return f"{family}_light"
        return f"{family}_{variant_name}"
    if flavor == "dark":
        if variant_name == dark_default:
            return f"{family}_dark"
        return f"{family}_{variant_name}"
    return f"{family}_{variant_name}"


def lua_serialize(data, indent: int = 0) -> str:
    pad = "  " * indent
    if isinstance(data, dict):
        parts = ["{"] if indent == 0 else ["{"]  # explicit for readability
        for key, value in data.items():
            parts.append(f'{pad}  ["{key}"] = {lua_serialize(value, indent + 1)},')
        parts.append(f"{pad}}}")
        return "\n".join(parts)
    if isinstance(data, list):
        parts = ["{"] if indent == 0 else ["{"]
        for value in data:
            parts.append(f"{pad}  {lua_serialize(value, indent + 1)},")
        parts.append(f"{pad}}}")
        return "\n".join(parts)
    if isinstance(data, str):
        return f'"{data}"'
    if isinstance(data, bool):
        return "true" if data else "false"
    return str(data)


def write_nvim_palette(data: dict) -> bool:
    lua_table = lua_serialize(data)
    content = "\n".join(
        [
            "-- Generated by colors/build.py from colors/palette.toml",
            "-- This file contains color palettes from multiple sources:",
            "--   Modus themes: GPL v3 (see colors/LICENSE)",
            "--   Ef themes: GPL v3 (see colors/LICENSE)",
            "--   Catppuccin themes: MIT (see https://github.com/catppuccin/catppuccin/blob/main/LICENSE)",
            "-- Palette data for Lua consumers (generated)",
            "return " + lua_table,
            "",
        ]
    )
    return write_if_changed(NVIM_PALETTE_MODULE, content)


def write_nvim_colorscheme(data: dict) -> bool:
    lua_table = lua_serialize(data)
    content = "\n".join(
        [
            "-- Generated by colors/build.py from colors/palette.toml",
            "-- This colorscheme includes palettes from multiple sources:",
            "--   Modus themes: GPL v3 (see colors/LICENSE)",
            "--   Ef themes: GPL v3 (see colors/LICENSE)",
            "--   Catppuccin themes: MIT (see https://github.com/catppuccin/catppuccin/blob/main/LICENSE)",
            "-- Generated colorscheme file is GPL v3 as derivative work",
            "-- Neovim colorscheme entry point (loaded via :colorscheme phajas_palette)",
            "local palette = " + lua_table,
            "",
            "local function select_variant(flavor)",
            "  -- Check if a specific variant was requested via global variable",
            "  if vim.g.phajas_palette_variant then",
            "    local requested = vim.g.phajas_palette_variant",
            "    if palette.variants and palette.variants[requested] then",
            "      return requested, palette.variants[requested]",
            "    end",
            "  end",
            "  ",
            "  -- Fall back to flavor-based selection",
            "  for name, variant in pairs(palette.variants or {}) do",
            "    if variant.flavor == flavor then",
            "      return name, variant",
            "    end",
            "  end",
            "  if palette.default_variant and palette.variants and palette.variants[palette.default_variant] then",
            "    return palette.default_variant, palette.variants[palette.default_variant]",
            "  end",
            "  if palette.variants then",
            "    return next(palette.variants)",
            "  end",
            "end",
            "",
            "local function apply_terminal(variant)",
            "  if not variant or not variant.ansi then",
            "    return",
            "  end",
            "  for i, color in ipairs(variant.ansi) do",
            "    vim.g[\"terminal_color_\" .. (i - 1)] = color",
            "  end",
            "  vim.g.terminal_color_background = variant.background",
            "  vim.g.terminal_color_foreground = variant.foreground",
            "end",
            "",
            "local function set_hl(group, opts)",
            "  vim.api.nvim_set_hl(0, group, opts)",
            "end",
            "",
            "local function colors_for(variant)",
            "  local c = {}",
            "  if variant.extended then",
            "    c = vim.deepcopy(variant.extended)",
            "    -- Derived fields to complete the extended palette",
            "    c.bg_sidebar = c.bg_dim",
            "    c.fg_sidebar = c.fg_main",
            "    c.cursor = c.fg_main",
            "    c.comment = c.fg_dim",
            "    c.error = c.red_cooler",
            "    c.warning = c.yellow_cooler",
            "    c.info = c.blue_cooler",
            "    c.hint = c.cyan_faint",
            "    c.ok = c.green_cooler",
            "    c.success = c.fg_added",
            "    c.visual = c.bg_magenta_intense",
            "    c.accent_light = c.blue_faint",
            "    c.accent = c.blue_warmer",
            "    c.accent_darker = c.blue",
            "    c.accent_dark = c.blue_intense",
            "    -- Default (non-tinted/non-accessibility variants) only for now",
            "    return c",
            "  end",
            "  -- Fallback to ANSI-derived minimal palette.",
            "  local a = variant.ansi or {}",
            "  return {",
            "    bg_main = variant.background,",
            "    fg_main = variant.foreground,",
            "    fg_dim = a[9] or a[8],",
            "    fg_alt = a[5] or variant.foreground,",
            "    border = a[8],",
            "    border_highlight = a[9] or a[8],",
            "    red = a[2], green = a[3], yellow = a[4], blue = a[5], magenta = a[6], cyan = a[7],",
            "    bg_dim = a[8],",
            "    bg_alt = variant.background,",
            "    bg_hl_line = a[8],",
            "    bg_paren_match = a[12] or a[5],",
            "    fg_inactive = a[9] or a[8],",
            "    fg_active = a[15] or a[7],",
            "    bg_active = a[8],",
            "    bg_inactive = a[8],",
            "    fg_tab_other = a[9] or a[8],",
            "    bg_tab_other = a[8],",
            "    fg_status_line_active = a[15] or a[7],",
            "    bg_status_line_active = a[1] or variant.background,",
            "    fg_status_line_inactive = a[9] or a[8],",
            "    bg_status_line_inactive = a[1] or variant.background,",
            "    visual = variant.selection_background,",
            "    fg_added = a[3], fg_changed = a[4], fg_removed = a[2],",
            "    bg_added = variant.background, bg_changed = variant.background, bg_removed = variant.background,",
            "    fg_added_intense = a[11] or a[3],",
            "    fg_changed_intense = a[12] or a[4],",
            "    fg_removed_intense = a[10] or a[2],",
            "    bg_added_refine = variant.background,",
            "    bg_changed_refine = variant.background,",
            "    bg_removed_refine = variant.background,",
            "    bg_completion = a[13] or a[5],",
            "    error = a[10] or a[2],",
            "    warning = a[12] or a[4],",
            "    info = a[13] or a[5],",
            "    hint = a[15] or a[7],",
            "    ok = a[11] or a[3],",
            "  }",
            "end",
            "",
            "local function apply_highlights(variant)",
            "  local c = colors_for(variant)",
            "  local hls = {",
            "    -- UI",
            "    Normal = { fg = c.fg_main, bg = c.bg_main },",
            "    NormalFloat = { fg = c.fg_active or c.fg_main, bg = c.bg_active or c.bg_main },",
            "    FloatBorder = { fg = c.border_highlight or c.border, bg = c.bg_main },",
            "    FloatTitle = { fg = c.border_highlight or c.border, bg = c.bg_main },",
            "    Folded = { fg = c.green_faint or c.green or c.fg_dim, bg = c.bg_dim or c.bg_main },",
            "    LineNr = { fg = c.fg_main, bg = c.bg_dim or c.bg_main },",
            "    LineNrAbove = { fg = c.fg_dim, bg = c.bg_dim or c.bg_main },",
            "    LineNrBelow = { fg = c.fg_dim, bg = c.bg_dim or c.bg_main },",
            "    CursorLineNr = { fg = c.fg_active or c.fg_main, bg = c.bg_active or c.bg_dim, bold = true },",
            "    SignColumn = { fg = c.fg_dim, bg = c.bg_dim or c.bg_main },",
            "    CursorLine = { bg = c.bg_hl_line or c.bg_dim },",
            "    CursorColumn = { bg = c.bg_hl_line or c.bg_dim },",
            "    NonText = { fg = c.fg_dim },",
            "    ColorColumn = { bg = c.bg_dim or c.bg_main },",
            "    FoldColumn = { fg = c.fg_inactive or c.fg_dim, bg = c.bg_inactive or c.bg_dim or c.bg_main },",
            "    Search = { fg = c.fg_main, bg = c.bg_green_intense or c.bg_completion or c.green },",
            "    IncSearch = { fg = c.fg_main, bg = c.bg_yellow_intense or c.yellow },",
            "    CurSearch = { link = \"IncSearch\" },",
            "    Substitute = { fg = c.fg_main, bg = c.bg_red_intense or c.red },",
            "    QuickFixLine = { fg = c.fg_main, bg = c.visual or c.bg_hl_line },",
            "    Pmenu = { fg = c.fg_active or c.fg_main, bg = c.bg_active or c.bg_main },",
            "    PmenuSel = { fg = c.bg_active or c.bg_main, bg = c.fg_active or c.fg_main },",
            "    PmenuSbar = { fg = c.fg_active or c.fg_main, bg = c.bg_dim or c.bg_main },",
            "    PmenuThumb = { fg = c.bg_main, bg = c.cursor or c.fg_main },",
            "    Directory = { fg = c.blue },",
            "    Title = { fg = c.fg_alt or c.blue, bold = true },",
            "    Visual = { fg = c.fg_main, bg = c.visual or c.bg_hl_line },",
            "    VisualNOS = { link = \"Visual\" },",
            "    WildMenu = { fg = c.fg_main, bg = c.visual or c.bg_hl_line },",
            "    Whitespace = { fg = c.fg_dim },",
            "    StatusLine = { fg = c.fg_status_line_active or c.fg_main, bg = c.bg_status_line_active or c.bg_main },",
            "    StatusLineNC = { fg = c.fg_status_line_inactive or c.fg_dim, bg = c.bg_status_line_inactive or c.bg_main },",
            "    TabLine = { fg = c.fg_tab_other or c.fg_dim, bg = c.bg_tab_other or c.bg_dim },",
            "    TabLineSel = { fg = c.fg_main, bg = c.bg_tab_current or c.bg_main, bold = true },",
            "    TabLineFill = { fg = c.fg_dim, bg = c.bg_tab_bar or c.bg_dim },",
            "    WinBar = { link = \"TabLineSel\" },",
            "    WinBarNC = { link = \"TabLine\" },",
            "    EndOfBuffer = { fg = c.fg_inactive or c.fg_dim },",
            "    MatchParen = { fg = c.fg_main, bg = c.bg_paren_match or c.bg_completion },",
            "    ModeMsg = { fg = c.fg_dim, bold = true },",
            "    MsgArea = { fg = c.fg_main },",
            "    MoreMsg = { fg = c.blue },",
            "    VertSplit = { fg = c.border },",
            "    WinSeparator = { fg = c.border, bold = true },",
            "    DiffAdd = { fg = c.fg_added, bg = c.bg_added },",
            "    DiffDelete = { fg = c.fg_removed, bg = c.bg_removed },",
            "    DiffChange = { fg = c.fg_changed, bg = c.bg_changed },",
            "    DiffText = { fg = c.fg_changed, bg = c.bg_changed },",
            "    SpecialKey = { fg = c.fg_dim },",
            "    SpellBad = { sp = c.error, undercurl = true },",
            "    SpellCap = { sp = c.warning, undercurl = true },",
            "    SpellLocal = { sp = c.info, undercurl = true },",
            "    SpellRare = { sp = c.hint, undercurl = true },",
            "    WarningMsg = { fg = c.warning },",
            "    Question = { fg = c.blue },",
            "",
            "    -- Syntax",
            "    Comment = { fg = c.comment or c.fg_dim, italic = true },",
            "    String = { fg = c.blue_warmer or c.green },",
            "    Character = { fg = c.blue_warmer or c.green },",
            "    Boolean = { fg = c.blue or c.magenta, bold = true },",
            "    Statement = { fg = c.magenta_cooler or c.magenta },",
            "    Conditional = { fg = c.magenta_cooler or c.magenta },",
            "    Repeat = { fg = c.magenta_cooler or c.magenta },",
            "    Label = { fg = c.cyan },",
            "    Keyword = { fg = c.magenta_cooler or c.magenta },",
            "    Exception = { fg = c.magenta_cooler or c.magenta },",
            "    StorageClass = { fg = c.magenta_cooler or c.magenta },",
            "    Structure = { fg = c.magenta_cooler or c.magenta },",
            "    Constant = { fg = c.fg_main },",
            "    Function = { fg = c.magenta },",
            "    Identifier = { fg = c.cyan },",
            "    PreProc = { fg = c.red_cooler or c.red },",
            "    Include = { fg = c.red_cooler or c.red },",
            "    Define = { fg = c.red_cooler or c.red },",
            "    Macro = { fg = c.red_cooler or c.red },",
            "    PreCondit = { fg = c.red_cooler or c.red },",
            "    Todo = { fg = c.magenta, bold = true },",
            "    Type = { fg = c.cyan_cooler or c.cyan },",
            "    TypeDef = { fg = c.cyan_warmer or c.cyan },",
            "    Number = { fg = c.blue_faint or c.magenta },",
            "    Float = { link = \"Number\" },",
            "    Operator = { fg = c.fg_main },",
            "    Tag = { fg = c.magenta },",
            "    Delimiter = { fg = c.fg_main },",
            "    Special = { link = \"Type\" },",
            "    SpecialChar = { fg = c.cyan_faint or c.cyan },",
            "    Underlined = { fg = c.fg_alt or c.blue, underline = true },",
            "    Error = { fg = c.fg_main, bg = c.bg_red_intense or c.red },",
            "",
            "    -- Diagnostics",
            "    DiagnosticError = { fg = c.error or c.red_intense, bold = true },",
            "    DiagnosticWarn = { fg = c.warning or c.yellow_intense, bold = true },",
            "    DiagnosticInfo = { fg = c.info or c.blue_intense, bold = true },",
            "    DiagnosticHint = { fg = c.hint or c.cyan_intense, bold = true },",
            "    DiagnosticOk = { fg = c.ok or c.green_intense, bold = true },",
            "    DiagnosticUnnecessary = { fg = c.fg_dim },",
            "    DiagnosticVirtualTextError = { fg = c.error or c.red_intense, bold = true },",
            "    DiagnosticVirtualTextWarn = { fg = c.warning or c.yellow_intense, bold = true },",
            "    DiagnosticVirtualTextInfo = { fg = c.info or c.blue_intense, bold = true },",
            "    DiagnosticVirtualTextHint = { fg = c.hint or c.cyan_intense, bold = true },",
            "    DiagnosticVirtualTextOk = { fg = c.ok or c.green_intense, bold = true },",
            "    DiagnosticUnderlineError = { undercurl = true, sp = c.error or c.red_intense },",
            "    DiagnosticUnderlineWarn = { undercurl = true, sp = c.warning or c.yellow_intense },",
            "    DiagnosticUnderlineInfo = { undercurl = true, sp = c.info or c.blue_intense },",
            "    DiagnosticUnderlineHint = { undercurl = true, sp = c.hint or c.cyan_intense },",
            "    DiagnosticUnderlineOk = { undercurl = true, sp = c.ok or c.green_intense },",
            "",
            "    -- Diff/Git",
            "    GitSignsAdd = { fg = c.fg_added_intense or c.fg_added, bg = c.bg_added or c.bg_main },",
            "    GitSignsChange = { fg = c.fg_changed_intense or c.fg_changed, bg = c.bg_changed or c.bg_main },",
            "    GitSignsDelete = { fg = c.fg_removed_intense or c.fg_removed, bg = c.bg_removed or c.bg_main },",
            "",
            "    -- LSP",
            "    LspReferenceText = { bg = c.bg_blue_intense or c.bg_hl_line, fg = c.fg_main },",
            "    LspReferenceRead = { bg = c.bg_blue_intense or c.bg_hl_line, fg = c.fg_main },",
            "    LspReferenceWrite = { bg = c.bg_blue_intense or c.bg_hl_line, fg = c.fg_main },",
            "",
            "    -- Telescope (basic alignment with palette intent)",
            "    TelescopeNormal = { link = 'Normal' },",
            "    TelescopeBorder = { fg = c.border or c.fg_dim, bg = c.bg_main },",
            "    TelescopeTitle = { fg = c.fg_dim, bg = c.bg_main },",
            "    TelescopeSelection = { link = 'CursorLine' },",
            "    TelescopePromptBorder = { fg = c.border_highlight or c.border, bg = c.bg_main },",
            "    TelescopePromptTitle = { fg = c.border_highlight or c.border, bg = c.bg_main },",
            "    TelescopeResultsComment = { fg = c.fg_dim },",
            "    TelescopePromptNormal = { link = 'Normal' },",
            "    TelescopePromptPrefix = { fg = c.accent_darker or c.blue, bg = c.bg_main },",
            "    TelescopeMatching = { fg = c.accent_dark or c.blue_intense, bold = true },",
            "",
            "    -- Treesitter (core captures)",
            "    ['@comment'] = { link = 'Comment' },",
            "    ['@error'] = { link = 'Error' },",
            "    ['@punctuation'] = { fg = c.fg_dim },",
            "    ['@punctuation.delimiter'] = { link = 'Delimiter' },",
            "    ['@punctuation.bracket'] = { fg = c.fg_main },",
            "    ['@punctuation.special'] = { fg = c.fg_main },",
            "    ['@string'] = { link = 'String' },",
            "    ['@character'] = { link = 'Character' },",
            "    ['@number'] = { link = 'Number' },",
            "    ['@boolean'] = { link = 'Boolean' },",
            "    ['@float'] = { link = 'Float' },",
            "    ['@constant'] = { link = 'Constant' },",
            "    ['@constant.builtin'] = { fg = c.magenta },",
            "    ['@constant.macro'] = { fg = c.red_cooler or c.red },",
            "    ['@namespace'] = { fg = c.fg_alt or c.blue },",
            "    ['@symbol'] = { fg = c.magenta },",
            "    ['@variable'] = { fg = c.fg_main },",
            "    ['@variable.builtin'] = { fg = c.magenta_cooler or c.magenta },",
            "    ['@variable.parameter'] = { fg = c.fg_main },",
            "    ['@variable.member'] = { fg = c.cyan },",
            "    ['@property'] = { link = '@field' },",
            "    ['@field'] = { fg = c.fg_main },",
            "    ['@function'] = { link = 'Function' },",
            "    ['@function.builtin'] = { fg = c.blue_warmer or c.blue },",
            "    ['@function.macro'] = { fg = c.red_cooler or c.red },",
            "    ['@method'] = { link = 'Function' },",
            "    ['@constructor'] = { fg = c.blue },",
            "    ['@parameter'] = { fg = c.fg_main },",
            "    ['@keyword'] = { link = 'Keyword' },",
            "    ['@keyword.function'] = { link = 'Keyword' },",
            "    ['@keyword.operator'] = { link = 'Operator' },",
            "    ['@keyword.return'] = { link = 'Keyword' },",
            "    ['@conditional'] = { link = 'Conditional' },",
            "    ['@repeat'] = { link = 'Repeat' },",
            "    ['@debug'] = { fg = c.red_cooler or c.red },",
            "    ['@label'] = { link = 'Label' },",
            "    ['@include'] = { link = 'Include' },",
            "    ['@exception'] = { link = 'Exception' },",
            "    ['@type'] = { link = 'Type' },",
            "    ['@type.builtin'] = { fg = c.cyan_cooler or c.cyan },",
            "    ['@type.definition'] = { link = 'Typedef' },",
            "    ['@storageclass'] = { link = 'StorageClass' },",
            "    ['@attribute'] = { fg = c.blue_warmer or c.blue },",
            "    ['@field.yaml'] = { fg = c.cyan },",
            "    ['@string.regex'] = { fg = c.blue_warmer or c.blue },",
            "    ['@string.escape'] = { fg = c.magenta },",
            "    ['@string.special'] = { fg = c.blue },",
            "    ['@text.title'] = { fg = c.blue, bold = true },",
            "    ['@text.emphasis'] = { italic = true },",
            "    ['@text.strong'] = { bold = true },",
            "    ['@text.uri'] = { fg = c.blue, underline = true },",
            "    ['@text.reference'] = { fg = c.magenta },",
            "    ['@text.literal'] = { fg = c.green },",
            "    ['@text.note'] = { fg = c.blue, bold = true },",
            "    ['@text.warning'] = { fg = c.warning or c.yellow },",
            "    ['@text.danger'] = { fg = c.error or c.red },",
            "",
            "    -- Treesitter context",
            "    TreesitterContext = { bg = c.bg_dim or c.bg_main },",
            "    TreesitterContextLineNumber = { fg = c.fg_dim, bg = c.bg_dim or c.bg_main },",
            "",
            "    -- NvimTree",
            "    NvimTreeNormal = { fg = c.fg_main, bg = c.bg_alt or c.bg_main },",
            "    NvimTreeNormalNC = { fg = c.fg_main, bg = c.bg_alt or c.bg_main },",
            "    NvimTreeFolderName = { fg = c.blue },",
            "    NvimTreeFolderIcon = { fg = c.blue },",
            "    NvimTreeRootFolder = { fg = c.magenta, bold = true },",
            "    NvimTreeSymlink = { fg = c.cyan },",
            "    NvimTreeExecFile = { fg = c.green },",
            "    NvimTreeSpecialFile = { fg = c.magenta_warmer or c.magenta, bold = true },",
            "    NvimTreeIndentMarker = { fg = c.fg_dim },",
            "    NvimTreeGitNew = { fg = c.fg_added_intense or c.fg_added },",
            "    NvimTreeGitDirty = { fg = c.fg_changed_intense or c.fg_changed },",
            "    NvimTreeGitDeleted = { fg = c.fg_removed_intense or c.fg_removed },",
            "    NvimTreeWinSeparator = { fg = c.border, bg = c.bg_alt or c.bg_main },",
            "",
            "    -- DAP / DAP UI",
            "    DapBreakpoint = { fg = c.red },",
            "    DapBreakpointCondition = { fg = c.yellow },",
            "    DapBreakpointRejected = { fg = c.red_intense or c.red },",
            "    DapStopped = { fg = c.green },",
            "    DapLogPoint = { fg = c.cyan },",
            "    DapUIScope = { fg = c.cyan },",
            "    DapUIType = { fg = c.magenta },",
            "    DapUIValue = { fg = c.fg_main },",
            "    DapUIThread = { fg = c.green },",
            "    DapUIStoppedThread = { fg = c.red },",
            "    DapUISource = { fg = c.blue },",
            "    DapUILineNumber = { fg = c.accent or c.blue },",
            "    DapUIFloatBorder = { fg = c.border_highlight or c.border, bg = c.bg_main },",
            "    DapUIWatchesValue = { fg = c.green },",
            "    DapUIWatchesError = { fg = c.red },",
            "    NvimDapVirtualText = { fg = c.fg_dim, italic = true },",
            "",
            "    -- Completion (cmp-style groups used by blink.cmp too)",
            "    CmpItemAbbr = { fg = c.fg_main },",
            "    CmpItemAbbrDeprecated = { fg = c.fg_dim, strikethrough = true },",
            "    CmpItemAbbrMatch = { fg = c.accent or c.blue, bold = true },",
            "    CmpItemAbbrMatchFuzzy = { fg = c.accent_dark or c.blue_intense, bold = true },",
            "    CmpItemMenu = { fg = c.fg_dim },",
            "    CmpItemKindText = { fg = c.fg_main },",
            "    CmpItemKindMethod = { fg = c.blue },",
            "    CmpItemKindFunction = { fg = c.blue },",
            "    CmpItemKindConstructor = { fg = c.magenta },",
            "    CmpItemKindField = { fg = c.cyan },",
            "    CmpItemKindVariable = { fg = c.fg_main },",
            "    CmpItemKindClass = { fg = c.cyan },",
            "    CmpItemKindInterface = { fg = c.cyan },",
            "    CmpItemKindModule = { fg = c.fg_alt or c.blue },",
            "    CmpItemKindProperty = { fg = c.cyan },",
            "    CmpItemKindUnit = { fg = c.yellow },",
            "    CmpItemKindValue = { fg = c.fg_main },",
            "    CmpItemKindEnum = { fg = c.yellow },",
            "    CmpItemKindKeyword = { fg = c.magenta },",
            "    CmpItemKindSnippet = { fg = c.green },",
            "    CmpItemKindColor = { fg = c.magenta },",
            "    CmpItemKindFile = { fg = c.fg_main },",
            "    CmpItemKindReference = { fg = c.magenta },",
            "    CmpItemKindFolder = { fg = c.blue },",
            "    CmpItemKindEnumMember = { fg = c.yellow },",
            "    CmpItemKindConstant = { fg = c.fg_main },",
            "    CmpItemKindStruct = { fg = c.cyan },",
            "    CmpItemKindEvent = { fg = c.magenta },",
            "    CmpItemKindOperator = { fg = c.fg_main },",
            "    CmpItemKindTypeParameter = { fg = c.cyan },",
            "  }",
            "",
            "  for group, opts in pairs(hls) do",
            "    set_hl(group, opts)",
            "  end",
            "end",
            "",
            "local function apply()",
            "  vim.o.termguicolors = true",
            "  local name, variant = select_variant(vim.o.background)",
            "  if not variant then",
            "    return",
            "  end",
            "  apply_terminal(variant)",
            "  apply_highlights(variant)",
            "  vim.g.colors_name = \"phajas_palette\"",
            "  return name, variant",
            "end",
            "",
            "apply()",
            "",
            "return {",
            "  palette = palette,",
            "  apply = apply,",
            "  select_variant = select_variant,",
            "}",
            "",
        ]
    )
    return write_if_changed(NVIM_COLORSCHEME_FILE, content)


def write_ghostty_palettes(variants: dict, families: dict) -> bool:
    changed = False
    seen = {}
    for name, variant in variants.items():
        file_name = ghostty_theme_name(name, variant, families)
        if file_name in seen:
            raise PaletteError(
                f"Multiple variants map to Ghostty theme '{file_name}' (from '{seen[file_name]}' and '{name}')."
            )
        seen[file_name] = name

        ghostty_file = GHOSTTY_THEME_DIR / file_name
        rendered = render_ghostty_variant(file_name, name, variant, families)
        if write_if_changed(ghostty_file, rendered):
            changed = True
    return changed


def ranger_scheme_name(variant_name: str, variant: dict) -> str:
    flavor = (variant.get("flavor") or "").lower()
    if flavor == "light":
        return "phajas_light"
    if flavor == "dark":
        return "phajas_dark"
    return f"phajas_{variant_name}"


def render_ranger_colorscheme(variant_name: str, variant: dict) -> str:
    flavor = (variant.get("flavor") or "").lower()
    accent = "blue" if flavor == "light" else "cyan"
    emphasis = "magenta" if flavor == "light" else "magenta"
    progress = "cyan" if flavor == "dark" else "blue"
    lines = [
        "# Generated by colors/build.py from colors/palette.toml",
        f"# Palette variant: {variant_name}",
        "# Colors rely on terminal ANSI slots provided by the palette;",
        "# keep palette.toml in sync with your terminal for best results.",
        "",
        "from ranger.gui.colorscheme import ColorScheme",
        "from ranger.gui.color import *",
        "",
        f"ACCENT = {accent}",
        f"EMPHASIS = {emphasis}",
        "ERROR = red",
        "SUCCESS = green",
        "WARNING = yellow",
        "",
        "class Scheme(ColorScheme):",
        f"    progress_bar_color = {progress}",
        "",
        "    def use(self, context):",
        "        fg, bg, attr = default_colors",
        "        if context.reset:",
        "            return default_colors",
        "",
        "        if context.in_browser:",
        "            if context.selected:",
        "                attr |= reverse",
        "            if context.marked:",
        "                attr |= bold",
        "                fg = WARNING",
        "            if context.bad:",
        "                fg = ERROR",
        "                attr |= bold",
        "            elif context.directory:",
        "                fg = ACCENT",
        "            elif context.link:",
        "                fg = cyan if not context.bad else ERROR",
        "            elif context.fifo or context.socket:",
        "                fg = EMPHASIS",
        "            elif context.executable and not context.directory:",
        "                fg = SUCCESS",
        "                attr |= bold",
        "            elif context.media:",
        "                fg = EMPHASIS",
        "            if context.inactive_pane:",
        "                attr |= dim",
        "",
        "        elif context.in_titlebar:",
        "            attr |= bold",
        "            if context.hostname:",
        "                fg = SUCCESS if not context.bad else ERROR",
        "            elif context.directory:",
        "                fg = ACCENT",
        "            elif context.tab:",
        "                fg = cyan if context.good else ACCENT",
        "            elif context.link:",
        "                fg = cyan",
        "",
        "        elif context.in_statusbar:",
        "            if context.permissions:",
        "                if context.good:",
        "                    fg = SUCCESS",
        "                elif context.bad:",
        "                    fg = ERROR",
        "            if context.marked:",
        "                attr |= bold | reverse",
        "            if context.message:",
        "                fg = default",
        "",
        "        if context.text:",
        "            if context.highlight:",
        "                attr |= reverse",
        "            if context.bad:",
        "                fg = ERROR",
        "",
        "        if context.in_taskview:",
        "            if context.title:",
        "                attr |= bold",
        "                fg = ACCENT",
        "            if context.selected:",
        "                attr |= reverse",
        "            if context.loaded:",
        "                fg = SUCCESS",
        "            if context.failed:",
        "                fg = ERROR",
        "",
        "        return fg, bg, attr",
        "",
    ]
    return "\n".join(lines)


def render_ranger_rc(scheme_name: str, variant_name: str | None) -> str:
    details = variant_name or "default"
    return "\n".join(
        [
            "# Generated by colors/build.py from colors/palette.toml",
            f"# Default colorscheme derived from palette variant: {details}",
            "# Edit palette.toml to change variants; local overrides can go in rc.local.",
            "",
            f"set colorscheme {scheme_name}",
            "set show_hidden true",
            "set draw_borders both",
            "",
        ]
    )


def write_ranger_configs(palette: dict) -> bool:
    changed = False
    variants = palette.get("variants") or {}
    for name, variant in variants.items():
        scheme_name = ranger_scheme_name(name, variant)
        scheme_file = RANGER_COLORSCHEME_DIR / f"{scheme_name}.py"
        rendered = render_ranger_colorscheme(name, variant)
        if write_if_changed(scheme_file, rendered):
            changed = True

    if variants:
        default_variant = palette.get("default_variant") or next(iter(variants))
        default_scheme = ranger_scheme_name(default_variant, variants[default_variant])
        rc_content = render_ranger_rc(default_scheme, default_variant)
        if write_if_changed(RANGER_RC_FILE, rc_content):
            changed = True

    return changed


def main() -> int:
    try:
        palette = apply_host_override(load_palette())
    except PaletteError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    changed = False
    changed |= write_ghostty_palettes(palette["variants"], palette.get("families", {}))
    changed |= write_nvim_palette(palette)
    changed |= write_nvim_colorscheme(palette)
    changed |= write_ranger_configs(palette)

    print(f"changed={'true' if changed else 'false'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
