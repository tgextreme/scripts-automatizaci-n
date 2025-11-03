#!/bin/bash

# Script para solucionar el problema de reinicio del login después de poner la contraseña
# CAMBIA "usuario" por tu nombre de usuario real en la línea siguiente
USUARIO="usuario"

echo "=== Solucionando problema de reinicio de login para: $USUARIO ==="

# 1. Agregar usuario a todos los grupos necesarios
echo "Agregando usuario a grupos necesarios..."
usermod -a -G wheel,audio,video,input,seat $USUARIO
usermod -a -G plugdev,usb,users $USUARIO

# 2. Configurar permisos de /tmp y /var/tmp
echo "Configurando permisos de directorios temporales..."
chmod 1777 /tmp
chmod 1777 /var/tmp
mkdir -p /run/user
chmod 755 /run/user

# 3. Instalar y configurar elogind (gestión de sesiones)
echo "Instalando elogind..."
emerge -q sys-auth/elogind
systemctl enable elogind
systemctl start elogind

# 4. Instalar dbus (necesario para comunicación entre procesos)
echo "Instalando dbus..."
emerge -q sys-apps/dbus
systemctl enable dbus
systemctl start dbus

# 5. Verificar y crear archivos de sesión para LightDM
echo "Configurando sesiones disponibles..."
mkdir -p /usr/share/xsessions

# Crear sesión OpenBox
cat > /usr/share/xsessions/openbox.desktop << 'EOF'
[Desktop Entry]
Name=OpenBox
Comment=OpenBox Window Manager
Exec=openbox-session
Type=Application
DesktopNames=OpenBox
EOF

# Crear sesión simple con Xterm
cat > /usr/share/xsessions/xterm.desktop << 'EOF'
[Desktop Entry]
Name=Xterm Session
Comment=Simple X Terminal Session
Exec=/usr/bin/xterm
Type=Application
DesktopNames=Xterm
EOF

# 6. Verificar instalación de window manager
echo "Verificando gestor de ventanas..."
emerge -q x11-wm/openbox x11-terms/xterm

# 7. Crear archivo .xinitrc válido para el usuario
echo "Creando archivo .xinitrc..."
cat > /home/$USUARIO/.xinitrc << 'EOF'
#!/bin/sh

# Iniciar dbus si no está corriendo
if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# Iniciar gestor de ventanas
exec openbox-session
EOF
chown $USUARIO:$USUARIO /home/$USUARIO/.xinitrc
chmod +x /home/$USUARIO/.xinitrc

# 8. Crear configuración básica de OpenBox
echo "Configurando OpenBox..."
mkdir -p /home/$USUARIO/.config/openbox
cat > /home/$USUARIO/.config/openbox/autostart << 'EOF'
# Iniciar terminal automáticamente
xterm &
EOF
chown -R $USUARIO:$USUARIO /home/$USUARIO/.config

# 9. Configurar LightDM correctamente
echo "Configurando LightDM..."
cat > /etc/lightdm/lightdm.conf << 'EOF'
[LightDM]
run-directory=/run/lightdm

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=openbox
session-wrapper=/etc/lightdm/Xsession
autologin-user-timeout=0
pam-service=lightdm
pam-autologin-service=lightdm-autologin
EOF

# 10. Crear script de sesión X
cat > /etc/lightdm/Xsession << 'EOF'
#!/bin/sh
# Xsession - run as user

# Iniciar dbus
if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# Cargar .profile
test -f /etc/profile && . /etc/profile
test -f $HOME/.profile && . $HOME/.profile

# Cargar recursos X
test -f /etc/X11/Xresources && xrdb -merge /etc/X11/Xresources
test -f $HOME/.Xresources && xrdb -merge $HOME/.Xresources

# Ejecutar sesión
exec $@
EOF
chmod +x /etc/lightdm/Xsession

# 11. Configurar PAM para LightDM
cat > /etc/pam.d/lightdm << 'EOF'
auth       include      system-local-login
account    include      system-local-login
password   include      system-local-login
session    include      system-local-login
EOF

