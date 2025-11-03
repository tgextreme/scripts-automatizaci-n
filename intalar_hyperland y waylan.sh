#!/bin/bash

# Instalar Hyprland y Wayland en Gentoo
# Copia y pega estos comandos uno por uno en tu terminal

# Configurar ACCEPT_KEYWORDS para paquetes ~amd64
echo "gui-wm/hyprland ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "gui-libs/xdg-desktop-portal-hyprland ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "dev-libs/hyprlang ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "dev-libs/hyprutils ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "dev-libs/hyprwayland-scanner ~amd64" >> /etc/portage/package.accept_keywords/hyprland

# Aceptar licencias
echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf

# Actualizar repositorio
emerge --sync

# Instalar dependencias de Wayland
emerge -av dev-libs/wayland dev-libs/wayland-protocols

# Instalar mesa con soporte Wayland
echo "media-libs/mesa wayland" >> /etc/portage/package.use/mesa
emerge -av media-libs/mesa

# Instalar compositor Hyprland y utilidades Wayland básicas
emerge -av gui-wm/hyprland

# Instalar terminal Wayland (kitty o alacritty)
emerge -av x11-terms/kitty

# Instalar launcher (wofi o rofi-wayland)
emerge -av gui-apps/wofi

# Instalar gestor de notificaciones
emerge -av gui-apps/mako

# Instalar bar (waybar)
emerge -av gui-apps/waybar

# Instalar herramientas útiles
emerge -av gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard

# Crear configuración básica de Hyprland
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF'
monitor=,preferred,auto,1

exec-once = waybar
exec-once = mako

input {
    kb_layout = es
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

$mainMod = SUPER

bind = $mainMod, RETURN, exec, kitty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,

bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
EOF

echo "Instalación completada. Reinicia y ejecuta 'Hyprland' para iniciar"
