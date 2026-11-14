# mac-like-windows

[Bahasa Indonesia](README.md) · **English**

A single [Hammerspoon](https://www.hammerspoon.org) script that makes macOS behave more like Windows. It is free, has no trial, and stays idle until a key or click triggers it.

## Features

| Feature | How to use it | macOS default |
|---|---|---|
| Click a Dock icon to hide the app | Click the icon of the app in front; click again to bring it back | Clicking the active app's icon does nothing |
| Per-window switcher (Alt-Tab) | Hold **Command**, press **Tab** (Shift-Tab goes back), release to select, **Escape** cancels | Command-Tab switches apps, so two Chrome windows are one entry |
| Switcher extras | While the panel is open: **Left / Right** move, a **click** selects, **W** closes the window, **Q** quits its app, **H** hides its app | Q and H exist; W and per-window selection do not |
| Screenshots go to the clipboard | Take a screenshot, then paste | Screenshots are only saved to a file |
| Enter opens in Finder | Select a file or folder, press **Enter** | Enter renames |
| F2 renames in Finder | Select a file, press **F2** | — |
| Delete trashes in Finder | Select a file, press **Delete** | Needs Command-Delete |
| Cut and paste files in Finder | **Command-X**, then **Command-V** in the destination | Finder has no cut for files |
| Show desktop (Win + D) | **Option-D**, again to restore | — |
| Open Finder (Win + R) | **Option-R** | — |
| Snap windows (Win + arrows) | **Control-Option-Left / Right** for half the screen, **Up** to maximize, **Down** to restore (or minimize if there is nothing to restore) | Needs the Window menu or Globe shortcuts |
| Green button maximizes | Click the green button to fill the screen, click again to restore | Enters full screen in a separate Space |

The switcher lists every window, including minimized windows and windows of hidden apps, and restores the one you pick. It shows app icons with each window's title underneath, not live previews, so it does not need Screen Recording permission.

The Finder keys only act while the file list has focus. While you are renaming a file, typing in the search field or answering a dialog, Enter, Delete and Command-X/V behave normally.

## Requirements

- macOS on Apple silicon or Intel
- [Hammerspoon](https://www.hammerspoon.org) 1.0 or later

Tested with Hammerspoon 1.1.1.

## Install

1. Install Hammerspoon:

   ```bash
   brew install --cask hammerspoon
   ```

2. Put the script in place. If you have no Hammerspoon config yet:

   ```bash
   mkdir -p ~/.hammerspoon && cp init.lua ~/.hammerspoon/init.lua
   ```

   If you already have a config, copy it under another name and load it from yours:

   ```bash
   cp init.lua ~/.hammerspoon/mac-like-windows.lua
   ```

   ```lua
   require("mac-like-windows")
   ```

3. Open Hammerspoon and grant it **Accessibility** access in System Settings → Privacy & Security → Accessibility. Nothing works without it.

4. Recommended macOS settings, so the result matches Windows more closely:

   ```bash
   defaults write com.apple.dock minimize-to-application -bool true && killall Dock
   ```

   ```bash
   defaults write com.apple.screencapture show-thumbnail -bool false && killall SystemUIServer
   ```

   The first makes minimized windows go into their app icon. The second removes the floating screenshot preview, which otherwise delays the file (and so the clipboard copy) by about five seconds.

The shortcuts become active about 15–20 seconds after login, once Hammerspoon has finished starting.

## Configuration

All options are in the `config` table at the top of `init.lua`. After editing, reload from the Hammerspoon console with `hs.reload()` or restart Hammerspoon.

| Option | Default | Meaning |
|---|---|---|
| `launchAtLogin` | `true` | Start Hammerspoon at login |
| `hideMenuIcon`, `hideDockIcon` | `true` | Hide Hammerspoon's own icons |
| `dockClickToHide` | `true` | Dock click hides the active app |
| `switcher.enabled` | `true` | Turn the window switcher on or off |
| `switcher.modifier` | `"cmd"` | `"cmd"` replaces the built-in Command-Tab; `"alt"` uses Option-Tab and keeps the built-in one |
| `switcher.iconSize` | `96` | Icon size in the switcher panel |
| `switcher.showAllTitles` | `true` | Title under every icon; `false` shows only the selected window's title, like macOS |
| `switcher.extraKeys` | `true` | Arrows, mouse click, W, Q and H in the panel |
| `screenshotToClipboard` | `true` | Copy new screenshots to the clipboard |
| `screenshotFolder` | `nil` | Folder to watch; `nil` follows the macOS screenshot location |
| `finder.enterOpens`, `f2Renames`, `deleteTrashes`, `cutPaste` | `true` | Individual Finder keys |
| `showDesktop` | `{ mods = { "alt" }, key = "d" }` | Show-desktop shortcut; `nil` disables it |
| `openFinder` | `{ mods = { "alt" }, key = "r" }` | Open-Finder shortcut; `nil` disables it |
| `snap.enabled`, `snap.mods` | `true`, `{ "ctrl", "alt" }` | Window snapping and its modifier keys |
| `greenButtonMaximizes` | `true` | Green button maximizes instead of full screen |
| `shortcutExcludedApps` | `{}` | Bundle IDs where the two global shortcuts are passed through |

### Notes on the defaults

- **Option is the Windows key.** On a Mac keyboard the Option key sits where the Windows key is, so Win + D becomes Option-D. This takes over the characters Option-D and Option-R normally type (`∂` and `®` on a US layout). Pick other shortcuts if you need those.
- **If you remapped your modifier keys**, set the shortcuts to what your keys actually send. For example, if your Option key sends Control, use `mods = { "ctrl" }` and add your terminal apps to `shortcutExcludedApps`, because Control-D and Control-R mean something there:

  ```lua
  showDesktop = { mods = { "ctrl" }, key = "d" },
  openFinder  = { mods = { "ctrl" }, key = "r" },
  shortcutExcludedApps = { "com.apple.Terminal", "com.microsoft.VSCode" },
  ```

- **Snap uses Control-Option, not Option alone**, because Option-Left and Option-Right already move the cursor by word in text.
- **To get real full screen**, hold any modifier key (for example Shift) while clicking the green button.
- **F2 on a MacBook** usually controls brightness, so press it together with Fn, or enable "Use F1, F2, etc. keys as standard function keys" in System Settings → Keyboard.
- **Delete moves files to the Trash.** It does not delete them permanently.

## Performance

At idle, Hammerspoon with this script uses about 0.0–0.1% CPU and 70–100 MB of memory on an 8 GB MacBook Air. Nothing polls in the background, apart from a ten-second check that event taps are still enabled.

## Turning it off

Quit Hammerspoon and macOS behaves as it did before. To remove it completely, delete `~/.hammerspoon/init.lua` and uninstall Hammerspoon.

## Limitations

- The switcher panel imitates the look of the built-in Command-Tab, but it is drawn by the script, so it has no blur effect.
- **Q in the switcher quits the app immediately**; an app with unsaved changes may still ask before closing.
- "Click the Dock icon to hide" applies to the frontmost app only, which is how the Windows taskbar behaves for the active window.
- Finder's desktop is not covered by the Enter and Delete keys in every case.

## License

[MIT](LICENSE)
