#!/bin/bash

# Script para instalar SWAY (Wayland para VirtualBox) en Gentoo
# Sway funciona en VirtualBox, Hyprland NO
# CAMBIA "usuario" por tu nombre de usuario real
USUARIO="usuario"

echo "==================================="
echo "Instalación de SWAY (compatible VirtualBox)"
echo "==================================="

# Detener y eliminar gestores viejos
systemctl stop lightdm 2>/dev/null
systemctl stop sddm 2>/dev/null
systemctl stop lxdm 2>/dev/null
systemctl disable lightdm 2>/dev/null
systemctl disable sddm 2>/dev/null
systemctl disable lxdm 2>/dev/null
killall -9 lightdm sddm lxdm Xorg 2>/dev/null

# Configuración de Portage
echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
mkdir -p /etc/portage/package.accept_keywords
mkdir -p /etc/portage/package.use

# Aceptar keywords para Sway y Wayland
cat > /etc/portage/package.accept_keywords/sway << 'EOF'
gui-wm/sway **
gui-apps/swaybar **
gui-apps/swaylock **
gui-apps/swaybg **
gui-apps/waybar **
gui-apps/wofi **
gui-apps/mako **
x11-terms/alacritty **
x11-terms/foot **
gui-apps/grim **
gui-apps/slurp **
gui-apps/wl-clipboard **
dev-libs/wayland **
dev-libs/wayland-protocols **
x11-misc/pcmanfm **
www-client/firefox **
media-fonts/fontawesome **
media-fonts/noto **
media-fonts/noto-emoji **
x11-themes/adwaita-icon-theme **
media-sound/pavucontrol **
media-sound/pulseaudio **
EOF

# USE flags para Wayland
cat > /etc/portage/package.use/wayland << 'EOF'
dev-libs/libinput wayland
media-libs/mesa wayland gles2 egl
gui-wm/sway X
media-sound/pulseaudio gtk
www-client/firefox wayland
EOF

# Sincronizar
emerge --sync

# PASO 1: Instalar Wayland básico
echo ">>> Instalando Wayland..."
emerge -q dev-libs/wayland dev-libs/wayland-protocols

# PASO 2: Instalar mesa con soporte Wayland
echo ">>> Instalando Mesa..."
emerge -q media-libs/mesa

# PASO 3: Instalar Sway
echo ">>> Instalando Sway..."
emerge -q gui-wm/sway

# PASO 4: Instalar terminal
echo ">>> Instalando terminal..."
emerge -q x11-terms/foot

# PASO 5: Instalar Waybar
echo ">>> Instalando Waybar..."
emerge -q gui-apps/waybar

# PASO 6: Instalar Wofi
echo ">>> Instalando Wofi..."
emerge -q gui-apps/wofi

# PASO 7: Instalar Mako
echo ">>> Instalando Mako..."
emerge -q gui-apps/mako

# PASO 8: Instalar herramientas
echo ">>> Instalando herramientas..."
emerge -q gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard

# PASO 8b: Instalar aplicaciones para usuario normal
echo ">>> Instalando Firefox, file manager y fonts..."
emerge -q www-client/firefox x11-misc/pcmanfm
emerge -q media-fonts/fontawesome media-fonts/noto media-fonts/noto-emoji
emerge -q x11-themes/adwaita-icon-theme

# PASO 8c: Instalar audio (PulseAudio)
echo ">>> Instalando audio (PulseAudio)..."
emerge -q media-sound/pulseaudio media-sound/pavucontrol

# PASO 9: Configurar usuario
echo ">>> Configurando usuario..."
usermod -a -G video,audio,input,seat $USUARIO

# PASO 10: Crear configuración de Sway
echo ">>> Creando configuración de Sway..."
mkdir -p /home/$USUARIO/.config/sway

cat > /home/$USUARIO/.config/sway/config << 'EOF'
# Configuración de Sway para VirtualBox - Entorno completo

# Variables
set $mod Mod4
set $left h
set $down j
set $up k
set $right l
set $term foot
set $menu wofi --show drun
set $filemanager pcmanfm

# Monitor con fondo degradado bonito
output * bg #2E3440 solid_color

# Autostart
exec waybar
exec mako
exec pulseaudio --start

# Input - Teclado español
input "type:keyboard" {
    xkb_layout "es"
}

# Input - Touchpad (si tienes)
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
}

# Keybindings básicos
bindsym $mod+Return exec $term
bindsym $mod+Shift+q kill
bindsym $mod+d exec $menu
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exit

# Aplicaciones
bindsym $mod+e exec $filemanager
bindsym $mod+w exec firefox

# Capturas de pantalla
bindsym Print exec grim -g "$(slurp)" ~/screenshot-$(date +%Y%m%d-%H%M%S).png && notify-send "Captura guardada" "En tu carpeta home"
bindsym $mod+Print exec grim ~/screenshot-$(date +%Y%m%d-%H%M%S).png && notify-send "Captura completa" "En tu carpeta home"

