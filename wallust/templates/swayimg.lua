-- wallust template -> ~/.config/swayimg/colors.lua
-- Generated on every wallpaper change; edit the template, not the output.
-- Colors are 0xAARRGGBB, so alpha goes first (hence the 'strip' filter).
--
-- Mapping (dark16 palette):
--   window/shadow   background
--   text            foreground
--   thumbnails      color0 unselected, color8 selected
--   border          color4 -- same accent as the fuzzel border
--   marks           color6 -- warm accent

swayimg.text.color = 0xff{{foreground | strip}}
swayimg.text.shadow = 0xff{{background | strip}}

swayimg.viewer.set_window_background(0xff{{background | strip}})
swayimg.viewer.mark_color = 0xff{{color6 | strip}}

swayimg.gallery.window_color = 0xff{{background | strip}}
swayimg.gallery.unselected_color = 0xff{{color0 | strip}}
swayimg.gallery.selected_color = 0xff{{color8 | strip}}
swayimg.gallery.border_color = 0xff{{color4 | strip}}
swayimg.gallery.mark_color = 0xff{{color6 | strip}}
