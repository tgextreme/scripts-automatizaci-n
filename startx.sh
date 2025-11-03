#!/bin/bash

# Script para solucionar problemas de inicio gráfico en Gentoo
# Instala y configura todo lo necesario para login gráfico

echo "=== Solucionando problemas de inicio gráfico ==="

# Configurar keywords y licencias
mkdir -p /etc/portage/package.accept_keywords
mkdir -p /etc/portage/package.use
echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf

# Keywords para paquetes necesarios
echo "x11-base/xorg-server ~amd64" >> /etc/portage/package.accept_keywords/xorg
echo "x11-drivers/xf86-video-intel ~amd64" >> /etc/portage/package.accept_keywords/xorg
echo "x11-drivers/xf86-video-amdgpu ~amd64" >> /etc/portage/package.accept_keywords/xorg
echo "x11-drivers/xf86-video-nouveau ~amd64" >> /etc/portage/package.accept_keywords/xorg
echo "x11-misc/lightdm ~amd64" >> /etc/portage/package.accept_keywords/xorg
echo "x11-misc/lightdm-gtk-greeter ~amd64" >> /etc/portage/package.accept_keywords/xorg
echo "x11-wm/openbox ~amd64" >> /etc/portage/package.accept_keywords/xorg
echo "x11-terms/xterm ~amd64" >> /etc/portage/package.accept_keywords/xorg

# USE flags necesarios
echo "x11-base/xorg-server elogind" >> /etc/portage/package.use/xorg
echo "x11-misc/lightdm gtk" >> /etc/portage/package.use/xorg

# Actualizar repositorio
emerge --sync

# Instalar servidor X
emerge -q x11-base/xorg-server x11-base/xorg-drivers

# Instalar drivers de video (adapta según tu hardware)
# Intel
emerge -q x11-drivers/xf86-video-intel || true
# AMD
emerge -q x11-drivers/xf86-video-amdgpu || true
# NVIDIA (open source)
emerge -q x11-drivers/xf86-video-nouveau || true

# Instalar gestor de login LightDM
emerge -q x11-misc/lightdm x11-misc/lightdm-gtk-greeter

# Instalar ventana simple (OpenBox)
emerge -q x11-wm/openbox

# Instalar terminal X
emerge -q x11-terms/xterm

# Instalar fuentes básicas
emerge -q media-fonts/dejavu media-fonts/liberation-fonts

# Habilitar elogind (necesario para login gráfico)
systemctl enable elogind

# Configurar LightDM
cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=openbox
EOF

# Habilitar LightDM
systemctl enable lightdm

# Crear archivo .xinitrc para startx (por si acaso)
cat > /root/.xinitrc << 'EOF'
#!/bin/sh
exec openbox-session
EOF
chmod +x /root/.xinitrc

# Si hay usuario, crear .xinitrc también
for user_home in /home/*; do
    username=$(basename $user_home)
    cat > $user_home/.xinitrc << 'EOF'
#!/bin/sh
exec openbox-session
EOF
    chown $username:$username $user_home/.xinitrc
    chmod +x $user_home/.xinitrc
done

# Configurar OpenBox
mkdir -p /root/.config/openbox
cat > /root/.config/openbox/autostart << 'EOF'
xterm &
EOF

for user_home in /home/*; do
    username=$(basename $user_home)
    mkdir -p $user_home/.config/openbox
    cat > $user_home/.config/openbox/autostart << 'EOF'
xterm &
EOF
    chown -R $username:$username $user_home/.config
done

# Verificar grupo video
usermod -a -G video root
for user_home in /home/*; do
    username=$(basename $user_home)
    usermod -a -G video $username
done

echo ""
echo "==================================="
echo "Configuración completada!"
echo "==================================="
echo ""
echo "Opciones para iniciar gráfico:"
echo ""
echo "1. Reiniciar y usar LightDM (recomendado):"
echo "   reboot"
echo ""
echo "2. Iniciar LightDM manualmente ahora:"
echo "   systemctl start lightdm"
echo ""
echo "3. Usar startx (sin gestor de login):"
echo "   startx"
echo ""
echo "Si tienes problemas:"
echo "- Verifica los logs: journalctl -xe"
echo "- Verifica Xorg: cat /var/log/Xorg.0.log"
echo "- Verifica video: lspci | grep VGA"
echo "==================================="
