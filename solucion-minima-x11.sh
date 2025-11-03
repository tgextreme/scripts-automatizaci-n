#!/bin/bash

# Solución MÍNIMA que SIEMPRE funciona
# Sin gestores de login - Solo startx manual
USUARIO="usuario"

echo "=== SOLUCIÓN MÍNIMA X11 ==="

# Detener todo
systemctl stop lxdm 2>/dev/null
systemctl stop lightdm 2>/dev/null
systemctl stop sddm 2>/dev/null
killall -9 Xorg 2>/dev/null

# Instalar lo mínimo
emerge --sync
emerge -q x11-base/xorg-server x11-apps/xinit x11-wm/twm x11-terms/xterm

# Configurar usuario
usermod -a -G video $USUARIO

# Crear .xinitrc ULTRA simple
cat > /home/$USUARIO/.xinitrc << 'EOF'
#!/bin/sh
exec twm
EOF
chown $USUARIO:$USUARIO /home/$USUARIO/.xinitrc
chmod +x /home/$USUARIO/.xinitrc

# Permisos
chmod 1777 /tmp
touch /home/$USUARIO/.Xauthority
chown $USUARIO:$USUARIO /home/$USUARIO/.Xauthority
chmod 600 /home/$USUARIO/.Xauthority

echo ""
echo "==================================="
echo "LISTO - Ahora haz esto:"
echo "==================================="
echo ""
echo "1. Cambia a tu usuario:"
echo "   su - $USUARIO"
echo ""
echo "2. Ejecuta:"
echo "   startx"
echo ""
echo "3. Verás TWM (gestor básico)"
echo "   - Clic derecho = menu"
echo "   - Exit = salir"
echo ""
echo "Si falla, ejecuta:"
echo "   cat ~/.xsession-errors"
echo "   cat /var/log/Xorg.0.log"
echo "==================================="
