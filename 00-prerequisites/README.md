# 00 — Prerequisites

Two kernel modules and four layered packages. Nothing else in `bazzite-setup`
works without these, so this goes first.

## What it installs

| File | Why |
|---|---|
| `/etc/modules-load.d/nct6775.conf` | the board's Super I/O sensor chip (NCT6799D). Without it the machine has **no motherboard fan sensors at all** — which is why fan control appeared impossible before. Not autoloaded on this board. |
| `/etc/modules-load.d/i2c-dev.conf` | userspace I2C access (`/dev/i2c-*`). The per-pin current monitor talks to the Astral's sensor chip over the GPU's own I2C bus and cannot see it without this. |

## Layered packages

These are not files, so the installer only checks for them and tells you the
command; layering triggers a reboot and that is not something an installer should
do behind your back.

```bash
sudo rpm-ostree install coolercontrol lact liquidctl gamescope-session-steam
sudo systemctl reboot
```

| Package | For |
|---|---|
| `coolercontrol` | fan control (`07`) |
| `lact` | GPU undervolt and the voltage reading the overlay uses (`08`, `02`) |
| `liquidctl` | lets CoolerControl see AIO pumps |
| `gamescope-session-steam` | the SteamOS-style Game Mode session at the login screen |

MangoHud and GOverlay ship with Bazzite already. The snapshot of what was layered
when this was built is in `../reference/layered-packages.txt`.

## Install

```bash
./install.sh            # needs sudo
```

The modules load on the next boot. To get them now without rebooting:

```bash
sudo modprobe nct6775
sudo modprobe i2c-dev
```

## Traps

**`/etc` is per-deployment on rpm-ostree.** Both these files live in `/etc`, so
they exist only on the deployment you installed them on. After an
`rpm-ostree rollback` or `upgrade`, re-run this installer — otherwise the fan
sensors and the per-pin monitor quietly stop working and the cause is not obvious.

**`nct6775` vs `nct6775-platform`.** The module that binds on this board is
`nct6775`; the file has a comment explaining the board ID it matches. If `sensors`
shows no `nct6799` section after a `modprobe`, the BIOS has taken the chip for
itself and needs `acpi_enforce_resources=lax` on the kernel command line —
this board did not, but a BIOS update could change that.