# Control de volumen
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym $mod+F12 exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym $mod+F11 exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym $mod+F10 exec pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brillo (si funciona)
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

# Movimiento
bindsym $mod+$left focus left
bindsym $mod+$down focus down
bindsym $mod+$up focus up
bindsym $mod+$right focus right

bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Mover ventanas
bindsym $mod+Shift+$left move left
bindsym $mod+Shift+$down move down
bindsym $mod+Shift+$up move up
bindsym $mod+Shift+$right move right

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9

# Layout
bindsym $mod+b splith
bindsym $mod+v splitv
bindsym $mod+s layout stacking
bindsym $mod+t layout tabbed
bindsym $mod+Shift+t layout toggle split
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Mouse
floating_modifier $mod normal

# Redimensionar ventanas
mode "resize" {
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px
    
    bindsym $left resize shrink width 10px
    bindsym $down resize grow height 10px
    bindsym $up resize shrink height 10px
    bindsym $right resize grow width 10px
    
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Bordes bonitos con sombras
default_border pixel 3
default_floating_border pixel 3
gaps inner 10
gaps outer 5

# Colores (Nord theme)
client.focused          #88C0D0 #434C5E #ECEFF4 #88C0D0 #88C0D0
client.focused_inactive #4C566A #2E3440 #D8DEE9 #4C566A #4C566A
client.unfocused        #4C566A #2E3440 #D8DEE9 #4C566A #4C566A
client.urgent           #BF616A #BF616A #ECEFF4 #BF616A #BF616A

# Barra
bar {
    swaybar_command waybar
}
EOF

# PASO 11: Crear configuración de Waybar
mkdir -p /home/$USUARIO/.config/waybar

cat > /home/$USUARIO/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 35,
    "spacing": 5,
    
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "cpu", "memory", "battery", "tray"],
    
    "sway/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "1",
            "2": "2",
            "3": "3",
            "4": "4",
            "5": "5",
            "6": "6",
            "7": "7",
            "8": "8",
            "9": "9",
            "urgent": "",
            "focused": "",
            "default": ""
        }
    },
    
    "clock": {
        "format": " {:%H:%M:%S}",
        "format-alt": " {:%d/%m/%Y - %H:%M:%S}",
        "interval": 1,
        "tooltip-format": "<big>{:%B %Y}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "cpu": {
        "format": " {usage}%",
        "interval": 2,
        "tooltip": true
    },
    
    "memory": {
        "format": " {used:0.1f}G/{total:0.1f}G",
        "interval": 2,
        "tooltip": true
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": " {volume}%",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol",
        "tooltip-format": "Volumen: {volume}%"
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    
    "tray": {
        "spacing": 10
    }
}
EOF

cat > /home/$USUARIO/.config/waybar/style.css << 'EOF'
* {
    font-family: "Noto Sans", "FontAwesome", monospace;
    font-size: 14px;
    border: none;
    border-radius: 0;
}

window#waybar {
    background-color: rgba(46, 52, 64, 0.95);
    color: #ECEFF4;
    border-bottom: 3px solid #88C0D0;
}

#workspaces button {
    padding: 0 12px;
    color: #D8DEE9;
    background-color: transparent;
    border-bottom: 3px solid transparent;
    transition: all 0.3s ease;
}

#workspaces button:hover {
    background-color: rgba(136, 192, 208, 0.2);
    color: #ECEFF4;
}

#workspaces button.focused {
    background-color: rgba(136, 192, 208, 0.3);
    color: #ECEFF4;
    border-bottom: 3px solid #88C0D0;
}

#workspaces button.urgent {
    background-color: #BF616A;
    color: #ECEFF4;
}

#mode {
    padding: 0 10px;
    background-color: #EBCB8B;
    color: #2E3440;
    font-weight: bold;
}

#clock {
    padding: 0 15px;
    color: #88C0D0;
    font-weight: bold;
    font-size: 15px;
}

#cpu {
    padding: 0 12px;
    color: #A3BE8C;
}

#memory {
    padding: 0 12px;
    color: #B48EAD;
}

#pulseaudio {
    padding: 0 12px;
    color: #EBCB8B;
}

#pulseaudio.muted {
    color: #BF616A;
}

#battery {
    padding: 0 12px;
    color: #8FBCBB;
}

#battery.charging {
    color: #A3BE8C;
}

#battery.warning:not(.charging) {
    color: #EBCB8B;
}

#battery.critical:not(.charging) {
    color: #BF616A;
    animation: blink 1s linear infinite;
}

#tray {
    padding: 0 10px;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
    background-color: #BF616A;
}

@keyframes blink {
    50% {
        opacity: 0.5;
    }
}

tooltip {
    background-color: rgba(46, 52, 64, 0.98);
    color: #ECEFF4;
    border: 2px solid #88C0D0;
    border-radius: 8px;
    padding: 10px;
}

tooltip label {
    color: #ECEFF4;
}
EOF

