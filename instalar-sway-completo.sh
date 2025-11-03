#!/bin/bash

# Script para instalar SWAY COMPLETO con entorno de usuario normal
# Parecido a GNOME/KDE pero más ligero
# Ejecutar como ROOT

USUARIO="usuario"

echo "========================================="
echo "INSTALACIÓN DE SWAY COMPLETO"
echo "Entorno gráfico moderno y funcional"
echo "========================================="

# 1. Configurar Portage
echo ""
echo ">>> Configurando Portage..."
mkdir -p /etc/portage/package.accept_keywords
mkdir -p /etc/portage/package.use

if ! grep -q 'ACCEPT_LICENSE="\*"' /etc/portage/make.conf; then
    echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
fi

# Keywords para TODO
cat > /etc/portage/package.accept_keywords/sway-full << 'EOF'
# Sway y compositor
gui-wm/sway **
gui-libs/wlroots **
dev-libs/wayland **
dev-libs/wayland-protocols **

# Barra y herramientas visuales
gui-apps/waybar **
gui-apps/wofi **
gui-apps/mako **
gui-apps/swaylock **
gui-apps/swaybg **
gui-apps/swayidle **

# Terminal y utilidades
x11-terms/foot **
gui-apps/grim **
gui-apps/slurp **
gui-apps/wl-clipboard **

# Navegador y aplicaciones
www-client/firefox **

# File manager y GTK
x11-misc/pcmanfm **
x11-libs/gtk+ **

# Iconos y temas
x11-themes/adwaita-icon-theme **
x11-themes/gnome-themes-standard **

# Fonts
media-fonts/fontawesome **
media-fonts/noto **
media-fonts/noto-emoji **

# Audio
media-sound/pulseaudio **
media-sound/pavucontrol **

# Visor de imágenes
media-gfx/imv **

# Editor de texto
app-editors/mousepad **
EOF

# USE flags
cat > /etc/portage/package.use/sway-full << 'EOF'
gui-wm/sway X man tray
gui-libs/wlroots x11-backend
gui-apps/waybar pulseaudio network tray
dev-libs/wayland abi_x86_32
media-libs/mesa wayland gles2
www-client/firefox wayland pulseaudio
media-sound/pulseaudio gtk bluetooth
x11-misc/pcmanfm gtk3
EOF

echo ""
echo ">>> Sincronizando Portage (puede tardar)..."
emerge --sync

# 2. Instalar SWAY
echo ""
echo ">>> Instalando Sway y compositor..."
emerge -v gui-wm/sway gui-libs/wlroots

# 3. Instalar WAYBAR (barra superior bonita)
echo ""
echo ">>> Instalando Waybar (barra de tareas)..."
emerge -v gui-apps/waybar

# 4. Instalar WOFI (menú de aplicaciones)
echo ""
echo ">>> Instalando Wofi (menú aplicaciones)..."
emerge -v gui-apps/wofi

# 5. Instalar MAKO (notificaciones)
echo ""
echo ">>> Instalando Mako (notificaciones)..."
emerge -v gui-apps/mako

# 6. Instalar TERMINAL
echo ""
echo ">>> Instalando terminal..."
emerge -v x11-terms/foot

# 7. Instalar FIREFOX
echo ""
echo ">>> Instalando Firefox..."
emerge -v www-client/firefox

# 8. Instalar FILE MANAGER
echo ""
echo ">>> Instalando gestor de archivos..."
emerge -v x11-misc/pcmanfm

# 9. Instalar AUDIO
echo ""
echo ">>> Instalando PulseAudio..."
emerge -v media-sound/pulseaudio media-sound/pavucontrol

# 10. Instalar FUENTES
echo ""
echo ">>> Instalando fuentes bonitas..."
emerge -v media-fonts/fontawesome media-fonts/noto media-fonts/noto-emoji

# 11. Instalar ICONOS Y TEMAS
echo ""
echo ">>> Instalando iconos y temas..."
emerge -v x11-themes/adwaita-icon-theme

