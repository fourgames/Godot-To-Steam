#!/usr/bin/env python3
"""Generates public/theme.tres – a warm, near-black theme modelled on the Claude desktop app.

Edit the palette below and run:  python3 tools/theme_generator.py
"""
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "public", "theme.tres")
THEME_UID = "uid://b56qgya4xh3s2"  # same uid the project.godot [gui] section pointed at before

# ---- palette ---------------------------------------------------------------
BG_APP        = "#1e1d1a"
BG_SIDEBAR    = "#171614"
BG_FOOTER     = "#141312"
BG_CARD       = "#262523"
BG_CARD_HOVER = "#2c2b28"
BG_INPUT      = "#1a1917"
BG_CONSOLE    = "#121110"
BG_POPUP      = "#232220"
BORDER        = "#2f2e2a"
BORDER_STRONG = "#3b3a35"
TEXT          = "#ebe7df"
TEXT_2        = "#a8a49b"
TEXT_MUTED    = "#6e6a62"
ACCENT        = "#d97757"
ACCENT_HOVER  = "#e2896b"
ACCENT_PRESS  = "#c4684a"
ON_ACCENT     = "#fff7f2"
ERR           = "#ef7f75"

def col(hexstr, a=1.0):
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.4g}, {g:.4g}, {b:.4g}, {a:.4g})"

subs = []      # (id, type, {prop: value})
def sub(sid, stype, **props):
    subs.append((sid, stype, props))
    return f'SubResource("{sid}")'

def four(v):
    return v if isinstance(v, (tuple, list)) else (v, v, v, v)

def flat(sid, bg=None, bg_a=1.0, border=None, border_a=1.0, bw=0, radius=0, margins=None,
         shadow=None, draw_center=True, expand=None):
    p = {}
    if margins is not None:
        l, t, r, b = four(margins)
        p.update(content_margin_left=float(l), content_margin_top=float(t),
                 content_margin_right=float(r), content_margin_bottom=float(b))
    p["bg_color"] = col(bg, bg_a) if bg else col("#000000", 0.0)
    if not draw_center:
        p["draw_center"] = "false"
    if border:
        l, t, r, b = four(bw)
        for k, v in (("border_width_left", l), ("border_width_top", t),
                     ("border_width_right", r), ("border_width_bottom", b)):
            if v:
                p[k] = v
        p["border_color"] = col(border, border_a)
    if radius:
        for k in ("corner_radius_top_left", "corner_radius_top_right",
                  "corner_radius_bottom_right", "corner_radius_bottom_left"):
            p[k] = radius
        p["corner_detail"] = 8
    if expand:
        l, t, r, b = four(expand)
        p.update(expand_margin_left=float(l), expand_margin_top=float(t),
                 expand_margin_right=float(r), expand_margin_bottom=float(b))
    if shadow:
        size, alpha, oy = shadow
        p["shadow_color"] = col("#000000", alpha)
        p["shadow_size"] = size
        p["shadow_offset"] = f"Vector2(0, {oy})"
    p["anti_aliasing_size"] = 1.0
    return sub(sid, "StyleBoxFlat", **p)

def empty(sid, margins=0):
    l, t, r, b = four(margins)
    return sub(sid, "StyleBoxEmpty", content_margin_left=float(l), content_margin_top=float(t),
               content_margin_right=float(r), content_margin_bottom=float(b))

def line(sid, color, vertical=False, thickness=1):
    p = dict(color=col(color), thickness=thickness)
    if vertical:
        p["vertical"] = "true"
    return sub(sid, "StyleBoxLine", **p)

UI = 'ExtResource("1_ui")'
SEMI = 'ExtResource("2_semibold")'
MONO = 'ExtResource("3_mono")'

T = {}  # theme item -> value (ordered)
def item(k, v): T[k] = v
def variation(name, base): item(f"{name}/base_type", f'&"{base}"')

