# Getting Lattice Radiant 2026.1 to Run on Ubuntu 26.04

**Status:** ✅ Working — GUI launches and is fully functional.
**Radiant version:** 2026.1.0.37.0 (installed at `~/lscc/radiant/2026.1`)

> Radiant is the toolchain this project builds with. On **Ubuntu 26.04** it does
> not run out of the box, and the failure is *silent* (the GUI exits 0 with no
> window), so it's miserable to debug from scratch. This is the fix.

---

## TL;DR

Radiant 2026.1 is **not officially supported** on Ubuntu 26.04 and does **not** run out-of-the-box.
Two manual fixes are required:

1. **Install missing Qt/XCB runtime libraries** (apt).
2. **Clear the executable-stack flag** on 8 bundled vendor libraries — modern glibc refuses to
   honor their `RWE` stack requirement, which silently prevented the GUI from loading.

After both, just run:

```bash
radiant
```

---

## Background / Symptom

- Make sure Radiant's `bin/lin64` is on your `PATH` (your shell rc usually sets this):
  ```bash
  export PATH="$PATH:$HOME/lscc/radiant/2026.1/bin/lin64"
  ```
  `which radiant` should then resolve to `~/lscc/radiant/2026.1/bin/lin64/radiant`.
- `radiant` is the official launcher **script** (a bash wrapper). It sources `radiant_env`
  (which sets `LD_LIBRARY_PATH`, `FOUNDRY`, `TCL_LIBRARY`, `LM_LICENSE_FILE`, and Ubuntu Qt
  workarounds) and then `exec`s the real GUI binary **`pnmain`**.
- **Symptom:** running `radiant` / `pnmain` exits immediately with **code 0**, no error, no
  window. It looks like nothing happened.

This is NOT a license, display, or Wayland problem (all of those check out — see Diagnostics).

---

## Installation (for reference)

Radiant installs from the vendor archive `2026.1.0.37.0_Radiant_lin.zip`:

```bash
unzip 2026.1.0.37.0_Radiant_lin.zip          # -> 2026.1.0.37.0_Radiant_lin.run (~6.4 GB)
chmod +x 2026.1.0.37.0_Radiant_lin.run
./2026.1.0.37.0_Radiant_lin.run              # Qt Installer Framework GUI wizard
#   Default install dir: ~/lscc/radiant/2026.1   (needs ~47 GB, install is ~48 GB)
#   Headless option also exists: ./...run --console  (or --prefix <dir>)
```

The installer itself is Qt-based and needs the **same XCB libs as Fix 1** — if the wizard
won't start with `libxkbcommon-x11.so.0: cannot open shared object file`, do Fix 1 first.

> ⚠️ **Reinstalling/updating re-triggers the exec-stack bug (Fix 2).** A fresh install lays
> down the vendor libs with the `RWE` flag again, so re-run the patcher afterward.

---

## Fix 1 — Missing system libraries (Qt / XCB / OpenGL)

The Qt-based installer and the app expect XCB/OpenGL libraries not present on a fresh 26.04.

```bash
sudo apt-get update
sudo apt-get install -y \
  libxkbcommon-x11-0 libxcb-cursor0 libxcb-icccm4 libxcb-image0 \
  libxcb-keysyms1 libxcb-render-util0 libxcb-xkb1 libopengl0
```

Verify nothing is still missing for the launcher binary:

```bash
ldd ~/lscc/radiant/2026.1/bin/lin64/pnmain 2>&1 | grep 'not found'
# (bundled libs like libQt6*, libbas*, libbaslu resolve at runtime via radiant_env's
#  LD_LIBRARY_PATH, so a bare `ldd` showing them "not found" is expected and harmless.)
```

---

## Fix 2 — Executable-stack incompatibility (the real blocker)

### Root cause

- `pnmain` is a thin bootstrapper. It `dlopen`s **`libpnmaindll.so`** (the actual GUI),
  which depends on **`libhwsecurity.so`**.
