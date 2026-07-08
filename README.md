# Blinky — Lattice CrossLinkU-NX-33

A minimal, complete Verilog "hello world" for the **CrossLinkU-NX Evaluation
Board** (`LIFCL-33U-EVN`): blink one on-board LED at ~1 Hz. Zero to blinking
light with three commands.

- **Device:** `LIFCL-33U-9CTG104I` (FCCSP104)
- **Toolchain:** Lattice Radiant 2026.1
- **LED:** LED0 (green, ref **D5**) on FPGA ball **G6**
- **Clock:** the FPGA's on-chip oscillator — no external clock, no PLL, no IP

## Quick start

> **Prerequisite:** Lattice Radiant 2026.1. On **Ubuntu 26.04** it won't run out
> of the box (it exits silently with no window) — see
> [docs/radiant-on-ubuntu-26.04.md](docs/radiant-on-ubuntu-26.04.md) for the fix.

```bash
scripts/build.sh            # 1. synthesize -> build/impl1/blink_impl1.bit
sudo scripts/setup-usb.sh   # 2. one-time: give Radiant access to the USB cable
                            #    (then unplug/replug the board's MicroUSB)
scripts/program.sh          # 3. flash the board -> LED D5 blinks
```

That's it. (Set `RADIANT=/path/to/radiant` if yours isn't at
`~/lscc/radiant/2026.1`.)

## Layout

```
blink/
├── source/            # the design + constraints (all you really author)
│   ├── blink.v        #   on-chip oscillator → counter → LED
│   ├── blink.pdc      #   pin constraint: which ball `led` goes to + I/O standard
│   └── blink.sdc      #   clock timing constraint
├── scripts/           # automation
│   ├── build.tcl      #   the Radiant flow (synth → map → place&route → bitstream)
│   ├── build.sh       #   run the flow
│   ├── program.sh     #   flash the board over JTAG
│   └── setup-usb.sh   #   one-time USB-cable setup (root)
├── build/             # everything generated (git-ignored; created by build.sh)
├── README.md
└── .gitignore
```

Everything under `build/` (`impl1/`, `blink.rdf`, `blink.xcf`, …) is **generated**
and git-ignored — delete it anytime and `scripts/build.sh` recreates it.

## How it works

`blink.v` instantiates **`OSCD`**, the LIFCL-33U's on-chip high-frequency
oscillator. Its base is **450 MHz**, and `HFCLKOUT = 450 MHz / DIV`; the OSCD
`HF_CLK_DIV` string encodes `DIV − 1`, so `HF_CLK_DIV="12"` → DIV = 13 →
**~34.6 MHz**. A 32-bit counter divides that down and drives the LED from
`counter[24]` (full period = 2²⁵ clocks), giving a **~1.03 Hz** blink. Because
the clock comes from inside the FPGA, the design needs no board clock pin.

`blink.pdc` locks the `led` output to ball **G6** and sets the I/O standard.
`build.tcl` creates the project, runs the full flow, and writes the bitstream.
`program.sh` loads it over JTAG using the board's on-board FT2232H cable.

## Board-specific gotchas (worth knowing)

These are the non-obvious bits that make this board different from the larger
CrossLink-NX parts:

- **Oscillator is `OSCD`, not `OSCA`.** The LIFCL-33U uses OSCD (with extra
  `HFOUTCIBEN`/`REBOOT` inputs; `HF_OSC_EN` must be set `"ENABLED"`). OSCA is
  only for LIFCL-40/17 and fails to map here.
- **The LED sits in a 1.2 V bank (bank 3), which requires `LVCMOS12H`** — the
  "H" variant. Plain `LVCMOS12` is rejected by the mapper.
- **Bitstream needs IP-Evaluation mode on** (`bit_ip_eval=True` in `build.tcl`).
  Harmless — there's no licensed IP — but Radiant 2026.1 requires it for this
  device.
- **LED0/D5 is active-high** through transistor Q5, so driving `led` HIGH lights
  it directly. (Pin/bank facts: user guide FPGA-EB-02072-1.1, Table 7.1 +
  Figure 5.1.)
- **USB cable:** Linux's `ftdi_sio` grabs the FT2232H as a serial port, and its
  USB node is root-owned. `setup-usb.sh` (run once, as root) frees the JTAG
  interface and installs a udev rule so Radiant can reach it.

## Notes

- `program.sh` does a **volatile SRAM** load (blinks now, gone on power-cycle).
  For a persistent load, program the internal configuration flash from the
  Radiant Programmer GUI (`FLASH Erase,Program,Verify`).
- To change the blink rate, pick a different `counter` bit in `blink.v`
  (higher bit = slower). To use a different LED, change the ball in `blink.pdc`.