# PASO 12: Limpiar configuraciones viejas de X11
echo ">>> Limpiando configuraciones antiguas de X11..."
rm -f /root/.xinitrc /root/.Xresources /root/.xsession
rm -f /home/$USUARIO/.xinitrc /home/$USUARIO/.Xresources /home/$USUARIO/.xsession

# PASO 12b: Configurar GTK theme
echo ">>> Configurando tema GTK..."
mkdir -p /home/$USUARIO/.config/gtk-3.0
cat > /home/$USUARIO/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
EOF

# PASO 12c: Configurar Mako (notificaciones bonitas)
mkdir -p /home/$USUARIO/.config/mako
cat > /home/$USUARIO/.config/mako/config << 'EOF'
font=Noto Sans 11
background-color=#2E3440DD
text-color=#ECEFF4
border-color=#88C0D0
border-size=3
border-radius=10
padding=15
margin=20
default-timeout=5000
icon-path=/usr/share/icons/Adwaita
max-icon-size=64
EOF

# PASO 12d: Configurar Wofi (launcher bonito)
mkdir -p /home/$USUARIO/.config/wofi
cat > /home/$USUARIO/.config/wofi/style.css << 'EOF'
window {
    background-color: rgba(46, 52, 64, 0.95);
    border: 3px solid #88C0D0;
    border-radius: 10px;
    font-family: Noto Sans;
}

#input {
    margin: 10px;
    padding: 10px;
    background-color: #3B4252;
    color: #ECEFF4;
    border: 2px solid #88C0D0;
    border-radius: 5px;
}

#inner-box {
    margin: 10px;
}

#outer-box {
    margin: 10px;
}

#scroll {
    margin: 0px;
}

#text {
    color: #ECEFF4;
    padding: 5px;
}

#entry:selected {
    background-color: #88C0D0;
    color: #2E3440;
    border-radius: 5px;
}

#entry:hover {
    background-color: rgba(136, 192, 208, 0.3);
    border-radius: 5px;
}
EOF

# PASO 12e: Configurar permisos
chown -R $USUARIO:$USUARIO /home/$USUARIO/.config
chmod 755 /home/$USUARIO/.config
chmod 1777 /tmp

# PASO 13: Configurar arranque automático de Sway
cat > /home/$USUARIO/.bash_profile << 'EOF'
# Iniciar Sway automáticamente en tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec sway
fi
EOF
chown $USUARIO:$USUARIO /home/$USUARIO/.bash_profile

# PASO 14: Configurar autologin en tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USUARIO --noclear %I \$TERM
Type=idle
EOF

systemctl daemon-reload

# PASO 15: Variables de entorno para Wayland
cat >> /home/$USUARIO/.bashrc << 'EOF'

# Variables para Wayland
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1
EOF
chown $USUARIO:$USUARIO /home/$USUARIO/.bashrc

echo ""
echo "==================================="
echo "✓ SWAY INSTALADO - Entorno Completo"
echo "==================================="
echo ""
echo "PARA INICIAR:"
echo ""
echo "OPCIÓN 1 - Reiniciar (arranca automático):"
echo "  reboot"
echo ""
echo "OPCIÓN 2 - Iniciar ahora manualmente:"
echo "  su - $USUARIO"
echo "  sway"
echo ""
echo "==================================="
echo "ATAJOS DE TECLADO:"
echo "==================================="
echo "Básicos:"
echo "  SUPER + ENTER       = Terminal"
echo "  SUPER + D           = Launcher (menú aplicaciones)"
echo "  SUPER + SHIFT + Q   = Cerrar ventana"
echo "  SUPER + SHIFT + E   = Salir de Sway"
echo ""
echo "Aplicaciones:"
echo "  SUPER + E           = File Manager"
echo "  SUPER + W           = Firefox"
echo ""
echo "Capturas:"
echo "  Print               = Captura área seleccionada"
echo "  SUPER + Print       = Captura pantalla completa"
echo ""
echo "Audio:"
echo "  SUPER + F12/F11/F10 = Subir/Bajar/Mutear volumen"
echo "  Click en icono      = Control de volumen (PulseAudio)"
echo ""
echo "Ventanas:"
echo "  SUPER + 1-9         = Cambiar workspace"
echo "  SUPER + F           = Pantalla completa"
echo "  SUPER + R           = Modo redimensionar"
echo "  SUPER + Flechas     = Mover foco"
echo "  SUPER + SHIFT + Flechas = Mover ventana"
echo ""
echo "==================================="
echo "CARACTERÍSTICAS:"
echo "==================================="
echo "✓ Tema oscuro Nord (bonito)"
echo "✓ Iconos Adwaita"
echo "✓ Bordes con gaps (espacios)"
echo "✓ Notificaciones visuales (Mako)"
echo "✓ Control de volumen en barra"
echo "✓ Firefox con Wayland"
echo "✓ File manager (PCManFM)"
echo "✓ Fuentes Noto + FontAwesome"
echo "✓ Compatible VirtualBox"
echo ""
echo "==================================="
echo "Si hay errores, revisa:"
echo "  journalctl -xe --user"
echo "==================================="



