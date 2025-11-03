#!/bin/bash
set -euo pipefail

### === 0) Comprobaciones iniciales ===
if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
  echo "Este script está preparado para systemd. Aborta."
  exit 1
fi
USR=usuario

echo ">>> 0.1 Asegurando arboles de Portage"
emerge --sync || true

### === 1) Perfil systemd + plasma si existe ===
echo ">>> 1) Seleccionando perfil Plasma + systemd (si está disponible)"
if eselect profile list | grep -q 'plasma.*systemd'; then
  PFNUM=$(eselect profile list | nl -ba | grep 'plasma.*systemd' | awk '{print $1}' | tail -1)
  eselect profile set "${PFNUM}" || true
fi

### === 2) make.conf: USE/VIDEO/INPUT globales (Xorg puro) ===
echo ">>> 2) Configurando USE/VIDEO/INPUT globales"
sed -i '/^USE=/d' /etc/portage/make.conf 2>/dev/null || true
sed -i '/^VIDEO_CARDS=/d' /etc/portage/make.conf 2>/dev/null || true
sed -i '/^INPUT_DEVICES=/d' /etc/portage/make.conf 2>/dev/null || true

cat >> /etc/portage/make.conf <<'EOF'
USE="X xcb systemd pulseaudio alsa udev -elogind -wayland -gtk -gnome qt5 kde plasma widgets"
VIDEO_CARDS="virtualbox modesetting vesa"
INPUT_DEVICES="libinput"
EOF

### === 3) Limpiar archivos corruptos y masks viejos ===
echo ">>> 3) Limpiando archivos corruptos de Portage y paquetes de Sway..."
rm -f /etc/portage/package.accept_keywords/all
rm -f /etc/portage/package.accept_keywords/sway*
rm -f /etc/portage/package.accept_keywords/basico
rm -f /etc/portage/package.use/wayland
rm -f /etc/portage/package.use/sway*
rm -f /etc/portage/package.use/basico
rm -f /etc/portage/package.use/xwayland
rm -f /etc/portage/package.mask/*
rm -rf /etc/portage/package.mask
mkdir -p /etc/portage/package.mask

# Desinstalar paquetes de Sway que causan conflictos
emerge --deselect gui-apps/wofi gui-wm/sway 2>/dev/null || true
emerge --depclean -q 2>/dev/null || true

### === 4) NO bloquear nada (KDE necesita wayland-scanner) ===
echo ">>> 4) Configurando paquetes para KDE sin bloqueos"
mkdir -p /etc/portage/package.use
mkdir -p /etc/portage/package.accept_keywords

# NO crear package.mask - KDE necesita wayland-scanner para compilar

# Aceptar keywords inestables para KDE
cat > /etc/portage/package.accept_keywords/kde <<'EOF'
# KDE Frameworks completo
kde-frameworks/* ~amd64
# Qt5 completo (todos los componentes)
dev-qt/* ~amd64
# Vulkan headers
dev-util/vulkan-headers ~amd64
EOF

# Asegurar que varios paquetes claves queden sin wayland pero CON lock para KDE
cat > /etc/portage/package.use/00-kde <<'EOF'
# Display manager / compositor
x11-misc/sddm -wayland
kde-plasma/kwin -wayland lock
kde-plasma/kwin-x11 lock
kde-plasma/plasma-meta -wayland
kde-plasma/plasma-workspace -wayland
# Xorg server con udev
x11-base/xorg-server udev
# libcanberra requiere alsa si se usa udev
media-libs/libcanberra pulseaudio udev alsa -gstreamer
# Qt6 - OpenGL y Vulkan según dependencias (sin wayland en qtbase)
dev-qt/qtbase icu gui network xml concurrent widgets libproxy cups dbus vulkan wayland -opengl -gles2-only -wayland
dev-qt/qttools opengl
dev-qt/qtdeclarative -opengl -vulkan
dev-qt/qt5compat icu qml
dev-qt/qtquick3d -opengl -vulkan
dev-qt/qtmultimedia qml -opengl -vulkan
# KDE Frameworks - dbus, wayland y qml
kde-frameworks/kconfig dbus qml
kde-frameworks/kwindowsystem wayland
kde-frameworks/kcoreaddons dbus
kde-frameworks/prison qml
kde-frameworks/kguiaddons wayland
kde-frameworks/kidletime wayland
# Qt5 - icu para qtcore
dev-qt/qtcore icu
dev-qt/qtgui egl dbus wayland
# Xwayland - libei
x11-base/xwayland libei
# NetworkManager y wpa_supplicant
net-wireless/wpa_supplicant dbus
dev-libs/qcoro dbus
# Zlib - minizip requerido por assimp
sys-libs/zlib minizip
# GTK y libdrm para compatibilidad (sin wayland)
x11-libs/gtk+ X -wayland
x11-libs/gtk+:3 X -wayland
x11-libs/libdrm video_cards_amdgpu video_cards_nouveau video_cards_intel
# Mesa y wayland sin soporte wayland
media-libs/mesa -wayland
dev-libs/wayland -abi_x86_32
EOF

### === 5) Instalar wayland-scanner (necesario para KDE) ===
echo ">>> 5) Instalando wayland-scanner..."
emerge -qv dev-util/wayland-scanner

### === 6) Instalar Xorg ===
echo ">>> 6) Instalando Xorg..."
emerge -qv x11-base/xorg-server x11-base/xorg-drivers

### === 7) Instalar KDE Plasma ===
echo ">>> 7) Instalando KDE Plasma..."
emerge --autounmask-write --autounmask-continue -qv kde-plasma/plasma-meta || {
  echo ">>> 7.1) Aplicando configuración automática..."
  etc-update --automode -3
  emerge -qv kde-plasma/plasma-meta
}

### === 8) Instalar SDDM ===
echo ">>> 8) Instalando SDDM..."
emerge -qv x11-misc/sddm

### === 9) Habilitar SDDM ===
echo ">>> 9) Habilitando SDDM..."
systemctl enable sddm
systemctl set-default graphical.target

### === 10) Configurar usuario ===
echo ">>> 10) Configurando usuario..."
usermod -a -G video,audio,input,plugdev,wheel $USR

### === 11) Aplicaciones básicas de KDE ===
echo ">>> 11) Instalando aplicaciones básicas de KDE..."
emerge -qv kde-apps/dolphin kde-apps/konsole kde-apps/kate firefox-bin || true

echo ""
echo "==================================="
echo "✓ KDE PLASMA INSTALADO"
echo "==================================="
echo ""
echo "Pasos siguientes:"
echo "  1. Revisa /var/log/Xorg.0.log si hay problemas gráficos"
echo "  2. Reinicia: reboot"
echo "  3. KDE Plasma se iniciará automáticamente con SDDM"
echo ""
echo "Usuario: $USR"
echo "==================================="
