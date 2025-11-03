#!/bin/bash

echo "========================================="
echo "DIAGNÓSTICO DE SWAY - VirtualBox"
echo "========================================="

echo ""
echo "1. Verificando si Sway está instalado..."
if command -v sway &> /dev/null; then
    echo "✓ Sway instalado: $(which sway)"
else
    echo "✗ Sway NO está instalado"
fi

echo ""
echo "2. Verificando Waybar..."
if command -v waybar &> /dev/null; then
    echo "✓ Waybar instalado: $(which waybar)"
else
    echo "✗ Waybar NO está instalado"
fi

echo ""
echo "3. Verificando terminal..."
if command -v foot &> /dev/null; then
    echo "✓ foot instalado: $(which foot)"
else
    echo "✗ foot NO está instalado"
fi

echo ""
echo "4. Verificando Firefox..."
if command -v firefox &> /dev/null; then
    echo "✓ Firefox instalado: $(which firefox)"
else
    echo "✗ Firefox NO está instalado"
fi

echo ""
echo "5. Verificando file manager..."
if command -v pcmanfm &> /dev/null; then
    echo "✓ PCManFM instalado: $(which pcmanfm)"
else
    echo "✗ PCManFM NO está instalado"
fi

echo ""
echo "6. Verificando configuración Sway..."
if [ -f "/home/usuario/.config/sway/config" ]; then
    echo "✓ Config Sway existe"
else
    echo "✗ Config Sway NO existe"
fi

echo ""
echo "7. Verificando Waybar config..."
if [ -f "/home/usuario/.config/waybar/config" ]; then
    echo "✓ Config Waybar existe"
else
    echo "✗ Config Waybar NO existe"
fi

echo ""
echo "8. Verificando permisos de /home/usuario..."
ls -la /home/usuario/.config/ 2>/dev/null || echo "✗ /home/usuario/.config no existe"

echo ""
echo "9. Verificando grupos del usuario..."
groups usuario

echo ""
echo "10. Verificando XDG_RUNTIME_DIR..."
echo "Usuario: $(id -u usuario)"
if [ -d "/run/user/$(id -u usuario)" ]; then
    echo "✓ /run/user/$(id -u usuario) existe"
    ls -la /run/user/$(id -u usuario)
else
    echo "✗ /run/user/$(id -u usuario) NO existe"
fi

echo ""
echo "11. Verificando autologin..."
if [ -f "/etc/systemd/system/getty@tty1.service.d/autologin.conf" ]; then
    echo "✓ Autologin configurado"
    cat /etc/systemd/system/getty@tty1.service.d/autologin.conf
else
    echo "✗ Autologin NO configurado"
fi

echo ""
echo "12. Verificando .bash_profile..."
if [ -f "/home/usuario/.bash_profile" ]; then
    echo "✓ .bash_profile existe"
    cat /home/usuario/.bash_profile
else
    echo "✗ .bash_profile NO existe"
fi

echo ""
echo "13. Últimos logs de systemd (posibles errores)..."
journalctl -b -p err -n 20

echo ""
echo "14. Logs de Sway (si existe)..."
journalctl --user -u sway -n 20 2>/dev/null || echo "No hay logs de Sway"

echo ""
echo "15. Verificando si hay proceso Sway corriendo..."
ps aux | grep -i sway | grep -v grep

echo ""
echo "========================================="
echo "DIAGNÓSTICO COMPLETO"
echo "========================================="
echo ""
echo "Para intentar iniciar Sway manualmente:"
echo "  su - usuario"
echo "  sway"
echo ""
echo "Si ves errores, cópialos y compártelos"
echo "========================================="
