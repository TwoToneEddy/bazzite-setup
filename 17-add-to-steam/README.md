# 17 — Add to Steam

An **Add to Steam** entry on Dolphin's right-click menu for `.exe` files,
AppImages, shell scripts and `.desktop` launchers. It adds the file to Steam as a
non-Steam game.

```bash
./install.sh                    # or ../install-all.sh 17 - no sudo
```

## What it installs

| File | |
|---|---|
| `~/.local/share/kio/servicemenus/add-to-steam.desktop` | the menu entry. Executable, because Plasma 6 ignores a service menu that is not |

It runs `steamos-add-to-steam -ui <file>`. Bazzite ships that helper (it comes
from SteamOS) in `/usr/bin` but does not add a Dolphin menu entry for it. The
helper checks the file type, then opens `steam://addnonsteamgame/<path>`, which
starts Steam if it is not already running. `-ui` shows errors in a `kdialog`
instead of printing them to a terminal nobody can see.

The menu lists the same file types the helper accepts. `.msi` is left out on
purpose: the helper rejects it as "Unsupported file type".

## Verify

```bash
../status.sh 17
```

Close every Dolphin window and reopen it, then right-click an `.exe`. The entry
can show up under **Actions** instead of the top level.

## Traps

**A Windows `.exe` is added with no Proton.** In Steam, open the shortcut's
**Properties → Compatibility**, tick *Force the use of a specific Steam Play
compatibility tool*, and pick a Proton version. Use GE-Proton if you want HDR (see
`00-gaming-env`).

**Linux executables and scripts must have the executable bit set**, or the helper
refuses them with "Is the file executable?".