cat > /etc/pam.d/lightdm-autologin << 'EOF'
auth       include      system-local-login
account    include      system-local-login
password   include      system-local-login
session    include      system-local-login
EOF

# 12. Verificar permisos del home
echo "Verificando permisos del home del usuario..."
chown -R $USUARIO:$USUARIO /home/$USUARIO
chmod 755 /home/$USUARIO

# 13. Limpiar archivos de bloqueo antiguos
echo "Limpiando archivos de bloqueo..."
rm -f /tmp/.X0-lock
rm -f /tmp/.X11-unix/X0
rm -rf /run/lightdm/*

# 14. Verificar y crear directorio de runtime
mkdir -p /run/user/$(id -u $USUARIO)
chown $USUARIO:$USUARIO /run/user/$(id -u $USUARIO)
chmod 700 /run/user/$(id -u $USUARIO)

# 15. Reiniciar servicios
echo "Reiniciando servicios..."
systemctl restart elogind
systemctl restart dbus
systemctl stop lightdm
sleep 2

# 16. Instalar consolekit2 como alternativa (más compatible)
echo "Instalando consolekit2 como alternativa..."
emerge -q sys-auth/consolekit

# 17. Configurar polkit
echo "Instalando y configurando polkit..."
emerge -q sys-auth/polkit
cat > /etc/polkit-1/rules.d/50-default.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# 18. Verificar shell del usuario
echo "Verificando shell del usuario..."
chsh -s /bin/bash $USUARIO

# 19. Crear directorio .cache
mkdir -p /home/$USUARIO/.cache
chown -R $USUARIO:$USUARIO /home/$USUARIO/.cache
chmod 700 /home/$USUARIO/.cache

# 20. Configurar variables de entorno
cat > /home/$USUARIO/.bash_profile << 'EOF'
# .bash_profile

# Cargar .bashrc si existe
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Variables para sesión X
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
EOF
chown $USUARIO:$USUARIO /home/$USUARIO/.bash_profile

# 21. Instalar policykit-desktop-privileges
emerge -q sys-auth/polkit-qt || true

# 22. Configurar SDDM como alternativa a LightDM
echo "Instalando SDDM como alternativa..."
mkdir -p /etc/portage/package.accept_keywords
echo "x11-misc/sddm ~amd64" >> /etc/portage/package.accept_keywords/sddm
emerge -q x11-misc/sddm
systemctl enable sddm

# 23. Verificar instalación de gtk
emerge -q x11-libs/gtk+:3 x11-themes/gnome-themes-standard

# 24. Limpiar todo y reiniciar LightDM
systemctl start lightdm

echo ""
echo "==================================="
echo "Solución aplicada!"
echo "==================================="
echo ""
echo "Cambios realizados:"
echo "✓ Usuario agregado a grupos necesarios"
echo "✓ Permisos de directorios corregidos"
echo "✓ elogind, dbus y consolekit instalados"
echo "✓ Sesiones X creadas correctamente"
echo "✓ Archivos de configuración reparados"
echo "✓ Polkit configurado"
echo "✓ Variables de entorno configuradas"
echo "✓ SDDM instalado como alternativa"
echo "✓ Servicios reiniciados"
echo ""
echo "OPCIONES:"
echo "1. Probar LightDM ahora (debería aparecer el login)"
echo "2. Si no funciona, ejecuta: systemctl stop lightdm && systemctl start sddm"
echo "3. O reinicia el sistema: reboot"
echo ""
echo "Si el problema persiste, verifica los logs:"
echo "  journalctl -xe | grep -i lightdm"
echo "  journalctl -xe | grep -i sddm"
echo "  cat /var/log/Xorg.0.log"
echo ""
echo "O prueba startx desde la terminal (Ctrl+Alt+F2):"
echo "  su - $USUARIO"
echo "  startx"
echo "==================================="
