#!/bin/bash

# Script para instalar gestor de login, Hyprland y aplicaciones básicas en Gentoo
# Copia y pega en tu terminal

# Aceptar todas las licencias y keywords
echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
mkdir -p /etc/portage/package.accept_keywords
echo "gui-wm/hyprland ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "gui-libs/xdg-desktop-portal-hyprland ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "dev-libs/hyprlang ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "dev-libs/hyprutils ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "dev-libs/hyprwayland-scanner ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "gui-apps/waybar ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "gui-apps/wofi ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "gui-apps/mako ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "x11-misc/sddm ~amd64" >> /etc/portage/package.accept_keywords/hyprland
echo "www-client/firefox ~amd64" >> /etc/portage/package.accept_keywords/hyprland

# Actualizar repositorio
emerge --sync

# Instalar gestor de login SDDM
emerge -q gui-libs/display-manager-init x11-misc/sddm

# Habilitar SDDM
systemctl enable sddm.service

# Instalar Wayland y dependencias
mkdir -p /etc/portage/package.use
echo "media-libs/mesa wayland" >> /etc/portage/package.use/mesa
echo "dev-libs/libinput wayland" >> /etc/portage/package.use/libinput
echo "x11-base/xwayland wayland" >> /etc/portage/package.use/xwayland
emerge -q dev-libs/wayland dev-libs/wayland-protocols media-libs/mesa

# Instalar Hyprland (compositor)
emerge -q gui-wm/hyprland

# Instalar terminal
emerge -q x11-terms/kitty

# Instalar Waybar (barra de tareas con reloj)
emerge -q gui-apps/waybar

# Instalar Wofi (launcher de aplicaciones)
emerge -q gui-apps/wofi

# Instalar Mako (notificaciones)
emerge -q gui-apps/mako

# Instalar herramientas de captura y clipboard
emerge -q gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard

# Instalar Firefox
emerge -q www-client/firefox

# Instalar monitor del sistema (htop como alternativa a gnome-system-monitor)
emerge -q sys-process/htop sys-process/btop

# Instalar gestor de archivos
emerge -q xfce-base/thunar

# Instalar fuentes básicas
emerge -q media-fonts/dejavu media-fonts/liberation-fonts media-fonts/noto

# Crear usuario si no existe (cambiar 'usuario' por tu nombre)
NEWUSER="usuario"
useradd -m -G wheel,audio,video,input -s /bin/bash $NEWUSER
echo "$NEWUSER:password" | chpasswd
echo "Recuerda cambiar la contraseña con: passwd $NEWUSER"

# Configurar Hyprland
mkdir -p /home/$NEWUSER/.config/hypr
cat > /home/$NEWUSER/.config/hypr/hyprland.conf << 'EOF'
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
bind = $mainMod, F, exec, firefox
bind = $mainMod, H, exec, kitty htop
bind = $mainMod, B, exec, kitty btop
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
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9

bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
EOF

# Configurar Waybar (barra con reloj y tareas)
mkdir -p /home/$NEWUSER/.config/waybar
cat > /home/$NEWUSER/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "battery", "tray"],
    
    "hyprland/workspaces": {
        "format": "{id}"
    },
    
    "clock": {
        "format": "{:%H:%M:%S  %d/%m/%Y}",
        "interval": 1,
        "tooltip-format": "{:%A, %d de %B de %Y}"
    },
    
    "cpu": {
        "format": "CPU {usage}%",
        "interval": 2
    },
    
    "memory": {
        "format": "RAM {used:0.1f}G/{total:0.1f}G"
    },
    
    "network": {
        "format-wifi": "WiFi {signalStrength}%",
        "format-ethernet": "Eth",
        "format-disconnected": "Sin red"
    },
    
    "pulseaudio": {
        "format": "Vol {volume}%",
        "format-muted": "Mute"
    },
    
    "battery": {
        "format": "Bat {capacity}%"
    }
}
EOF

cat > /home/$NEWUSER/.config/waybar/style.css << 'EOF'
* {
    font-family: "DejaVu Sans", monospace;
    font-size: 13px;
}

window#waybar {
    background-color: rgba(43, 48, 59, 0.9);
    color: #ffffff;
}

#workspaces button {
    padding: 0 10px;
    color: #ffffff;
}

#workspaces button.active {
    background-color: rgba(255, 255, 255, 0.2);
}

#clock, #cpu, #memory, #network, #pulseaudio, #battery {
    padding: 0 10px;
}
EOF

# Configurar permisos
chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.config

# Configurar sesión de Hyprland para SDDM
cat > /usr/share/wayland-sessions/hyprland.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland Compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
EOF

echo ""
echo "==================================="
echo "Instalación completada!"
echo "==================================="
echo "Usuario creado: $NEWUSER"
echo "Contraseña temporal: password"
echo ""
echo "Reinicia el sistema con: reboot"
echo "En el login (SDDM), selecciona Hyprland"
echo ""
echo "Atajos de teclado (SUPER = tecla Windows):"
echo "  SUPER + ENTER = Terminal"
echo "  SUPER + R = Lanzador de aplicaciones"
echo "  SUPER + F = Firefox"
echo "  SUPER + H = Monitor del sistema (htop)"
echo "  SUPER + B = Monitor del sistema (btop)"
echo "  SUPER + E = Gestor de archivos"
echo "  SUPER + Q = Cerrar ventana"
echo "  SUPER + M = Salir de Hyprland"
echo "  SUPER + 1-9 = Cambiar workspace"
echo ""
echo "La barra superior (Waybar) muestra:"
echo "  - Workspaces activos"
echo "  - Reloj con hora y fecha"
echo "  - CPU, RAM, Red, Volumen, Batería"
echo "==================================="
