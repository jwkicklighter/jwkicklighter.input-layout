# jwkicklighter.input-layout

Omarchy bar widget showing the active xkb keyboard layout **and variant**, with a flyout to pick the active layout and manage which layouts are enabled.

Unlike language-only indicators, this lists individual layouts such as English (US) QWERTY and English (Dvorak) as separate entries.

## Features

- Shows the current layout variant in the bar (e.g. `DV`, `US`, `CM`).
- Left-click opens a flyout listing enabled layouts; click one to activate it.
- Right-click or scroll wheel cycles to the next layout; middle-click cycles back.
- The flyout's gear button switches to a manage view where you can toggle which layouts are active (persisted to `~/.local/state/omarchy/plugins/jwkicklighter.input-layout/config.json`).
- The manage view has a search field to find and add any layout or variant installed on the system (Dvorak, Colemak, QWERTY, and others).

## Requirements

- Omarchy (Hyprland + Quickshell shell)
- `hyprctl` (from `hyprland`)
- `xkbcli` (from `libxkbcommon`)

No extra packages are installed. The plugin applies layouts at runtime with `hyprctl eval` and does not edit `~/.config/hypr/` unless you choose layouts in the flyout.

## Install

```sh
omarchy plugin add https://github.com/jwkicklighter/jwkicklighter.input-layout.git --enable
```

It is placed in the center bar section by default. Move it with:

```sh
omarchy bar move jwkicklighter.input-layout --section right
```

## Usage

Click the bar label to open or close the flyout. Press Escape to close it.

Use the gear to add layouts. Search for `dvorak`, `qwerty`, `colemak`, or a language name.

## Configure

Enabled layouts are stored in `~/.local/state/omarchy/plugins/jwkicklighter.input-layout/config.json`:

```json
{ "version": 1, "enabled": ["us(dvorak)", "us"] }
```

Manage them from the flyout's gear view — no manual editing required.

```sh
omarchy bar move jwkicklighter.input-layout --section center
```

## Remove

```sh
omarchy plugin remove jwkicklighter.input-layout
```

This removes the plugin code but leaves persisted state in `~/.local/state/omarchy/plugins/jwkicklighter.input-layout/`. Delete that directory to fully reset.

## License

MIT