# ---- Button ---------------------------------------------------------------
BTN_M = (12, 6, 12, 6)
item("Button/styles/normal",   flat("btn_normal", BG_CARD, border=BORDER_STRONG, bw=1, radius=6, margins=BTN_M))
item("Button/styles/hover",    flat("btn_hover", "#32312d", border="#46443f", bw=1, radius=6, margins=BTN_M))
item("Button/styles/pressed",  flat("btn_pressed", "#3a3934", border="#4c4a44", bw=1, radius=6, margins=BTN_M))
item("Button/styles/hover_pressed", 'SubResource("btn_pressed")')
item("Button/styles/disabled", flat("btn_disabled", "#222120", border="#2a2926", bw=1, radius=6, margins=BTN_M))
item("Button/styles/focus",    flat("btn_focus", border=ACCENT, border_a=0.55, bw=1, radius=6, draw_center=False))
for state, c in (("font_color", TEXT), ("font_hover_color", TEXT), ("font_pressed_color", TEXT),
                 ("font_hover_pressed_color", TEXT), ("font_focus_color", TEXT),
                 ("font_disabled_color", TEXT_MUTED), ("icon_normal_color", TEXT_2),
                 ("icon_hover_color", TEXT), ("icon_pressed_color", TEXT),
                 ("icon_focus_color", TEXT), ("icon_disabled_color", TEXT_MUTED)):
    item(f"Button/colors/{state}", col(c))
item("Button/constants/h_separation", 6)
item("Button/constants/outline_size", 0)
item("Button/font_sizes/font_size", 13)

# Primary (accent) button – the Build & Publish / New Game call to action.
variation("PrimaryButton", "Button")
PM = (16, 8, 16, 8)
item("PrimaryButton/styles/normal",   flat("primary_normal", ACCENT, radius=8, margins=PM))
item("PrimaryButton/styles/hover",    flat("primary_hover", ACCENT_HOVER, radius=8, margins=PM))
item("PrimaryButton/styles/pressed",  flat("primary_pressed", ACCENT_PRESS, radius=8, margins=PM))
item("PrimaryButton/styles/hover_pressed", 'SubResource("primary_pressed")')
item("PrimaryButton/styles/disabled", flat("primary_disabled", "#4a3a33", radius=8, margins=PM))
item("PrimaryButton/styles/focus",    flat("primary_focus", border=ON_ACCENT, border_a=0.5, bw=1, radius=8, draw_center=False))
for state in ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
    item(f"PrimaryButton/colors/{state}", col(ON_ACCENT))
item("PrimaryButton/colors/font_disabled_color", col("#9a8880"))
item("PrimaryButton/fonts/font", SEMI)
item("PrimaryButton/font_sizes/font_size", 14)

# Flat / ghost button – secondary actions in headers.
variation("FlatButton", "Button")
FM = (10, 5, 10, 5)
item("FlatButton/styles/normal",   empty("flat_normal", FM))
item("FlatButton/styles/hover",    flat("flat_hover", "#2b2a27", radius=6, margins=FM))
item("FlatButton/styles/pressed",  flat("flat_pressed", "#35342f", radius=6, margins=FM))
item("FlatButton/styles/hover_pressed", 'SubResource("flat_pressed")')
item("FlatButton/styles/disabled", empty("flat_disabled", FM))
item("FlatButton/styles/focus",    flat("flat_focus", border=ACCENT, border_a=0.5, bw=1, radius=6, draw_center=False))
item("FlatButton/colors/font_color", col(TEXT_2))
item("FlatButton/colors/font_hover_color", col(TEXT))
item("FlatButton/colors/font_pressed_color", col(TEXT))
item("FlatButton/colors/font_hover_pressed_color", col(TEXT))
item("FlatButton/colors/font_focus_color", col(TEXT))
item("FlatButton/font_sizes/font_size", 13)

# Danger flat button – hover turns red (Remove).
variation("DangerButton", "FlatButton")
item("DangerButton/colors/font_hover_color", col(ERR))
item("DangerButton/colors/font_pressed_color", col(ERR))
item("DangerButton/colors/font_hover_pressed_color", col(ERR))

