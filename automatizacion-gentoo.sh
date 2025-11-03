#!/bin/bash
set -euo pipefail

# ================== PARÁMETROS ==================
DISK="/dev/sda"
BOOT="/dev/sda1"   # /boot (ext4)
SWAP="/dev/sda2"   # swap
ROOT="/dev/sda3"   # /     (ext4)
MNT="/mnt/gentoo"

# Formateo destructivo: déjalo en "YES" para que sea 100% automático.
ERASE_PARTITIONS="YES"

# Mirror base para stage3 desktop systemd amd64:
BASE="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd"

# ================== UTILIDADES ==================
log(){ printf "\n\033[1;32m[+] %s\033[0m\n" "$*"; }
die(){ printf "\n\033[1;31m[!] %s\033[0m\n" "$*" ; exit 1; }
need(){ command -v "$1" &>/dev/null || die "Falta la herramienta '$1' en el LiveCD."; }
rootok(){ [ "$(id -u)" -eq 0 ] || die "Ejecuta como root."; }

rootok
need wget
need tar
need mkfs.ext4
need mkswap
need lsblk

log "Paso 0) Comprobaciones básicas"
lsblk || true

if [[ "$ERASE_PARTITIONS" == "YES" ]]; then
  log "Paso 1) FORMATEANDO EXT4 y SWAP (esto borra TODO en ${BOOT}, ${SWAP} y ${ROOT})"
  umount -R "${MNT}" 2>/dev/null || true
  umount -R "${BOOT}" 2>/dev/null || true
  umount -R "${ROOT}" 2>/dev/null || true
  swapoff "${SWAP}" 2>/dev/null || true
  wipefs -a "${BOOT}" 2>/dev/null || true
  wipefs -a "${SWAP}" 2>/dev/null || true
  wipefs -a "${ROOT}" 2>/dev/null || true
  mkfs.ext4 -F -L BOOT "${BOOT}"
  mkswap -L SWAP "${SWAP}"
  mkfs.ext4 -F -L ROOT "${ROOT}"
  swapon "${SWAP}"
else
  log "Saltando formateo por configuración (ERASE_PARTITIONS!=YES)"
fi

log "Paso 2) Montando ${ROOT} -> ${MNT} y ${BOOT} -> ${MNT}/boot"
mkdir -p "${MNT}"
mount -o rw "${ROOT}" "${MNT}"
mkdir -p "${MNT}/boot"
mount -o rw "${BOOT}" "${MNT}/boot"

log "Paso 3) Descargando stage3 desktop systemd amd64 más reciente"
mkdir -p "${MNT}/var/tmp/stage3"
cd "${MNT}/var/tmp/stage3"
# Obtener nombre del último stage3 desde el archivo 'latest-...txt'
LATEST_TXT="latest-stage3-amd64-desktop-systemd.txt"
wget -q "${BASE}/${LATEST_TXT}" -O "${LATEST_TXT}"
STAGE_REL=$(awk '/stage3.*tar.*/{print $1; exit}' "${LATEST_TXT}")   || die "No pude parsear ${LATEST_TXT}"
STAGE_URL="${BASE}/${STAGE_REL}"
STAGE_FILE="${STAGE_REL##*/}"

log "  -> ${STAGE_FILE}"
wget -q "${STAGE_URL}" -O "${STAGE_FILE}" || die "Fallo al descargar stage3"

log "Paso 4) Extrayendo stage3 en ${MNT}"
cd "${MNT}"
tar xpf "var/tmp/stage3/${STAGE_FILE}" --xattrs-include='*.*' --numeric-owner

log "Paso 5) Preparando chroot (proc, sys, dev, DNS)"
cp -L /etc/resolv.conf "${MNT}/etc/" || true
mount -t proc /proc "${MNT}/proc"
mount --rbind /sys "${MNT}/sys" && mount --make-rslave "${MNT}/sys"
mount --rbind /dev "${MNT}/dev" && mount --make-rslave "${MNT}/dev"

# -------- Script que se ejecuta dentro del chroot --------
cat > "${MNT}/root/instala_dentro.sh" <<'CHROOT_SCRIPT'
#!/bin/bash
set -euo pipefail
log(){ printf "\n\033[1;36m[CHROOT] %s\033[0m\n" "$*"; }
die(){ printf "\n\033[1;31m[CHROOT][!] %s\033[0m\n" "$*"; exit 1; }

