#!/bin/bash

# Instalar entorno básico funcional en Gentoo
# SOLO lo esencial: Sway + Firefox + File Manager
USUARIO="usuario"

echo "==================================="
echo "INSTALACIÓN BÁSICA FUNCIONAL"
echo "==================================="

# 1. Configurar Portage
echo ">>> Configurando Portage..."
mkdir -p /etc/portage/package.accept_keywords
mkdir -p /etc/portage/package.use

echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf

# Keywords mínimos
cat > /etc/portage/package.accept_keywords/basico << 'EOF'
gui-wm/sway **
gui-libs/wlroots **
x11-terms/foot **
www-client/firefox-bin **
x11-misc/pcmanfm **
EOF

# USE flags mínimos
cat > /etc/portage/package.use/basico << 'EOF'
gui-wm/sway X
gui-libs/wlroots x11-backend
media-libs/mesa wayland
EOF

# 2. Sync
echo ">>> Sincronizando..."
emerge --sync

# 3. Instalar SOLO lo esencial
echo ""
echo ">>> Instalando Sway..."
emerge -qv gui-wm/sway || { echo "ERROR instalando Sway"; exit 1; }

echo ""
echo ">>> Instalando terminal..."
emerge -qv x11-terms/foot || { echo "ERROR instalando foot"; exit 1; }

echo ""
echo ">>> Instalando Firefox BINARIO (sin compilar)..."
emerge -qv www-client/firefox-bin || { echo "ERROR instalando Firefox"; exit 1; }

echo ""
echo ">>> Instalando gestor archivos..."
emerge -qv x11-misc/pcmanfm || { echo "ERROR instalando PCManFM"; exit 1; }

# 4. Configurar usuario
echo ""
echo ">>> Configurando usuario..."
usermod -a -G video,input,seat $USUARIO
systemctl enable systemd-logind
systemctl start systemd-logind
mkdir -p /run/user/1000
chown $USUARIO:$USUARIO /run/user/1000
chmod 700 /run/user/1000

# 5. Configuración MÍNIMA Sway
echo ""
echo ">>> Configurando Sway..."
mkdir -p /home/$USUARIO/.config/sway

cat > /home/$USUARIO/.config/sway/config << 'EOF'
# Sway básico funcional
set $mod Mod4
set $term foot

# Aplicaciones
bindsym $mod+Return exec foot
bindsym $mod+w exec firefox
bindsym $mod+e exec pcmanfm
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exit

# Teclado
input "type:keyboard" {
    xkb_layout "es"
}

# Movimiento
bindsym $mod+Left focus left
bindsym $mod+Right focus right
bindsym $mod+Up focus up
bindsym $mod+Down focus down

# Workspaces
bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3

# Fullscreen
bindsym $mod+f fullscreen

# Barra simple
bar {
    position bottom
    status_command while date +'%H:%M'; do sleep 60; done
}
EOF

chown -R $USUARIO:$USUARIO /home/$USUARIO/.config

# 6. Variables de entorno
cat > /home/$USUARIO/.bash_profile << 'EOF'
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec sway
fi
EOF
chown $USUARIO:$USUARIO /home/$USUARIO/.bash_profile

# 7. Autologin
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USUARIO --noclear %I \$TERM
Type=idle
EOF
systemctl daemon-reload

echo ""
echo "==================================="
echo "✓ INSTALACIÓN BÁSICA COMPLETA"
echo "==================================="
echo ""
echo "Instalado:"
echo "  ✓ Sway (compositor)"
echo "  ✓ foot (terminal)"
echo "  ✓ Firefox (navegador)"
echo "  ✓ PCManFM (archivos)"
echo ""
echo "ATAJOS:"
echo "  SUPER + ENTER = Terminal"
echo "  SUPER + W = Firefox"
echo "  SUPER + E = Archivos"
echo "  SUPER + SHIFT + Q = Cerrar ventana"
echo "  SUPER + SHIFT + E = Salir"
echo ""
echo "REINICIA:"
echo "  reboot"
echo "==================================="
