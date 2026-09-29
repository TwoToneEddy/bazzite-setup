---
description: Walk through setting this machine up one component at a time, with a status check between each.
---

You are running the `bazzite-setup` wizard. Take the user through this repository
one component at a time. Do not batch it, and do not run `install-all.sh` with no
arguments unless they explicitly ask for everything at once.

Argument (optional): `$ARGUMENTS` — a component number such as `05`, or `resume`,
or empty. Empty or `resume` means "carry on from wherever the machine is up to".

## Before you start

Read `AGENTS.md` if it is not already in context. Its **Bazzite policy** and **HDR
policy** sections are binding: this is an immutable Fedora Atomic system, `dnf` is
not the package manager, `/etc` is per-deployment, and you never reboot on your own
initiative.

## Step 1 — orient, then show the user where they are

Run both, and show the user the output:

```bash
./status.sh
./preflight.sh --brief
```

`status.sh` says which components are done. `preflight.sh --brief` prints nothing
when the hardware matches the recorded profile; anything it does print is a value
some component hardcodes, and it names the file to edit.

Then tell them, in a short list: what this repo covers (the thirteen components, one
line each — take the descriptions from `README.md`, do not invent them), which are
already `ok`, and which need work. If `preflight.sh` reported differences, say that
adaptation comes before installation.

## Step 2 — pick the next component

If `$ARGUMENTS` names one, go there. Otherwise take the first component that is not
`ok`, in numeric order. Components depend only on lower numbers, so numeric order
is dependency order. `00`–`03` are stage 1 and need nothing layered; if the user
only wants the basics, stop after `03`. `04` layers packages and needs a reboot
before `05`, `07` and `08` can work.

Ask the user to confirm before each component, and let them skip. A skipped
component is a legitimate outcome — `absent` is not a failure.

## Step 3 — for each component, in this order

1. **Say what it does and what it will touch.** Read its `README.md` first. If it
   has a `files/system` tree, say that it needs `sudo`.
2. **Adapt it if preflight flagged it.** Edit inside `NN-*/files/`, never the live
   file — the installer copies from `files/` onwards, so an edit to the live file is
   lost on the next run.
3. **Dry run, and show the user:** `DRY_RUN=1 ./install-all.sh NN`
4. **Install:** `./install-all.sh NN`
5. **Verify:** `./status.sh NN`. Do not call it done because the installer exited 0
   — a component can install perfectly and do nothing.
6. **Hand back anything a script cannot do**, quoting the installer's own warning
   rather than paraphrasing it. The likely ones: layering packages needs a reboot
   (`04`); the CoolerControl password if one was set in its GUI (`07`); activating
   the undervolt, which you must **not** do yourself (`08`); arranging the panel
   (`09`).

Then move to the next component.

## Step 4 — when the list is done

```bash
./reference/health-check.sh
```

Then give the user the short list of things only they can check, because they need
a keyboard and a game running:

- launch a game, press `/`, confirm the overlay appears with the GPU rows populated
- press Pause/Break — screens blank, any input brings them back
- click each display-profile launcher
- left-click the DLSS tray icon and confirm the icon changes state

## Rules while running this

- Never activate the GPU undervolt. Report `current_profile` and the command; the
  decision is the user's.
- Never edit `plasma-org.kde.plasma.desktop-appletsrc` while plasmashell is
  running. `09-taskbar` prints the three commands; use those.
- Never reboot, and never enable `rpm-ostree` layering silently.
- If a check disagrees with the hardware, suspect the check. Two bugs in this
  repo's own scripts were exactly that.
- Report honestly: installed-and-verified, installed-but-unverified with the
  reason, or deliberately left to the user. Quote failures rather than summarising
  them.