# Small square icon button ("+", "✕").
variation("IconButton", "Button")
IM = (6, 3, 6, 3)
item("IconButton/styles/normal",   empty("icon_normal", IM))
item("IconButton/styles/hover",    flat("icon_hover", "#2f2e2a", radius=6, margins=IM))
item("IconButton/styles/pressed",  flat("icon_pressed", "#3a3934", radius=6, margins=IM))
item("IconButton/styles/hover_pressed", 'SubResource("icon_pressed")')
item("IconButton/styles/disabled", empty("icon_disabled", IM))
item("IconButton/styles/focus",    flat("icon_focus", border=ACCENT, border_a=0.5, bw=1, radius=6, draw_center=False))
item("IconButton/colors/font_color", col(TEXT_MUTED))
item("IconButton/colors/font_hover_color", col(TEXT))
item("IconButton/colors/font_pressed_color", col(TEXT))
item("IconButton/colors/font_hover_pressed_color", col(TEXT))
item("IconButton/colors/font_focus_color", col(TEXT))
item("IconButton/colors/font_disabled_color", col("#4a4741"))
for state, c in (("icon_normal_color", TEXT_MUTED), ("icon_hover_color", TEXT),
                 ("icon_pressed_color", TEXT), ("icon_hover_pressed_color", TEXT),
                 ("icon_focus_color", TEXT), ("icon_disabled_color", "#4a4741")):
    item(f"IconButton/colors/{state}", col(c))
item("IconButton/font_sizes/font_size", 15)

# Sidebar rows – nav entries, game entries, account header.
variation("SidebarItem", "Button")
SM = (10, 6, 10, 6)
item("SidebarItem/styles/normal",   empty("side_normal", SM))
item("SidebarItem/styles/hover",    flat("side_hover", "#222120", radius=8, margins=SM))
item("SidebarItem/styles/pressed",  flat("side_pressed", "#2b2a27", radius=8, margins=SM))
item("SidebarItem/styles/hover_pressed", flat("side_hover_pressed", "#302f2b", radius=8, margins=SM))
item("SidebarItem/styles/disabled", empty("side_disabled", SM))
item("SidebarItem/styles/focus",    flat("side_focus", border=ACCENT, border_a=0.45, bw=1, radius=8, draw_center=False))
item("SidebarItem/colors/font_color", col(TEXT_2))
item("SidebarItem/colors/font_hover_color", col(TEXT))
item("SidebarItem/colors/font_pressed_color", col(TEXT))
item("SidebarItem/colors/font_hover_pressed_color", col(TEXT))
item("SidebarItem/colors/font_focus_color", col(TEXT))
item("SidebarItem/colors/font_disabled_color", col(TEXT_MUTED))
item("SidebarItem/colors/icon_normal_color", col(TEXT_MUTED))
item("SidebarItem/colors/icon_hover_color", col(TEXT_2))
item("SidebarItem/colors/icon_pressed_color", col(TEXT))
item("SidebarItem/constants/h_separation", 8)
item("SidebarItem/font_sizes/font_size", 13)

