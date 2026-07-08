#!/usr/bin/env bash
# program.sh -- load the bitstream onto the CrossLinkU-NX-33 board over JTAG.
#
# Prereq (one time, as root):   sudo ./setup-usb.sh
#   ...frees the FT2232H from ftdi_sio and grants USB access.
#
# This does a volatile SRAM "Fast Configuration": the design runs immediately
# but is lost on power-cycle.  (For a persistent load, program the internal
# configuration flash from the Radiant Programmer GUI instead.)
set -euo pipefail

RADIANT="${RADIANT:-$HOME/lscc/radiant/2026.1}"
export bali_LICENSE_FILE="$RADIANT/license/license.dat"
export LM_LICENSE_FILE="$RADIANT/license/license.dat"
export LD_LIBRARY_PATH="$RADIANT/programmer/bin/lin64:$RADIANT/bin/lin64:${LD_LIBRARY_PATH:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # project root (parent of scripts/)
BIT="$ROOT/build/impl1/blink_impl1.bit"
XCF="$ROOT/build/blink.xcf"

[[ -f "$BIT" ]] || { echo "No bitstream -- run scripts/build.sh first."; exit 1; }

if ls /sys/bus/usb/drivers/ftdi_sio/*:1.0 >/dev/null 2>&1; then
  echo "The FT2232H is still held by ftdi_sio. Run:  sudo scripts/setup-usb.sh  (then re-plug USB)"; exit 1
fi

# JTAG chain-config file for pgrcmd.  Device data is fixed for LIFCL-33U;
# only the bitstream path changes, so we generate it here (keeps it portable).
cat > "$XCF" <<XCFEOF
<?xml version='1.0' encoding='utf-8' ?>
<!DOCTYPE ispXCF SYSTEM "IspXCF.dtd" >
<ispXCF version="R2026.1">
	<Chain>
		<Comm>JTAG</Comm>
		<Device>
			<SelectedProg value="TRUE"/>
			<Pos>1</Pos>
			<Vendor>Lattice</Vendor>
			<Family>LIFCL</Family>
			<Name>LIFCL-33U</Name>
			<IDCode>0x010f0043</IDCode>
			<PON>LIFCL-33U</PON>
			<Bypass><InstrLen>8</InstrLen><InstrVal>11111111</InstrVal><BScanLen>1</BScanLen><BScanVal>0</BScanVal></Bypass>
			<File>${BIT}</File>
			<MemoryType>Static Random Access Memory (SRAM)</MemoryType>
			<Operation>Fast Configuration</Operation>
			<Option><SVFVendor>JTAG STANDARD</SVFVendor><IOState>HighZ</IOState><Usercode>0x00000000</Usercode><AccessMode>Direct Programming</AccessMode></Option>
		</Device>
	</Chain>
	<ProjectOptions>
		<Program>SEQUENTIAL</Program>
		<Process>ENTIRED CHAIN</Process>
		<OperationOverride>No Override</OperationOverride>
		<StartTAP>TLR</StartTAP><EndTAP>TLR</EndTAP>
		<VerifyUsercode value="FALSE"/>
		<TCKDelay>30</TCKDelay>
	</ProjectOptions>
	<CableOptions>
		<CableName>USB2</CableName>
		<PortAdd>FTUSB-0</PortAdd>
	</CableOptions>
</ispXCF>
XCFEOF

echo ">> Programming LIFCL-33U (SRAM Fast Configuration)..."
"$RADIANT/programmer/bin/lin64/pgrcmd" -infile "$XCF"
echo ">> Done -- LED0 (D5, green) should be blinking (rate set by the counter tap in blink.v)."