log "A) Cargando entorno"
source /etc/profile || true
export PS1="(chroot) ${PS1:-\h:\w\\\$ }"

log "B) Asegurando /boot montado"
mountpoint -q /boot || mount /boot || mount /dev/sda1 /boot

log "C) Sync de Portage (puede tardar)"
(emaint -a sync || emerge --sync) >/dev/null || true

log "D) Seleccionando perfil systemd si no está ya"
if eselect profile list | grep -qE 'amd64/.*systemd'; then
  TARGET="$(eselect profile list | awk '/amd64\/.*systemd/ {print $2}' | sed -n '1p')"
  eselect profile set "${TARGET}"
fi

log "E) Ajustes Portage: GRUB BIOS, licencias y keywords"
mkdir -p /etc/portage/package.use
mkdir -p /etc/portage/package.accept_keywords
mkdir -p /etc/portage/package.license

# Aceptar licencias redistributables del firmware en make.conf (método más efectivo)
grep -q '^ACCEPT_LICENSE=' /etc/portage/make.conf 2>/dev/null || echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
grep -q '^GRUB_PLATFORMS=' /etc/portage/make.conf 2>/dev/null || echo 'GRUB_PLATFORMS="pc"' >> /etc/portage/make.conf

# Configurar USE flags necesarios
echo "sys-kernel/installkernel dracut" > /etc/portage/package.use/kernel

# También en package.license por redundancia
echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" > /etc/portage/package.license/linux-firmware
echo "sys-firmware/linux-firmware @BINARY-REDISTRIBUTABLE" >> /etc/portage/package.license/linux-firmware

# Aceptar keywords ~amd64 si es necesario
echo "sys-kernel/linux-firmware **" > /etc/portage/package.accept_keywords/firmware
echo "sys-kernel/gentoo-kernel-bin **" >> /etc/portage/package.accept_keywords/firmware

log "F) Instalando kernel binario precompilado (más rápido y sin problemas de masked)"
# Primera pasada: dejar que emerge escriba configuraciones automáticas
emerge --autounmask-write -q sys-kernel/gentoo-kernel-bin sys-kernel/linux-firmware \
  sys-boot/grub:2 net-misc/dhcpcd 2>&1 || true

# Aplicar configuraciones automáticas
etc-update --automode -5 2>/dev/null || true
yes | etc-update 2>/dev/null || true

# Segunda pasada: instalar realmente
emerge -q sys-kernel/gentoo-kernel-bin sys-kernel/linux-firmware \
  sys-boot/grub:2 net-misc/dhcpcd || die "Fallo al instalar paquetes base"

log "G) El kernel binario ya incluye initramfs, verificando instalación"
KVER=$(ls -1 /lib/modules/ | sort -V | tail -n1)
[ -n "${KVER}" ] || die "No se encontró kernel instalado en /lib/modules"
log "   Versión del kernel instalado: ${KVER}"

log "H) Configurando hostname, zona horaria y locales"
echo "gentoo-box" > /etc/hostname
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data || true
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8 || true

log "I) fstab para sda3(/) y sda1(/boot) en ext4"
cat > /etc/fstab <<EOF
/dev/sda3   /      ext4   noatime                0 1
/dev/sda1   /boot  ext4   noauto,noatime         0 2
/dev/sda2   none   swap   sw                     0 0
EOF

log "J) Verificando /boot montado antes de instalar GRUB"
mountpoint -q /boot || mount /boot

log "K) Instalar GRUB en MBR del disco y generar grub.cfg"
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

log "L) Habilitar servicios útiles de systemd (red y hora)"
systemctl enable dhcpcd.service || true
systemctl enable systemd-timesyncd.service || true

log "M) Resumen de /boot:"
ls -l /boot
ls -l /boot/grub/grub.cfg

log "N) IMPORTANTE: Establece un password a root ahora"

log "M) fstab para sda3(/) y sda1(/boot) en ext4"
cat > /etc/fstab <<EOF
/dev/sda3   /      ext4   noatime                0 1
/dev/sda1   /boot  ext4   noauto,noatime         0 2
/dev/sda2   none   swap   sw                     0 0
EOF

log "N) Verificando /boot montado antes de instalar GRUB"
mountpoint -q /boot || mount /boot

log "O) Instalar GRUB en MBR del disco y generar grub.cfg"
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

log "N) Verificando /boot montado antes de instalar GRUB"
mountpoint -q /boot || mount /boot