# Vector checkbox: an 18x18 toggle Button whose "✓" text is invisible until
# pressed. Stays crisp at any content scale, unlike the raster CheckBox icons.
variation("CheckToggle", "Button")
item("CheckToggle/styles/normal",   flat("ct_normal", BG_INPUT, border=BORDER_STRONG, bw=1, radius=4))
item("CheckToggle/styles/hover",    flat("ct_hover", "#22211f", border="#4c4a44", bw=1, radius=4))
item("CheckToggle/styles/pressed",  flat("ct_pressed", ACCENT, radius=4))
item("CheckToggle/styles/hover_pressed", flat("ct_hover_pressed", ACCENT_HOVER, radius=4))
item("CheckToggle/styles/disabled", flat("ct_disabled", "#222120", border="#2a2926", bw=1, radius=4))
item("CheckToggle/styles/focus",    flat("ct_focus", border=ACCENT, border_a=0.6, bw=1, radius=4, draw_center=False))
item("CheckToggle/colors/font_color", col("#000000", 0.0))
item("CheckToggle/colors/font_hover_color", col("#000000", 0.0))
item("CheckToggle/colors/font_focus_color", col("#000000", 0.0))
item("CheckToggle/colors/font_disabled_color", col("#000000", 0.0))
item("CheckToggle/colors/font_pressed_color", col(ON_ACCENT))
item("CheckToggle/colors/font_hover_pressed_color", col(ON_ACCENT))
item("CheckToggle/fonts/font", SEMI)
item("CheckToggle/font_sizes/font_size", 11)
item("CheckToggle/constants/align_to_largest_stylebox", 0)

# ---- CheckBox / OptionButton ----------------------------------------------
item("CheckBox/styles/normal",  empty("chk_normal", (4, 4, 4, 4)))
item("CheckBox/styles/hover",   empty("chk_hover", (4, 4, 4, 4)))
item("CheckBox/styles/pressed", empty("chk_pressed", (4, 4, 4, 4)))
item("CheckBox/styles/hover_pressed", empty("chk_hover_pressed", (4, 4, 4, 4)))
item("CheckBox/styles/disabled", empty("chk_disabled", (4, 4, 4, 4)))
item("CheckBox/styles/focus",   flat("chk_focus", border=ACCENT, border_a=0.5, bw=1, radius=6, draw_center=False))
item("CheckBox/colors/font_color", col(TEXT_2))
item("CheckBox/colors/font_hover_color", col(TEXT))
item("CheckBox/colors/font_pressed_color", col(TEXT))
item("CheckBox/colors/font_hover_pressed_color", col(TEXT))
item("CheckBox/colors/font_focus_color", col(TEXT))
item("CheckBox/colors/icon_normal_color", col(TEXT_2))
item("CheckBox/colors/icon_hover_color", col(TEXT))
item("CheckBox/colors/icon_pressed_color", col(ACCENT))
item("CheckBox/colors/icon_hover_pressed_color", col(ACCENT_HOVER))
item("CheckBox/colors/icon_focus_color", col(ACCENT))
item("CheckBox/constants/h_separation", 8)
item("CheckBox/font_sizes/font_size", 13)

item("OptionButton/styles/normal",   'SubResource("btn_normal")')
item("OptionButton/styles/hover",    'SubResource("btn_hover")')
item("OptionButton/styles/pressed",  'SubResource("btn_pressed")')
item("OptionButton/styles/hover_pressed", 'SubResource("btn_pressed")')
item("OptionButton/styles/disabled", 'SubResource("btn_disabled")')
item("OptionButton/styles/focus",    'SubResource("btn_focus")')
item("OptionButton/colors/font_color", col(TEXT))
item("OptionButton/colors/font_hover_color", col(TEXT))
item("OptionButton/colors/font_pressed_color", col(TEXT))
item("OptionButton/colors/font_hover_pressed_color", col(TEXT))
item("OptionButton/colors/font_focus_color", col(TEXT))
item("OptionButton/colors/font_disabled_color", col(TEXT_MUTED))
item("OptionButton/constants/arrow_margin", 8)
item("OptionButton/constants/modulate_arrow", 1)
item("OptionButton/font_sizes/font_size", 13)

# Red-bordered dropdown for a depot row whose preset failed validation.
variation("ErrorOption", "OptionButton")
item("ErrorOption/styles/normal",  flat("opt_error_normal", BG_CARD, border=ERR, bw=1, radius=6, margins=BTN_M))
item("ErrorOption/styles/hover",   flat("opt_error_hover", "#32312d", border=ERR, bw=1, radius=6, margins=BTN_M))
item("ErrorOption/styles/pressed", flat("opt_error_pressed", "#3a3934", border=ERR, bw=1, radius=6, margins=BTN_M))
item("ErrorOption/styles/hover_pressed", 'SubResource("opt_error_pressed")')
item("ErrorOption/styles/focus",   flat("opt_error_focus", border=ERR, border_a=0.85, bw=1, radius=6, draw_center=False))

