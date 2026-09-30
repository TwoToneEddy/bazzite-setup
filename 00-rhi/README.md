# 00-rhi — RHI, the ReShade HDR Installer

Clones [RHI](https://github.com/TwoToneEddy/RHI) (`linux_port` branch) to `~/RHI`,
builds it, and adds an application-menu entry (**RHI (Linux / Proton)**).

RHI is what installs RenoDX, Luma and ReShade per game, and it owns DLSS presets and
DLL versions — `00-gaming-env`'s `dlss` no longer does. It sits at `00`
because it depends on nothing else here.

```bash
./install.sh             # clone, build, menu entry; idempotent
DRY_RUN=1 ./install.sh
```

- The clone tries SSH (`git@github.com:TwoToneEddy/RHI.git`) and falls back to
  HTTPS when there is no SSH key yet, leaving `origin` pointing at SSH.
- The first build downloads a user-local .NET SDK, restores packages and runs the
  tests: allow several minutes and a network connection. Nothing is layered and
  nothing goes in `/usr`.
- An existing `~/RHI` is left alone — not pulled, not rebuilt. After a
  `git pull`, rebuild with `~/RHI/scripts/build-linux.sh`.
- Per game, RHI's own **Finish Steam setup** writes the launch options it needs.
