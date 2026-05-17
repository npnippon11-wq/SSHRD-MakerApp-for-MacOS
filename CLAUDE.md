# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

SSHRD Maker is a macOS GUI application (v1.0 beta, macOS 11+) that wraps the [SSHRD_Script](https://github.com/verygenericname/SSHRD_Script) to create and boot SSH ramdisks on checkm8 devices (Apple A7–A11, iOS 13.1–16.3). The repo ships a pre-compiled `.app` bundle — there is no buildable source in this repo.

## Repository Layout

```
SSHRD Maker.app/Contents/
  MacOS/SSHRD Maker          # compiled Swift/macOS GUI binary (no source here)
  Resources/tools/
    ramdisk/                 # core SSH ramdisk script and its binaries
      sshrd.sh               # main script — the primary file to edit
      Darwin/                # macOS binaries called by sshrd.sh
      Linux/                 # Linux binaries (not used on macOS)
      sshtars/               # ssh.tar.gz, t2ssh.tar.gz, atvssh.tar.gz injected into ramdisk
      other/                 # bootlogo.im4p, SHSH stubs
      shsh/                  # per-CPID SHSH blobs used for img4tool signing
    euphoria_scripts/        # helper binaries and scripts called by the GUI
      detectNormalDevice.sh  # detects a normally-booted iOS device via ideviceinfo
      detectRecDevice.sh     # detects a device in DFU/recovery via irecovery
      enterrecovery.sh       # kicks a normal device into recovery
      exitrecovery.sh        # exits recovery with irecovery -n
```

## sshrd.sh — Script Operations

The script is invoked from `ramdisk/` with the working directory set there (it `cd`s to `$(dirname "$0")`). All binary calls use `"$oscheck"/<binary>` where `$oscheck` is `Darwin` or `Linux`.

| Command | Effect |
|---|---|
| `./sshrd.sh <iOS version>` | Download firmware, decrypt/patch iBSS+iBEC+kernel, build ramdisk |
| `./sshrd.sh boot` | Boot a previously built ramdisk from `sshramdisk/` |
| `./sshrd.sh ssh` | Open SSH session via iproxy tunnel (password: `alpine`) |
| `./sshrd.sh reboot` | Reboot the device over SSH |
| `./sshrd.sh reset` | Factory-erase device (sets `oblit-inprogress`) |
| `./sshrd.sh dump-blobs` | Dump onboard SHSH blobs to Desktop |
| `./sshrd.sh clean` | Delete the built `sshramdisk/` directory |

Ramdisk artifacts are written to `ramdisk/sshramdisk/`. Logs are written to the `ramdisk/` directory as `HH:MM:SS-YYYY-MM-DD-Darwin-<kernel>.log`.

## Key Binaries (Darwin/)

| Binary | Role |
|---|---|
| `gaster` | checkm8 exploit — `pwn`, `reset`, `decrypt` |
| `iBoot64Patcher` | Patches iBSS/iBEC for custom boot args |
| `KPlooshFinder` | Finds kernel patch offsets |
| `kerneldiff` | Generates binary patch (`.bpatch`) between raw and patched kernel |
| `img4` | IMG4 pack/unpack |
| `img4tool` | Extracts IM4M from SHSH for signing |
| `pzb` | Partial-zip: downloads individual files from a remote IPSW |
| `irecovery` | DFU/recovery mode communication |
| `iproxy` | USB→TCP proxy for SSH tunneling |
| `gtar` | GNU tar for extracting sshtars onto the ramdisk HFS+ image |

## Device-Specific Behaviour

- **T2 (CPID `0x8012`, model `j42dap` is AppleTV):** uses `t2ssh.tar.gz`, 127 MB ramdisk.
- **AppleTV (model `j42dap`):** uses `atvssh.tar.gz`.
- **All others:** uses `ssh.tar.gz`, 210 MB ramdisk.
- **iOS ≥ 17 / Darwin major ≥ 17:** trustcache is required and injected as `trustcache.img4`.
- **iOS ≥ 26 (future):** darwin_major formula shifts from `+6` to `-1`.
- **Darwin major ≥ 24:** iBSS/iBEC decryption uses `img4 -i` directly instead of `gaster decrypt`.

## Installation / Quarantine Fix

After unzipping or cloning, remove macOS quarantine before the app will run:
```sh
sudo xattr -r com.apple.quarantine /Applications/SSHRD\ Maker.app
```