- `libhwsecurity.so` (and 7 other bundled libs) are marked `PT_GNU_STACK = RWE`, i.e.
  **"I require an executable stack"** — a common practice years ago.
- **Modern glibc (shipped in Ubuntu 26.04) refuses to grant an executable stack at
  `dlopen` time** and hard-fails:
  ```
  dlopen FAILED: libhwsecurity.so: cannot enable executable stack
                 as shared object requires: Invalid argument
  ```
  Older glibc silently complied. This is the crux — the OS security posture changed and
  these old vendor libs violate it.
- Because the `dlopen` failed, `pnmain` had no GUI module to run and quit cleanly (exit 0),
  which is why "nothing happened."

### The 8 affected libraries

```
~/lscc/radiant/2026.1/bin/lin64/libhwsecurity.so
~/lscc/radiant/2026.1/bin/lin64/libbassecmgr.so
~/lscc/radiant/2026.1/programmer/bin/lin64/libhwsecurity.so
~/lscc/radiant/2026.1/programmer/bin/lin64/libbassecmgr.so
~/lscc/radiant/2026.1/questasim/linux_x86_64/libvsimnotcl.so
~/lscc/radiant/2026.1/questasim/linux_x86_64/libvsim.so
~/lscc/radiant/2026.1/questasim/linux_x86_64/libmtipli.so
~/lscc/radiant/2026.1/synpbase/linux_a_64/lib/libzRtl.so
```

