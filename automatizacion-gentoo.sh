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

# Mirror base para stage3 systemd amd64:
BASE="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-systemd"

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

log "Paso 3) Descargando stage3 systemd amd64 más reciente"
mkdir -p "${MNT}/var/tmp/stage3"
cd "${MNT}/var/tmp/stage3"
# Obtener nombre del último stage3 desde el archivo 'latest-...txt'
LATEST_TXT="latest-stage3-amd64-systemd.txt"
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
grep -q '^GRUB_PLATFORMS=' /etc/portage/make.conf 2>/dev/null || echo 'GRUB_PLATFORMS="pc"' >> /etc/portage/make.conf

# Aceptar licencias redistributables del firmware
echo "sys-kernel/linux-firmware linux-fw-redistributable no-source-code" > /etc/portage/package.license/linux-firmware
echo "sys-firmware/linux-firmware linux-fw-redistributable no-source-code" >> /etc/portage/package.license/linux-firmware

# Aceptar keywords ~amd64 si es necesario
echo "sys-kernel/linux-firmware ~amd64" > /etc/portage/package.accept_keywords/firmware
echo "sys-kernel/gentoo-kernel-bin ~amd64" >> /etc/portage/package.accept_keywords/firmware

log "F) Instalando kernel binario precompilado (más rápido y sin problemas de masked)"
# Usar kernel binario para evitar problemas con versiones masked y compilación larga
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
