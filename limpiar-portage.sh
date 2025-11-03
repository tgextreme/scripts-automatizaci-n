#!/bin/bash

# Script para limpiar errores de Portage y reinstalar correctamente

echo "==================================="
echo "LIMPIEZA Y CORRECCIÓN DE PORTAGE"
echo "==================================="

# 1. Limpiar archivos corruptos
echo ">>> Limpiando archivos corruptos..."
rm -f /etc/portage/package.accept_keywords/all
rm -f /etc/portage/package.accept_keywords/sway
rm -f /etc/portage/package.accept_keywords/sway-full
rm -f /etc/portage/package.use/wayland
rm -f /etc/portage/package.use/sway
rm -f /etc/portage/package.use/sway-full

# 2. Limpiar archivos temporales
echo ">>> Limpiando temporales de emerge..."
rm -rf /var/tmp/portage/*
rm -rf /var/db/repos/gentoo/.tmp-unverified-download-quarantine

# 3. Actualizar Portage
echo ">>> Actualizando Portage..."
emerge --sync

# 4. Crear configuración LIMPIA
echo ">>> Creando configuración limpia..."
mkdir -p /etc/portage/package.accept_keywords
mkdir -p /etc/portage/package.use

# Verificar que ACCEPT_LICENSE está configurado
if ! grep -q 'ACCEPT_LICENSE=' /etc/portage/make.conf; then
    echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
fi

# 5. Keywords limpios
cat > /etc/portage/package.accept_keywords/basico << 'ENDFILE'
gui-wm/sway **
gui-libs/wlroots **
x11-terms/foot **
www-client/firefox-bin **
x11-misc/pcmanfm **
ENDFILE

# 6. USE flags limpios
cat > /etc/portage/package.use/basico << 'ENDFILE'
gui-wm/sway X
gui-libs/wlroots x11-backend
media-libs/mesa wayland
ENDFILE

echo ""
echo "==================================="
echo "✓ PORTAGE LIMPIO Y CORREGIDO"
echo "==================================="
echo ""
echo "Ahora ejecuta:"
echo "  bash instalar-basico.sh"
echo "==================================="