# ---- LineEdit -------------------------------------------------------------
LM = (10, 7, 10, 7)
item("LineEdit/styles/normal",    flat("le_normal", BG_INPUT, border=BORDER_STRONG, bw=1, radius=6, margins=LM))
item("LineEdit/styles/focus",     flat("le_focus", BG_INPUT, border=ACCENT, border_a=0.85, bw=1, radius=6, margins=LM))
item("LineEdit/styles/read_only", flat("le_readonly", "#1f1e1b", border=BORDER, bw=1, radius=6, margins=LM))
item("LineEdit/colors/font_color", col(TEXT))
item("LineEdit/colors/font_placeholder_color", col(TEXT_MUTED))
item("LineEdit/colors/font_uneditable_color", col(TEXT_2))
item("LineEdit/colors/font_selected_color", col(TEXT))
item("LineEdit/colors/selection_color", col(ACCENT, 0.35))
item("LineEdit/colors/caret_color", col(ACCENT))
item("LineEdit/colors/clear_button_color", col(TEXT_2))
item("LineEdit/colors/clear_button_color_pressed", col(TEXT))
item("LineEdit/constants/caret_width", 1)
item("LineEdit/font_sizes/font_size", 13)

# Red-bordered field for a required value that is missing or invalid.
# Same geometry as le_normal so toggling the variation never shifts layout.
variation("ErrorField", "LineEdit")
item("ErrorField/styles/normal", flat("le_error", BG_INPUT, border=ERR, bw=1, radius=6, margins=LM))
item("ErrorField/styles/focus",  flat("le_error_focus", BG_INPUT, border=ERR, border_a=0.85, bw=1, radius=6, margins=LM))

# Borderless inline field (project path).
variation("GhostField", "LineEdit")
item("GhostField/styles/normal",    empty("ghost_normal", (0, 2, 0, 2)))
item("GhostField/styles/focus",     empty("ghost_focus", (0, 2, 0, 2)))
item("GhostField/styles/read_only", empty("ghost_readonly", (0, 2, 0, 2)))
item("GhostField/colors/font_uneditable_color", col(TEXT_MUTED))
item("GhostField/font_sizes/font_size", 12)

# ---- Labels ---------------------------------------------------------------
item("Label/colors/font_color", col(TEXT))
item("Label/font_sizes/font_size", 14)
item("Label/styles/normal", empty("label_normal"))

variation("Heading", "Label")
item("Heading/fonts/font", SEMI)
item("Heading/font_sizes/font_size", 22)

variation("Subheading", "Label")
item("Subheading/fonts/font", SEMI)
item("Subheading/font_sizes/font_size", 15)

variation("SectionLabel", "Label")
item("SectionLabel/colors/font_color", col(TEXT_MUTED))
item("SectionLabel/fonts/font", SEMI)
item("SectionLabel/font_sizes/font_size", 12)

variation("FieldLabel", "Label")
item("FieldLabel/colors/font_color", col(TEXT_2))
item("FieldLabel/font_sizes/font_size", 13)

# The red "*" after a required field's label.
variation("RequiredMark", "Label")
item("RequiredMark/colors/font_color", col(ERR))
item("RequiredMark/font_sizes/font_size", 13)

variation("Muted", "Label")
item("Muted/colors/font_color", col(TEXT_2))
item("Muted/font_sizes/font_size", 13)

variation("Caption", "Label")
item("Caption/colors/font_color", col(TEXT_MUTED))
item("Caption/font_sizes/font_size", 12)

variation("OnAccent", "Label")
item("OnAccent/colors/font_color", col(ON_ACCENT))
item("OnAccent/fonts/font", SEMI)
item("OnAccent/font_sizes/font_size", 12)

