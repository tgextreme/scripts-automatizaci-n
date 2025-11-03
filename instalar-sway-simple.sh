#!/bin/bash

# Script para instalar Sway REALMENTE en Gentoo
# Ejecutar como ROOT

echo "========================================="
echo "INSTALACIÓN REAL DE SWAY"
echo "========================================="

# 1. Configurar Portage primero
echo ""
echo ">>> Configurando Portage..."
mkdir -p /etc/portage/package.accept_keywords
mkdir -p /etc/portage/package.use

# Aceptar todas las licencias
if ! grep -q 'ACCEPT_LICENSE="\*"' /etc/portage/make.conf; then
    echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
fi

# Keywords para Sway y dependencias
cat > /etc/portage/package.accept_keywords/sway << 'EOF'
gui-wm/sway **
gui-libs/wlroots **
dev-libs/wayland **
dev-libs/wayland-protocols **
x11-libs/cairo **
x11-libs/pango **
x11-libs/gdk-pixbuf **
gui-libs/gtk **
x11-terms/foot **
EOF

# USE flags necesarios
cat > /etc/portage/package.use/sway << 'EOF'
gui-wm/sway X man
gui-libs/wlroots x11-backend
dev-libs/wayland abi_x86_32
x11-libs/cairo X
x11-libs/pango X
media-libs/mesa wayland
EOF

# 2. Sync
echo ""
echo ">>> Sincronizando Portage..."
emerge --sync

# 3. Instalar dependencias básicas primero
echo ""
echo ">>> Instalando dependencias de Wayland..."
emerge -v dev-libs/wayland dev-libs/wayland-protocols

# 4. Instalar wlroots (biblioteca de Sway)
echo ""
echo ">>> Instalando wlroots..."
emerge -v gui-libs/wlroots

# 5. Instalar Sway
echo ""
echo ">>> Instalando Sway..."
emerge -v gui-wm/sway

# 6. Instalar terminal
echo ""
echo ">>> Instalando terminal foot..."
emerge -v x11-terms/foot

# 7. Verificar instalación
echo ""
echo ">>> Verificando instalación..."
if command -v sway &> /dev/null; then
    echo "✓ Sway instalado correctamente en: $(which sway)"
    sway --version
else
    echo "✗ ERROR: Sway NO se instaló"
    exit 1
fi

if command -v foot &> /dev/null; then
    echo "✓ foot instalado correctamente en: $(which foot)"
else
    echo "✗ ADVERTENCIA: foot no se instaló"
fi

# 8. Configurar usuario
USUARIO="usuario"
echo ""
echo ">>> Configurando usuario y grupos..."
usermod -a -G video,input,seat $USUARIO

# 9. Habilitar systemd-logind
echo ""
echo ">>> Habilitando systemd-logind..."
systemctl enable systemd-logind
systemctl start systemd-logind

# 10. Crear XDG_RUNTIME_DIR
echo ""
echo ">>> Creando XDG_RUNTIME_DIR..."
mkdir -p /run/user/1000
chown $USUARIO:$USUARIO /run/user/1000
chmod 700 /run/user/1000

# 11. Configuración mínima de Sway
echo ""
echo ">>> Creando configuración mínima de Sway..."
mkdir -p /home/$USUARIO/.config/sway

cat > /home/$USUARIO/.config/sway/config << 'EOFCONFIG'
# Configuración mínima de Sway
set $mod Mod4
set $term foot

# Atajos básicos
bindsym $mod+Return exec $term
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exit

# Teclado español
input "type:keyboard" {
    xkb_layout "es"
}

# Fondo
output * bg #1a1a1a solid_color

# Barra simple
bar {
    position bottom
    status_command while date +'%H:%M:%S'; do sleep 1; done
}
EOFCONFIG

chown -R $USUARIO:$USUARIO /home/$USUARIO/.config

# 12. Configurar .bash_profile
cat > /home/$USUARIO/.bash_profile << 'EOFPROFILE'
# Variables Wayland
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1

# Iniciar Sway en tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec sway
fi
EOFPROFILE

chown $USUARIO:$USUARIO /home/$USUARIO/.bash_profile

# 13. Configurar autologin
echo ""
echo ">>> Configurando autologin..."
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
echo "✓ SWAY INSTALADO CORRECTAMENTE"
echo "========================================="
echo ""
echo "Sway está en: $(which sway)"
echo "Versión: $(sway --version)"
echo ""
echo "PARA INICIAR:"
echo ""
echo "1. Reiniciar (autologin):"
echo "   reboot"
echo ""
echo "2. O iniciar manualmente:"
echo "   su - usuario"
echo "   sway"
echo ""
echo "ATAJOS:"
echo "  SUPER + ENTER = Terminal"
echo "  SUPER + SHIFT + Q = Cerrar ventana"
echo "  SUPER + SHIFT + E = Salir"
echo "========================================="
