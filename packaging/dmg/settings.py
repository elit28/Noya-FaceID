# Réglages de dmgbuild pour l'image disque de NOYA Face (fenêtre d'installation).
# Utilisé par scripts/build-dmg.sh ; les valeurs « defines » viennent de la ligne de commande.
import os.path

app = defines.get("app", "dist/NOYA Face.app")  # noqa: F821 (fourni par dmgbuild)
app_name = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines.get("icon")  # noqa: F821 — icône du volume
background = defines.get("background")  # noqa: F821 — TIFF multi-résolution (660 × 400 et Retina)

# Fenêtre : taille du fond, sans barre d'outils, d'état, de chemin ni latérale.
window_rect = ((200, 140), (660, 400))
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0
default_view = "icon-view"
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False

# Icônes : 128 pt, alignées sur la flèche du fond.
arrange_by = None
icon_size = 128
text_size = 13
label_pos = "bottom"
icon_locations = {
    app_name: (170, 190),
    "Applications": (490, 190),
}