# ---- Panels ---------------------------------------------------------------
item("Panel/styles/panel", flat("panel_app", BG_APP))
item("PanelContainer/styles/panel", empty("pc_empty"))
item("ScrollContainer/styles/panel", empty("sc_empty"))
item("MarginContainer/constants/margin_left", 0)

variation("Card", "PanelContainer")
item("Card/styles/panel", flat("card", BG_CARD, border=BORDER, bw=1, radius=10, margins=(16, 14, 16, 14)))

variation("Chip", "PanelContainer")
item("Chip/styles/panel", flat("chip", "#2b2a27", border=BORDER_STRONG, bw=1, radius=6, margins=(9, 3, 9, 3)))

variation("Banner", "PanelContainer")
item("Banner/styles/panel", flat("banner", BG_POPUP, border=BORDER, bw=1, radius=8, margins=(12, 8, 12, 8)))

variation("Composer", "PanelContainer")
item("Composer/styles/panel", flat("composer", BG_CARD, border=BORDER_STRONG, bw=1, radius=12,
                                   margins=(14, 10, 10, 10), shadow=(14, 0.35, 4)))

variation("Sidebar", "PanelContainer")
item("Sidebar/styles/panel", flat("sidebar", BG_SIDEBAR, border=BORDER, bw=(0, 0, 1, 0)))

variation("SidebarFooter", "PanelContainer")
item("SidebarFooter/styles/panel", flat("sidebar_footer", BG_FOOTER, border=BORDER, bw=(0, 1, 0, 0), margins=(10, 8, 10, 10)))

variation("ConsolePanel", "PanelContainer")
item("ConsolePanel/styles/panel", flat("console_panel", BG_CONSOLE, border=BORDER, bw=(1, 0, 0, 0)))

variation("Avatar", "PanelContainer")
item("Avatar/styles/panel", flat("avatar", ACCENT, radius=13))

variation("Dot", "Panel")
item("Dot/styles/panel", flat("dot", "#ffffff", radius=4))

variation("Divider", "Panel")
item("Divider/styles/panel", flat("divider", BORDER))

# ---- Scrollbars -----------------------------------------------------------
item("VScrollBar/styles/scroll",       empty("vscroll_bg", (3, 2, 3, 2)))
item("VScrollBar/styles/scroll_focus", empty("vscroll_focus", (3, 2, 3, 2)))
item("VScrollBar/styles/grabber",           flat("vgrab", "#3d3b36", radius=3, margins=(3, 3, 3, 3)))
item("VScrollBar/styles/grabber_highlight", flat("vgrab_hi", "#4f4c46", radius=3, margins=(3, 3, 3, 3)))
item("VScrollBar/styles/grabber_pressed",   flat("vgrab_press", "#5d5a52", radius=3, margins=(3, 3, 3, 3)))
item("HScrollBar/styles/scroll",       empty("hscroll_bg", (2, 3, 2, 3)))
item("HScrollBar/styles/scroll_focus", empty("hscroll_focus", (2, 3, 2, 3)))
item("HScrollBar/styles/grabber",           'SubResource("vgrab")')
item("HScrollBar/styles/grabber_highlight", 'SubResource("vgrab_hi")')
item("HScrollBar/styles/grabber_pressed",   'SubResource("vgrab_press")')

# ---- Separators / splits --------------------------------------------------
item("HSeparator/styles/separator", line("hsep", BORDER))
item("HSeparator/constants/separation", 1)
item("VSeparator/styles/separator", line("vsep", BORDER, vertical=True))
item("VSeparator/constants/separation", 1)
item("SplitContainer/constants/separation", 1)
item("SplitContainer/constants/minimum_grab_thickness", 8)
item("SplitContainer/constants/autohide", 1)
item("SplitContainer/styles/split_bar_background", empty("split_bg"))