# 12. Instalar UTILIDADES
echo ""
echo ">>> Instalando utilidades (capturas, clipboard)..."
emerge -v gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard

# 13. Instalar visor de imágenes y editor
echo ""
echo ">>> Instalando aplicaciones extras..."
emerge -v media-gfx/imv app-editors/mousepad

# 14. Configurar usuario
echo ""
echo ">>> Configurando usuario..."
usermod -a -G video,audio,input,seat,wheel $USUARIO

# 15. Habilitar servicios
echo ""
echo ">>> Habilitando servicios..."
systemctl enable systemd-logind
systemctl start systemd-logind

# 16. Crear XDG_RUNTIME_DIR
mkdir -p /run/user/1000
chown $USUARIO:$USUARIO /run/user/1000
chmod 700 /run/user/1000

# 17. Configuración COMPLETA de Sway
echo ""
echo ">>> Creando configuración completa de Sway..."
mkdir -p /home/$USUARIO/.config/sway

cat > /home/$USUARIO/.config/sway/config << 'EOFCONFIG'
# Configuración COMPLETA de Sway - Entorno moderno

# Tecla SUPER (Windows)
set $mod Mod4

# Aplicaciones
set $term foot
set $menu wofi --show drun --allow-images --prompt "Buscar aplicaciones"
set $browser firefox
set $filemanager pcmanfm

# Autostart
exec waybar
exec mako
exec pulseaudio --start

# Fondo bonito (color degradado simulado)
output * bg #2E3440 solid_color

# Teclado español
input "type:keyboard" {
    xkb_layout "es"
}

# Touchpad (si existe)
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
}

### ATAJOS DE TECLADO ###

# Aplicaciones básicas
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+w exec $browser
bindsym $mod+e exec $filemanager
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exec swaynag -t warning -m '¿Salir de Sway?' -B 'Sí' 'swaymsg exit'
bindsym $mod+Shift+c reload

# Capturas de pantalla
bindsym Print exec grim -g "$(slurp)" ~/captura-$(date +%Y%m%d-%H%M%S).png && notify-send "Captura guardada"
bindsym $mod+Print exec grim ~/captura-completa-$(date +%Y%m%d-%H%M%S).png && notify-send "Captura completa"

# Control de volumen
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym $mod+F12 exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym $mod+F11 exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym $mod+F10 exec pactl set-sink-mute @DEFAULT_SINK@ toggle

# Movimiento entre ventanas
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Mover ventanas
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Workspaces (escritorios virtuales)
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

# Layouts
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Modo redimensionar
mode "resize" {
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px
    
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Mouse
floating_modifier $mod normal

# Bordes bonitos
default_border pixel 3
default_floating_border pixel 3
gaps inner 8
gaps outer 4

# Colores (tema Nord)
client.focused          #88C0D0 #434C5E #ECEFF4 #88C0D0 #88C0D0
client.focused_inactive #4C566A #2E3440 #D8DEE9 #4C566A #4C566A
client.unfocused        #4C566A #2E3440 #D8DEE9 #4C566A #4C566A
client.urgent           #BF616A #BF616A #ECEFF4 #BF616A #BF616A

# NO usar barra integrada (usamos Waybar)
bar {
    swaybar_command waybar
}
EOFCONFIG

# 18. Configurar WAYBAR (barra superior bonita)
mkdir -p /home/$USUARIO/.config/waybar

cat > /home/$USUARIO/.config/waybar/config << 'EOFWAYBAR'
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "spacing": 8,
    
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "cpu", "memory", "tray"],
    
    "sway/workspaces": {
        "format": "{index}"
    },
    
    "clock": {
        "format": "  {:%H:%M:%S}",
        "format-alt": "  {:%d/%m/%Y %H:%M}",
        "interval": 1,
        "tooltip-format": "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>"
    },
    
    "cpu": {
        "format": "  {usage}%",
        "interval": 2
    },
    
    "memory": {
        "format": "  {used:0.1f}G"
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "  Mute",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    
    "tray": {
        "spacing": 10
    }
}
EOFWAYBAR

