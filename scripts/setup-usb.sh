#!/usr/bin/env bash
# =============================================================================
# setup-usb.sh -- one-time host setup so Radiant Programmer can reach the
#                 CrossLinkU-NX board's FT2232H JTAG cable.
#
# Two things block access out of the box:
#   1. The Linux ftdi_sio driver grabs the FT2232H and exposes it as
#      /dev/ttyUSB0 / ttyUSB1 (UART mode).  Radiant's cable driver needs the
#      JTAG interface (interface 0) free.
#   2. The raw USB node is root-owned, so libusb (run as your user) can't open
#      it.  A udev rule fixes permissions for the FTDI VID:PID.
#
# Run once with sudo:   sudo scripts/setup-usb.sh
# Re-plug the board (or replug USB) after running, then use scripts/program.sh.
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Please run with sudo: sudo $0"; exit 1; fi

VID=0403
PID=6010

echo "[1/2] Installing udev rule for FTDI ${VID}:${PID} (plugdev, mode 0666)..."
cat > /etc/udev/rules.d/99-lattice-ftdi.rules <<EOF
# Lattice FT2232H programmer (CrossLinkU-NX / Nexus eval boards)
SUBSYSTEM=="usb", ATTR{idVendor}=="${VID}", ATTR{idProduct}=="${PID}", GROUP="plugdev", MODE="0666"
EOF
udevadm control --reload-rules
udevadm trigger || true

echo "[2/2] Unbinding ftdi_sio from the FT2232H so the JTAG interface is free..."
# Detach the kernel UART driver from both FT2232H interfaces (ours only).
for i in /sys/bus/usb/drivers/ftdi_sio/*:1.0 /sys/bus/usb/drivers/ftdi_sio/*:1.1; do
  [[ -e "$i" ]] || continue
  dev=$(basename "$i")
  parent="/sys/bus/usb/devices/${dev%:*}"
  if [[ -f "$parent/idVendor" ]] && grep -q "$VID" "$parent/idVendor" 2>/dev/null; then
    echo "   unbinding $dev"
    echo -n "$dev" > /sys/bus/usb/drivers/ftdi_sio/unbind 2>/dev/null || true
  fi
done

echo
echo "Done. Re-plug the board's MicroUSB, then run:  scripts/program.sh"
echo "(If ftdi_sio re-grabs the cable after a reboot, just re-run this script.)"
