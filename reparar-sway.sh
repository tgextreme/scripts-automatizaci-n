#!/bin/bash

# Script de REPARACIÓN Y REINSTALACIÓN COMPLETA de Sway
# Ejecutar como ROOT
USUARIO="usuario"

echo "========================================="
echo "REPARACIÓN COMPLETA DE SWAY"
echo "========================================="

# 1. Detener todo lo que pueda estar corriendo
echo ""
echo ">>> Deteniendo procesos X11 y Wayland..."
killall -9 sway waybar mako foot firefox Xorg xinit startx 2>/dev/null
systemctl stop lightdm sddm lxdm gdm 2>/dev/null
systemctl disable lightdm sddm lxdm gdm 2>/dev/null

# Limpiar sesiones viejas
pkill -u $USUARIO 2>/dev/null

# 2. Verificar e instalar paquetes básicos
echo ""
echo ">>> Verificando instalación de paquetes..."

# Instalar Sway si falta
if ! command -v sway &> /dev/null; then
    echo "Instalando Sway..."
    emerge -q gui-wm/sway
fi

# Instalar Waybar si falta
if ! command -v waybar &> /dev/null; then
    echo "Instalando Waybar..."
    emerge -q gui-apps/waybar
fi

# Instalar terminal si falta
if ! command -v foot &> /dev/null; then
    echo "Instalando foot terminal..."
    emerge -q x11-terms/foot
fi

# Instalar wofi si falta
if ! command -v wofi &> /dev/null; then
    echo "Instalando wofi..."
    emerge -q gui-apps/wofi
fi

# 3. Habilitar servicio systemd para crear XDG_RUNTIME_DIR
echo ""
echo ">>> Habilitando servicio systemd para XDG_RUNTIME_DIR..."
# Crear el directorio temporal
mkdir -p /run/user/$(id -u $USUARIO)
chown $USUARIO:$USUARIO /run/user/$(id -u $USUARIO)
chmod 700 /run/user/$(id -u $USUARIO)

# Habilitar logind para que cree el directorio automáticamente
systemctl enable systemd-logind
systemctl start systemd-logind

# Verificar que se creó
if [ ! -d "/run/user/$(id -u $USUARIO)" ]; then
    echo "⚠ Creando manualmente /run/user/$(id -u $USUARIO)..."
    mkdir -p /run/user/$(id -u $USUARIO)
    chown $USUARIO:$USUARIO /run/user/$(id -u $USUARIO)
    chmod 700 /run/user/$(id -u $USUARIO)
fi

# 4. Recrear configuración COMPLETA de Sway (SIMPLIFICADA)
echo ""
echo ">>> Recreando configuración de Sway (versión simple)..."
mkdir -p /home/$USUARIO/.config/sway

cat > /home/$USUARIO/.config/sway/config << 'EOF'
# Sway config - VERSIÓN SIMPLE PARA VIRTUALBOX

# Tecla modificadora (Windows key)
set $mod Mod4

# Terminal y launcher
set $term foot
set $menu wofi --show drun

# Fondo
output * bg #2E3440 solid_color

# Teclado español
input "type:keyboard" {
    xkb_layout "es"
}

# ATAJOS BÁSICOS
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exit
bindsym $mod+Shift+c reload

# Movimiento entre ventanas
bindsym $mod+Left focus left
bindsym $mod+Right focus right
bindsym $mod+Up focus up
bindsym $mod+Down focus down

# Mover ventanas
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Right move right
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Down move down

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5

# Pantalla completa
bindsym $mod+f fullscreen

# Floating
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Mouse
floating_modifier $mod normal

# Bordes simples
default_border pixel 2
default_floating_border pixel 2

# Barra inferior (WAYBAR)
bar {
    position bottom
    status_command while date +'%Y-%m-%d %H:%M:%S'; do sleep 1; done
    
    colors {
        statusline #ffffff
        background #323232
        inactive_workspace #32323200 #32323200 #5c5c5c
    }
}

# Autostart waybar (comentado por ahora para probar)
# exec waybar
EOF

# 5. Configurar permisos
echo ""
echo ">>> Configurando permisos..."
chown -R $USUARIO:$USUARIO /home/$USUARIO/.config
chmod -R 755 /home/$USUARIO/.config

# 6. Asegurar grupos del usuario
echo ""
echo ">>> Configurando grupos del usuario..."
usermod -a -G video,audio,input,seat $USUARIO

# 7. Variables de entorno
echo ""
echo ">>> Configurando variables de entorno..."

cat > /home/$USUARIO/.bash_profile << 'EOF'
# Variables para Wayland en VirtualBox
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1
export WLR_BACKENDS=headless,libinput

# Crear XDG_RUNTIME_DIR si no existe
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    sudo mkdir -p "$XDG_RUNTIME_DIR"
    sudo chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR"
    sudo chmod 700 "$XDG_RUNTIME_DIR"
fi

# Iniciar Sway en tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec sway 2>&1 | tee /home/usuario/sway.log
fi
EOF
chown $USUARIO:$USUARIO /home/$USUARIO/.bash_profile

cat > /home/$USUARIO/.bashrc << 'EOF'
# .bashrc
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER_ALLOW_SOFTWARE=1
EOF
chown $USUARIO:$USUARIO /home/$USUARIO/.bashrc

# 8. Configurar autologin
echo ""
echo ">>> Configurando autologin..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USUARIO --noclear %I \$TERM
Type=idle
EOF

systemctl daemon-reload

# 9. Limpiar archivos viejos
echo ""
echo ">>> Limpiando configuraciones antiguas..."
rm -f /root/.xinitrc /home/$USUARIO/.xinitrc
rm -f /root/.xsession /home/$USUARIO/.xsession
rm -f /root/.Xauthority /home/$USUARIO/.Xauthority

# 10. Dar permisos sudo al usuario para crear XDG_RUNTIME_DIR
echo ""
echo ">>> Configurando sudo para usuario..."
echo "$USUARIO ALL=(ALL) NOPASSWD: /bin/mkdir -p /run/user/*, /bin/chown * /run/user/*, /bin/chmod * /run/user/*" > /etc/sudoers.d/xdg-runtime
chmod 440 /etc/sudoers.d/xdg-runtime

echo ""
echo "========================================="
echo "✓ REPARACIÓN COMPLETA"
echo "========================================="
echo ""
echo "AHORA PRUEBA:"
echo ""
echo "OPCIÓN 1 - Como usuario (RECOMENDADO):"
echo "  su - usuario"
echo "  sway"
echo ""
echo "OPCIÓN 2 - Reiniciar para autologin:"
echo "  reboot"
echo ""
echo "========================================="
echo "ATAJOS EN SWAY:"
echo "  SUPER + ENTER     = Terminal"
echo "  SUPER + D         = Menú aplicaciones"
echo "  SUPER + SHIFT + Q = Cerrar ventana"
echo "  SUPER + SHIFT + E = Salir"
echo "========================================="
echo ""
echo "Si sigue sin funcionar, ejecuta:"
echo "  bash diagnostico-sway.sh"
echo "Y comparte la salida"
echo "========================================="