# ---- RichTextLabel (console) ----------------------------------------------
item("RichTextLabel/styles/normal", empty("rtl_normal", (14, 10, 14, 10)))
item("RichTextLabel/styles/focus",  empty("rtl_focus", (14, 10, 14, 10)))
item("RichTextLabel/colors/default_color", col(TEXT))
item("RichTextLabel/colors/selection_color", col(ACCENT, 0.35))
item("RichTextLabel/colors/font_selected_color", col(TEXT))
item("RichTextLabel/fonts/normal_font", MONO)
item("RichTextLabel/fonts/bold_font", MONO)
item("RichTextLabel/fonts/italics_font", MONO)
item("RichTextLabel/fonts/bold_italics_font", MONO)
item("RichTextLabel/fonts/mono_font", MONO)
item("RichTextLabel/font_sizes/normal_font_size", 12)
item("RichTextLabel/font_sizes/bold_font_size", 12)
item("RichTextLabel/font_sizes/italics_font_size", 12)
item("RichTextLabel/font_sizes/bold_italics_font_size", 12)
item("RichTextLabel/font_sizes/mono_font_size", 12)
item("RichTextLabel/constants/line_separation", 4)

# ---- Popups / tooltips ----------------------------------------------------
item("PopupMenu/styles/panel", flat("popup_panel", BG_POPUP, border=BORDER_STRONG, bw=1, radius=8,
                                    margins=(6, 6, 6, 6), shadow=(12, 0.4, 4)))
item("PopupMenu/styles/hover", flat("popup_hover", "#34332f", radius=6))
item("PopupMenu/styles/separator", line("popup_sep", BORDER))
item("PopupMenu/colors/font_color", col(TEXT))
item("PopupMenu/colors/font_hover_color", col(TEXT))
item("PopupMenu/colors/font_disabled_color", col(TEXT_MUTED))
item("PopupMenu/colors/font_accelerator_color", col(TEXT_MUTED))
item("PopupMenu/colors/font_separator_color", col(TEXT_MUTED))
item("PopupMenu/constants/v_separation", 4)
item("PopupMenu/constants/h_separation", 8)
item("PopupMenu/constants/item_start_padding", 10)
item("PopupMenu/constants/item_end_padding", 10)
item("PopupMenu/font_sizes/font_size", 13)
item("PopupPanel/styles/panel", 'SubResource("popup_panel")')
item("TooltipPanel/styles/panel", flat("tooltip", "#2a2927", border=BORDER_STRONG, bw=1, radius=6,
                                       margins=(10, 6, 10, 6), shadow=(8, 0.35, 2)))
item("TooltipLabel/colors/font_color", col(TEXT))
item("TooltipLabel/font_sizes/font_size", 12)

# ---- emit -----------------------------------------------------------------
ext = [
    ('1_ui', 'SystemFont', 'res://public/fonts/ui_font.tres', 'uid://c5k2fq7t8yv1a'),
    ('2_semibold', 'SystemFont', 'res://public/fonts/ui_font_semibold.tres', 'uid://dq3m8w2xr6n4b'),
    ('3_mono', 'SystemFont', 'res://public/fonts/mono_font.tres', 'uid://bx7p4h1kd2s3c'),
]
lines = [f'[gd_resource type="Theme" load_steps={len(ext) + len(subs) + 1} format=3 uid="{THEME_UID}"]', ""]
for eid, etype, path, uid in ext:
    lines.append(f'[ext_resource type="{etype}" uid="{uid}" path="{path}" id="{eid}"]')
lines.append("")
for sid, stype, props in subs:
    lines.append(f'[sub_resource type="{stype}" id="{sid}"]')
    for k, v in props.items():
        lines.append(f"{k} = {v}")
    lines.append("")
lines.append("[resource]")
lines.append(f"default_font = {UI}")
lines.append("default_font_size = 14")
for k, v in T.items():
    lines.append(f"{k} = {v}")
lines.append("")
with open(OUT, "w") as f:
    f.write("\n".join(lines))
print(f"wrote {OUT}: {len(subs)} styleboxes, {len(T)} theme items")
