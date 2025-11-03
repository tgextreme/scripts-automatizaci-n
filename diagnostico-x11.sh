#!/bin/bash

# Script de DIAGNÓSTICO para problemas de X11
# Ejecuta esto para ver qué está fallando

echo "==================================="
echo "DIAGNÓSTICO DE X11"
echo "==================================="

echo ""
echo ">>> 1. Verificando Xorg instalado..."
which X
which Xorg
ls -l /usr/bin/X*

echo ""
echo ">>> 2. Verificando drivers de video..."
lspci | grep -i vga
lspci | grep -i display
ls -l /usr/lib64/xorg/modules/drivers/

echo ""
echo ">>> 3. Verificando gestor de ventanas..."
which openbox
which openbox-session

echo ""
echo ">>> 4. Verificando usuario en grupos correctos..."
groups usuario

echo ""
echo ">>> 5. Verificando permisos de /tmp..."
ls -ld /tmp

echo ""
echo ">>> 6. Últimos logs de Xorg..."
tail -50 /var/log/Xorg.0.log

echo ""
echo ">>> 7. Verificando servicios..."
systemctl status lxdm --no-pager
systemctl status lightdm --no-pager 2>/dev/null || echo "lightdm no instalado"
systemctl status sddm --no-pager 2>/dev/null || echo "sddm no instalado"

echo ""
echo ">>> 8. Verificando procesos X..."
ps aux | grep -i x11
ps aux | grep -i xorg

echo ""
echo "==================================="
echo "PRUEBA MANUAL:"
echo "==================================="
echo ""
echo "Como usuario normal (NO root), ejecuta:"
echo "  su - usuario"
echo "  startx"
echo ""
echo "Y observa los errores que aparezcan"
echo "==================================="
