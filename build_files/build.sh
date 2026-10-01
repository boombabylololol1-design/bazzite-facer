set -euo pipefail

# Determine the kernel shipped inside the image.
KVER="$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n1)"
KERNELDIR="/usr/src/kernels/${KVER}"

echo "Building facer for kernel: ${KVER}"
echo "Kernel build tree: ${KERNELDIR}"

test -d "${KERNELDIR}"

# Build tools needed for the kernel module
dnf5 install -y gcc make elfutils-libelf-devel "kernel-devel-${KVER}"

test -d "${KERNELDIR}"

# Copy facer source into the build environment
rm -rf /tmp/facer
cp -a /ctx/build_files/facer /tmp/facer

# Compile all three modules
make -C "${KERNELDIR}" M=/tmp/facer modules

# Install modules into the immutable image
install -d "/usr/lib/modules/${KVER}/extra/facer"

for module in facer acer-wmi-battery acpi_ec; do
    install -m 0644 \
        "/tmp/facer/${module}.ko" \
        "/usr/lib/modules/${KVER}/extra/facer/${module}.ko"

    xz -f "/usr/lib/modules/${KVER}/extra/facer/${module}.ko"
done

# Load the modules automatically at boot
cat > /etc/modules-load.d/facer.conf <<'MODULES'
facer
acer-wmi-battery
acpi_ec
MODULES

# Generate module dependency metadata
depmod -a "${KVER}"

rm -rf /tmp/facer

echo "facer kernel modules installed successfully."
