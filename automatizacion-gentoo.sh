#!/bin/bash
set -euo pipefail

# ================== PARÁMETROS ==================
DISK="/dev/sda"
BOOT="/dev/sda1"   # /boot (ext4)
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
need lsblk

log "Paso 0) Comprobaciones básicas"
lsblk || true

if [[ "$ERASE_PARTITIONS" == "YES" ]]; then
  log "Paso 1) FORMATEANDO EXT4 (esto borra TODO en ${BOOT} y ${ROOT})"
  umount -R "${MNT}" 2>/dev/null || true
  umount -R "${BOOT}" 2>/dev/null || true
  umount -R "${ROOT}" 2>/dev/null || true
  wipefs -a "${BOOT}" 2>/dev/null || true
  wipefs -a "${ROOT}" 2>/dev/null || true
  mkfs.ext4 -F -L BOOT "${BOOT}"
  mkfs.ext4 -F -L ROOT "${ROOT}"
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
export PS1="(chroot) $PS1"

log "B) Asegurando /boot montado"
mountpoint -q /boot || mount /boot || mount /dev/sda1 /boot

log "C) Sync de Portage (puede tardar)"
(emaint -a sync || emerge --sync) >/dev/null || true

log "D) Seleccionando perfil systemd si no está ya"
if eselect profile list | grep -qE 'amd64/.*systemd'; then
  TARGET="$(eselect profile list | awk '/amd64\/.*systemd/ {print $2}' | sed -n '1p')"
  eselect profile set "${TARGET}"
fi

log "E) Ajustes Portage: GRUB BIOS + dracut para installkernel"
mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut" > /etc/portage/package.use/installkernel-dracut
grep -q '^GRUB_PLATFORMS=' /etc/portage/make.conf 2>/dev/null || echo 'GRUB_PLATFORMS="pc"' >> /etc/portage/make.conf

log "F) Paquetes base: kernel vanilla, dracut, grub2 (BIOS), firmware, headers, dhcpcd"
emerge -q --autounmask=y --autounmask-continue=y \
  sys-kernel/vanilla-sources sys-kernel/dracut sys-boot/grub:2 \
  sys-kernel/installkernel sys-kernel/linux-headers sys-firmware/linux-firmware \
  net-misc/dhcpcd

command -v etc-update >/dev/null && etc-update --automode -5 || true

log "G) Preparar /usr/src/linux -> última versión de vanilla-sources"
cd /usr/src
LATEST="$(ls -d vanilla-sources-* | sort -V | tail -n1)"
[ -n "${LATEST}" ] || die "No se encontró vanilla-sources instalado."
ln -sfn "/usr/src/${LATEST}" /usr/src/linux
cd /usr/src/linux

log "H) Configuración rápida del kernel (defconfig + flags mínimas)"
make mrproper
make defconfig

# Activar initramfs y autodescubrimiento de dispositivos básicos
./scripts/config --enable BLK_DEV_INITRD || true
./scripts/config --enable DEVTMPFS || true
./scripts/config --enable DEVTMPFS_MOUNT || true
./scripts/config --module EXT4_FS || true
./scripts/config --module SCSI_MOD || true
./scripts/config --module BLK_DEV_SD || true
./scripts/config --module ATA || true
./scripts/config --module SATA_AHCI || true
./scripts/config --module NVME_CORE || true
./scripts/config --module MD || true
./scripts/config --module DM_CRYPT || true
yes "" | make olddefconfig

log "I) Compilando kernel y módulos (tarda según CPU)"
make -j"$(nproc)"
make modules_install

KVER="$(make kernelrelease)"
log "   Versión del kernel: ${KVER}"

log "J) Instalando kernel en /boot/vmlinuz-${KVER}"
install -D -m 0644 arch/x86/boot/bzImage "/boot/vmlinuz-${KVER}"

log "K) Generando initramfs con dracut"
dracut --kver "${KVER}" --force
ls -l "/boot/initramfs-${KVER}.img"

log "L) fstab para sda3(/) y sda1(/boot) en ext4"
cat > /etc/fstab <<EOF
/dev/sda3   /      ext4   noatime                0 1
/dev/sda1   /boot  ext4   noauto,noatime         0 2
EOF

log "M) Instalar GRUB en MBR del disco y generar grub.cfg"
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

log "N) Habilitar servicios útiles de systemd (red y hora)"
systemctl enable dhcpcd.service || true
systemctl enable systemd-timesyncd.service || true

log "O) Resumen de /boot:"
ls -l /boot
ls -l /boot/grub/grub.cfg

log "P) (Opcional) Establece un password a root tras el primer arranque: 'passwd'"
log "OK dentro del chroot."
CHROOT_SCRIPT
# -------- fin script chroot --------

chmod +x "${MNT}/root/instala_dentro.sh"

log "Paso 6) Entrando en chroot para la configuración interna"
chroot "${MNT}" /bin/bash -lc "/root/instala_dentro.sh"

log "Paso 7) Limpiando y desmontando"
sync
umount -R "${MNT}"

log "Todo listo. Ejecuta:  reboot"