cat > /home/$USUARIO/.config/waybar/style.css << 'EOFWAYBARCSS'
* {
    font-family: "Noto Sans", "FontAwesome", sans-serif;
    font-size: 13px;
    border: none;
    border-radius: 0;
}

window#waybar {
    background-color: rgba(46, 52, 64, 0.95);
    color: #ECEFF4;
    border-bottom: 3px solid #88C0D0;
}

#workspaces button {
    padding: 0 10px;
    color: #D8DEE9;
    background-color: transparent;
    border-bottom: 3px solid transparent;
}

#workspaces button:hover {
    background-color: rgba(136, 192, 208, 0.2);
}

#workspaces button.focused {
    background-color: rgba(136, 192, 208, 0.3);
    border-bottom: 3px solid #88C0D0;
}

#clock {
    padding: 0 15px;
    color: #88C0D0;
    font-weight: bold;
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

#tray {
    padding: 0 10px;
}
EOFWAYBARCSS

# 19. Configurar Wofi (menú aplicaciones)
mkdir -p /home/$USUARIO/.config/wofi
cat > /home/$USUARIO/.config/wofi/style.css << 'EOFWOFI'
window {
    background-color: rgba(46, 52, 64, 0.98);
    border: 3px solid #88C0D0;
    border-radius: 10px;
    font-family: "Noto Sans";
}

#input {
    margin: 10px;
    padding: 10px;
    background-color: #3B4252;
    color: #ECEFF4;
    border: 2px solid #88C0D0;
    border-radius: 5px;
}

#entry:selected {
    background-color: #88C0D0;
    color: #2E3440;
}
EOFWOFI

# 20. Configurar Mako (notificaciones)
mkdir -p /home/$USUARIO/.config/mako
cat > /home/$USUARIO/.config/mako/config << 'EOFMAKO'
font=Noto Sans 11
background-color=#2E3440DD
text-color=#ECEFF4
border-color=#88C0D0
border-size=3
border-radius=10
padding=15
default-timeout=5000
EOFMAKO

# 21. Tema GTK
mkdir -p /home/$USUARIO/.config/gtk-3.0
cat > /home/$USUARIO/.config/gtk-3.0/settings.ini << 'EOFGTK'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=1
EOFGTK

# 22. Permisos
chown -R $USUARIO:$USUARIO /home/$USUARIO/.config

# 23. Variables de entorno
cat > /home/$USUARIO/.bash_profile << 'EOFPROFILE'
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1
export MOZ_ENABLE_WAYLAND=1

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec sway
fi
EOFPROFILE
chown $USUARIO:$USUARIO /home/$USUARIO/.bash_profile

# 24. Autologin
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOFAUTOLOGIN
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USUARIO --noclear %I \$TERM
Type=idle
EOFAUTOLOGIN
systemctl daemon-reload

echo ""
echo "========================================="
echo "✓ SWAY COMPLETO INSTALADO"
echo "========================================="
echo ""
echo "CARACTERÍSTICAS:"
echo "✓ Barra superior Waybar (reloj, CPU, RAM, volumen)"
echo "✓ Firefox navegador"
echo "✓ PCManFM gestor de archivos"
echo "✓ Menú Wofi con iconos"
echo "✓ Notificaciones Mako"
echo "✓ Control de volumen PulseAudio"
echo "✓ Tema oscuro Nord"
echo "✓ Fuentes Noto + iconos"
echo ""
echo "ATAJOS:"
echo "  SUPER + ENTER = Terminal"
echo "  SUPER + D = Menú aplicaciones"
echo "  SUPER + W = Firefox"
echo "  SUPER + E = Gestor archivos"
echo "  SUPER + 1-9 = Cambiar escritorio"
echo "  SUPER + F = Pantalla completa"
echo "  SUPER + R = Redimensionar"
echo "  Print = Captura área"
echo "  SUPER + Print = Captura completa"
echo "  SUPER + F10/F11/F12 = Control volumen"
echo ""
echo "REINICIA PARA APLICAR:"
echo "  reboot"
echo "========================================="