log "O) Instalar GRUB en MBR del disco y generar grub.cfg"
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

log "P) Habilitar servicios útiles de systemd (red y hora)"
systemctl enable dhcpcd.service || true
systemctl enable systemd-timesyncd.service || true

log "Q) Resumen de /boot:"
ls -l /boot
ls -l /boot/grub/grub.cfg

log "R) IMPORTANTE: Establece un password a root ahora"
echo "root:gentoo" | chpasswd
echo "   Password temporal de root: 'gentoo' - CÁMBIALO tras el primer arranque con 'passwd'"

log "S) Creando usuario para KDE"
useradd -m -G users,wheel,audio,video,input -s /bin/bash usuario || true
echo "usuario:usuario" | chpasswd
echo "   Usuario: usuario / Password: usuario"

log "T) Configurando sudo para el grupo wheel"
emerge -q app-admin/sudo || true
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

log "U) Instalando KDE Plasma con configuración automática"
# Keywords y USE flags para KDE
mkdir -p /etc/portage/package.accept_keywords
cat > /etc/portage/package.accept_keywords/kde <<'KEOF'
kde-frameworks/* ~amd64
dev-qt/* ~amd64
dev-util/vulkan-headers ~amd64
KEOF

mkdir -p /etc/portage/package.use
cat > /etc/portage/package.use/00-kde <<'USEEOF'
# Display manager / compositor
x11-misc/sddm -wayland
kde-plasma/kwin -wayland lock
kde-plasma/kwin-x11 lock
kde-plasma/plasma-meta -wayland
kde-plasma/plasma-workspace -wayland
# Xorg
x11-base/xorg-server udev
# Qt6
dev-qt/qtbase icu gui network xml concurrent widgets libproxy cups dbus vulkan wayland -opengl -gles2-only
dev-qt/qttools opengl
dev-qt/qtdeclarative -opengl -vulkan
dev-qt/qt5compat icu qml
dev-qt/qtquick3d -opengl -vulkan
dev-qt/qtmultimedia qml -opengl -vulkan
# KDE Frameworks
kde-frameworks/kconfig dbus qml
kde-frameworks/kwindowsystem wayland
kde-frameworks/kcoreaddons dbus
kde-frameworks/prison qml
kde-frameworks/kguiaddons wayland
kde-frameworks/kidletime wayland
# Qt5
dev-qt/qtcore icu
dev-qt/qtgui egl dbus wayland
# Xwayland
x11-base/xwayland libei
# NetworkManager
net-wireless/wpa_supplicant dbus
dev-libs/qcoro dbus
# Otros
sys-libs/zlib minizip
x11-libs/gtk+ X -wayland
x11-libs/gtk+:3 X -wayland
x11-libs/libdrm video_cards_amdgpu video_cards_nouveau video_cards_intel
media-libs/mesa -wayland
media-libs/libcanberra pulseaudio udev alsa -gstreamer
USEEOF

log "V) Instalando KDE Plasma (esto tomará 1-3 horas)..."
emerge --autounmask-write --autounmask-continue -q kde-plasma/plasma-meta x11-misc/sddm \
  kde-apps/dolphin kde-apps/konsole kde-apps/kate www-client/firefox-bin || {
  etc-update --automode -3
  emerge -q kde-plasma/plasma-meta x11-misc/sddm kde-apps/dolphin kde-apps/konsole kde-apps/kate www-client/firefox-bin
}

log "W) Habilitando SDDM (display manager de KDE)"
systemctl enable sddm
systemctl set-default graphical.target

log "X) KDE Plasma instalado correctamente"

log "OK dentro del chroot."
CHROOT_SCRIPT
# -------- fin script chroot --------

chmod +x "${MNT}/root/instala_dentro.sh"

log "Paso 6) Entrando en chroot para la configuración interna"
chroot "${MNT}" /bin/bash -lc "/root/instala_dentro.sh"

log "Paso 7) Limpiando y desmontando"
sync
umount -l "${MNT}/dev"{/shm,/pts,} 2>/dev/null || true
umount -R "${MNT}/proc" 2>/dev/null || true
umount -R "${MNT}/sys" 2>/dev/null || true
umount -R "${MNT}/boot" 2>/dev/null || true
umount -R "${MNT}" 2>/dev/null || true

log "Todo listo. Ejecuta:  reboot"
log "Credenciales: usuario=root, password=gentoo (CÁMBIALO DESPUÉS)"