(The first two are the core GUI blockers; the `questasim/*` and `synpbase/*` ones were
patched too so ModelSim/Questa and Synplify won't hit the same wall.)

### The fix

Clear the `PF_X` (executable) bit on each library's `PT_GNU_STACK` header
(`RWE` `0x7` → `RW` `0x6`). These libs don't actually execute from the stack, so this is safe.

Ubuntu 26.04 **no longer ships the classic `execstack` tool**, and the packaged `patchelf`
lacked `--clear-execstack`, so a tiny version-independent ELF patcher is used — its full
source is in the **Appendix** at the end of this file. It makes a `*.execstack.bak` backup
of each file and is idempotent (safe to re-run).

To use it, save the Appendix script to a file (e.g. `/tmp/clear_execstack.py`), then run:

```bash
python3 /tmp/clear_execstack.py \
  ~/lscc/radiant/2026.1/bin/lin64/libhwsecurity.so \
  ~/lscc/radiant/2026.1/bin/lin64/libbassecmgr.so \
  ~/lscc/radiant/2026.1/programmer/bin/lin64/libhwsecurity.so \
  ~/lscc/radiant/2026.1/programmer/bin/lin64/libbassecmgr.so \
  ~/lscc/radiant/2026.1/questasim/linux_x86_64/libvsimnotcl.so \
  ~/lscc/radiant/2026.1/questasim/linux_x86_64/libvsim.so \
  ~/lscc/radiant/2026.1/questasim/linux_x86_64/libmtipli.so \
  ~/lscc/radiant/2026.1/synpbase/linux_a_64/lib/libzRtl.so
```

To find any exec-stack libs yourself (e.g. after an update):

```bash
find ~/lscc/radiant/2026.1 -name '*.so*' -type f 2>/dev/null | while read f; do
  readelf -l "$f" 2>/dev/null | grep -A1 GNU_STACK | grep -q RWE && echo "$f"
done
```

---

## Launching

```bash
radiant
```

- No `DISPLAY`, `LD_LIBRARY_PATH`, or `QT_QPA_PLATFORM` tweaking needed — the `radiant`
  wrapper + `radiant_env` handle all environment setup.
- Radiant bundles **only the xcb Qt platform plugin** (`bin/lin64/platforms/libqxcb.so`).
  On a Wayland session, Qt auto-falls back to xcb over XWayland, which works fine.
- Confirmed working: a window titled **"Lattice Radiant Software - Start Page"** appears.

---

## License

- Radiant requires a Lattice license file at `~/lscc/radiant/2026.1/license/license.dat`.
  A free **node-locked** license (`uncounted`) covers the GUI and core tools — request one
  from Lattice for your machine.
- It is node-locked to your NIC's MAC address (the FlexLM host ID). Find yours with:
  ```bash
  lmutil lmhostid            # FlexLM host ID (usually a NIC MAC)
  ```
  If you later swap network hardware and the NIC MAC changes, the license stops validating
  and you'll need a new one from Lattice.
- No license **server** is needed for the node-locked GUI features. (The `DAEMON saltd` /
  `mgcld INCREMENT` lines in a license only matter for ModelSim/Questa simulation.)

---

## ⚠️ Important: this can break again

The exec-stack patch is on-disk and permanent, **BUT any Radiant reinstall or update that
lays down fresh vendor libraries will re-introduce the `RWE` flag** — the GUI will silently
fail to launch again (exit 0, no window). If that happens, just re-run the patcher
(Fix 2) on the affected libraries.

The Qt/XCB apt packages (Fix 1) persist across Radiant updates and only need redoing on a
fresh OS install.

---

## Diagnostics reference (how it was traced)

Useful if it ever misbehaves again:

```bash
# 1. Watch what pnmain actually does before exiting (it reroutes its own logs, so stdout is empty):
strace -f -s 200 -o /tmp/pn.txt ~/lscc/radiant/2026.1/bin/lin64/pnmain
#    -> tail showed it searching every path for libpnmaindll, then exit_group(0)

# 2. Reproduce the real dlopen error directly:
#    (source radiant_env first so LD_LIBRARY_PATH is set)
python3 -c 'import ctypes; ctypes.CDLL("libpnmaindll.so")'
#    -> "cannot enable executable stack as shared object requires"

# 3. Check a lib's stack flag:
readelf -l <lib>.so | grep -A1 GNU_STACK      # RWE = bad, RW = fixed
```

Things that were verified NOT to be the problem: PATH, license validity, FlexLM host ID,
X11/display connectivity, Wayland vs xcb, missing bundled libs.

---

## Appendix — the exec-stack patcher script

Everything needed is contained in this one file. To use the patcher (see Fix 2), copy the
script below into a file such as `/tmp/clear_execstack.py`, then run it with the library
paths as arguments:

```python
#!/usr/bin/env python3
"""Clear the PF_X (executable) bit on an ELF's PT_GNU_STACK program header.
Works on 64-bit little-endian ELFs. Idempotent; backs up to <file>.execstack.bak."""
import struct, sys, shutil, os

PT_GNU_STACK = 0x6474e551
PF_X = 0x1

def patch(path):
    with open(path, 'rb') as f:
        data = bytearray(f.read())
    if data[:4] != b'\x7fELF':
        return f"SKIP (not ELF): {path}"
    if data[4] != 2 or data[5] != 1:
        return f"SKIP (not 64-bit LE): {path}"
    e_phoff     = struct.unpack_from('<Q', data, 0x20)[0]
    e_phentsize = struct.unpack_from('<H', data, 0x36)[0]
    e_phnum     = struct.unpack_from('<H', data, 0x38)[0]
    for i in range(e_phnum):
        off = e_phoff + i*e_phentsize
        if struct.unpack_from('<I', data, off)[0] == PT_GNU_STACK:
            flags = struct.unpack_from('<I', data, off+4)[0]
            if not (flags & PF_X):
                return f"OK (already clear): {path}"
            new = flags & ~PF_X
            struct.pack_into('<I', data, off+4, new)
            bak = path + '.execstack.bak'
            if not os.path.exists(bak):
                shutil.copy2(path, bak)
            with open(path, 'wb') as f:
                f.write(data)
            return f"PATCHED {path}  (flags {flags:#x} -> {new:#x})"
    return f"OK (no exec PT_GNU_STACK): {path}"

if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(patch(os.path.realpath(p)))
```
