# Bleakfiber's Action Bars - Forever

[![Interface](https://img.shields.io/badge/Interface-16001%20(WoW%20Forever)-0078D7.svg?style=flat-square)](https://github.com/Bleakfiber/BleakfibersActionBars-Forever)
[![Release](https://img.shields.io/badge/Release-v1.1.4-ffd100.svg?style=flat-square)](https://github.com/Bleakfiber/BleakfibersActionBars-Forever/releases)
[![License](https://img.shields.io/badge/License-Source--Available-crimson.svg?style=flat-square)](LICENSE.md)
[![Dependencies](https://img.shields.io/badge/Dependencies-Zero%20External-2ea44f.svg?style=flat-square)](https://github.com/Bleakfiber/BleakfibersActionBars-Forever)
[![Suite](https://img.shields.io/badge/Suite-Bleakfiber's%20Addon%20Suite-8a2be2.svg?style=flat-square)](https://github.com/Bleakfiber)

**Bleakfiber's Action Bars** is a modular, high-performance, standalone action bar suite crafted specifically for **World of Warcraft: Forever** (Interface 16001).

Engineered from the ground up as a lightweight, pixel-perfect replacement for the default Blizzard action bar system, it delivers bespoke **Dark Slate & Gold** visual styling alongside advanced combat features: 10 independent movable action bars, a dedicated skinnable Bags and Keyring container, Shaman Totem and Paladin Aura/Stance bars, instant Cast on Key Down activation, cooldown pulse animations, shiny golden proc activation glows, an integrated hover keybinder, and seamless synchronization with the **Bleakfiber Addon Suite**.

Runs **100% standalone out of the box** with zero required third-party libraries or addons.

---

## 📑 Table of Contents

- [Key Highlights](#-key-highlights)
- [Feature Showcase](#-feature-showcase)
  - [1. Comprehensive 10-Bar Architecture](#1-comprehensive-10-bar-architecture)
  - [2. Dedicated Bags Bar & Keyring Container](#2-dedicated-bags-bar--keyring-container)
  - [3. Class Stance, Shapeshift & Totem Bars](#3-class-stance-shapeshift--totem-bars)
  - [4. Cooldown Pulse Animation & Proc Overlays](#4-cooldown-pulse-animation--proc-overlays)
  - [5. Cast on Key Down Responsiveness](#5-cast-on-key-down-responsiveness)
  - [6. Visual Hover Keybinder](#6-visual-hover-keybinder)
  - [7. Master Mover Mode & Profile Sync](#7-master-mover-mode--profile-sync)
- [Interactive Controls & Mouse Shortcuts](#-interactive-controls--mouse-shortcuts)
- [Configuration Guide](#-configuration-guide)
- [Slash Commands Reference](#-slash-commands-reference)
- [Architecture & File Overview](#-architecture--file-overview)
- [Installation Guide](#-installation-guide)
- [Bleakfiber Addon Suite Ecosystem](#-bleakfiber-addon-suite-ecosystem)
- [License & Support](#-license--support)

---

## 🌟 Key Highlights

* **Pure Standalone Power**: Zero external dependencies required. Embedded libraries (`Ace3`, `LibSharedMedia-3.0`) ensure complete stability out of the box.
* **10 Independent Bars**: Bar 1 (Main Action Bar), Bars 2–5, Pet Bar, Stance/Shapeshift Bar, Totem Bar, Micro Menu Bar, and Dedicated Bags Bar.
* **Dedicated Bags & Keyring Container**: Freely movable and scalable container housing your Backpack, 4 character bags, and Keyring with Blizzard Layout hijacking immunity.
* **Shaman Totem & Paladin Aura Support**: Fully integrated Totem Bar with customizable orientation (horizontal/vertical), slot padding, and active duration timers.
* **Cooldown Pulse Animation**: Visual burst and pulse animation over action button icons the instant abilities finish their cooldowns.
* **Spell Activation Proc Glows**: Golden proc overlay borders that illuminate when reactive abilities (Overpower, Revenge, Execute, etc.) become usable.
* **Cast on Key Down**: Instant spell activation on button press (`ActionButtonUseKeyDown`) rather than button release for maximum responsiveness.
* **Visual Hover Keybinder**: Quickly assign or unassign keybindings by hovering over any action button and pressing your desired key combination.
* **Non-Destructive Profile Capture**: Instant profile synchronization with `BleakfibersAddonConfig-Forever` that captures active settings upon creating a new profile instead of resetting to defaults.

---

## 🎯 Feature Showcase

### 1. Comprehensive 10-Bar Architecture
Take complete control over your interface layout:
- **Bars 1 through 5**: Full 12-button action bars with independent horizontal/vertical orientation, button count (1–12), column counts, button sizing, and padding.
- **Pet Action Bar**: Dedicated 10-button pet bar with auto-hiding when no pet is summoned.
- **Micro Menu**: Compact, customizable bar housing Blizzard game menu buttons.
- **Button Grid Visibility**: Toggle between always-visible empty button slots and clean contextual fading.
- **Range & Mana Tinting**: Visual out-of-range red desaturation and out-of-mana blue tinting.

### 2. Dedicated Bags Bar & Keyring Container
An independent container for inventory management:
- Houses the Backpack, Bag 1 through Bag 4, and the classic Keyring button in a unified frame.
- Fully movable via mover mode with configurable scale, button spacing, and orientation.
- **Blizzard Layout Hijacking Protection**: Hardened against Blizzard internal layout overrides to ensure bag buttons never jump back to screen bottom-center when opening configuration menus.

### 3. Class Stance, Shapeshift & Totem Bars
Tailored support for every class mechanic:
- **Stance & Shapeshift Bar**: Automatic handling for Warrior stances, Druid shapeshift forms, Rogue stealth, and Paladin auras.
- **Shaman Totem Bar**: Configurable totem bar with horizontal or vertical orientation, custom totem element order, and active duration timers.

### 4. Cooldown Pulse Animation & Proc Overlays
Never miss a critical combat window:
- **Cooldown Pulse**: Subtle, high-contrast flash/pulse centered on the action button the moment a cooldown completes.
- **Proc Glows**: Shiny golden proc activation borders highlighting procs, spell activations, and combo conditions.

### 5. Cast on Key Down Responsiveness
Eliminate click-release latency:
- Toggles `ActionButtonUseKeyDown` to fire spells and abilities the millisecond a key is depressed.
- Configurable per-profile with zero macro reconfiguration required.

### 6. Visual Hover Keybinder
Effortlessly configure keybindings on the fly:
- Enter Keybind Mode with `/bfb bind` or `/kb`.
- Hover over any button, press any key or combination (`Shift+Q`, `Ctrl+1`, `Mouse4`), and the binding is instantly saved.
- Hover and press `Escape` to unbind.

### 7. Master Mover Mode & Profile Sync
Full integration into the Bleakfiber suite:
- **Global Mover Coordination**: Integrated with `BleakfibersAddonConfig-Forever`. When BAC is installed, ActionBars automatically defers to the global `/bac mover` mode.
- **Non-Destructive Profiles**: New profiles capture current active configurations rather than resetting bars to factory defaults.

---

## 🖱️ Interactive Controls & Mouse Shortcuts

| Action | Description |
| :--- | :--- |
| **`/bfb` or `/bar`** | Opens the ActionBars graphical configuration options panel. |
| **`/bfb mover`** | Toggles mover overlays to drag and reposition all 10 action bars. |
| **`/bfb bind` or `/kb`** | Enters interactive hover-to-bind keybinding mode. |
| **Hover + Key in Bind Mode** | Binds the hovered action button to the pressed key combination. |
| **Hover + Escape in Bind Mode** | Unbinds any existing keybind on the hovered button. |
| **`/bfb reset`** | Resets all action bar positions back to default layout. |

---

## 🛠️ Configuration Guide

Access settings via `/bfb`, `/bar`, `/actionbars`, or through the master hub in `/bac`:

1. **General Settings**: Master addon toggle, Cast on Key Down activation, cooldown pulse toggle, proc glow toggle, button grid visibility, and button styling.
2. **Bar Configurations (Bars 1–5)**: Independent toggles, number of buttons (1–12), column layout, icon scaling (50%–200%), padding, and visibility conditions.
3. **Pet & Stance Bars**: Orientation (horizontal/vertical), scale, button padding, and auto-hide behaviors.
4. **Totem Bar**: Orientation, element ordering, button scaling, and duration timer displays.
5. **Bags Bar**: Scale, horizontal/vertical orientation, slot spacing, and keyring toggle.
6. **Micro Menu**: Button scale, orientation, and visibility options.
7. **Profiles**: Create, copy, delete, and switch configurations backed by AceDB-3.0 with suite-wide synchronization.

---

## ⌨️ Slash Commands Reference

| Command | Description |
| :--- | :--- |
| `/bfb` | Opens the graphical configuration panel. |
| `/bar` or `/actionbars` | Alternative shortcuts to open the configuration panel. |
| `/bfb mover` | Toggles on-screen mover frames for all action bars. |
| `/bfb bind` or `/kb` | Toggles visual hover keybinding mode. |
| `/bfb reset` | Resets all bar positions back to factory defaults. |
| `/bfb profile <name>` | Switches active profile or prints current profile name. |

---

## 🏗️ Architecture & File Overview

```
BleakfibersActionBars-Forever/
├── BleakfibersActionBars-Forever.toc  # Addon metadata, SavedVariables & dependencies
├── Config.lua                         # AceDB configuration schema, defaults & BAC registry
├── Core.lua                           # Bar lifecycle, secure action buttons, movers, events & logic
├── UI.lua                             # Configuration GUI panels & options tables
├── Media/
│   ├── Media.lua                      # LibSharedMedia font & texture registration
│   └── Fonts/                         # Embedded Nata Sans, Orbitron, and Roboto Condensed fonts
└── Libs/                              # Embedded Ace3 & LibSharedMedia-3.0 libraries
```

---

## 💾 Installation Guide

1. Download the latest release package from the official [Releases](https://github.com/Bleakfiber/BleakfibersActionBars-Forever/releases) page.
2. Exit World of Warcraft completely.
3. Extract the downloaded archive (`BleakfibersActionBars-Forever 1.1.4.zip`).
4. Copy the `BleakfibersActionBars-Forever` folder into your WoW client AddOns directory:
   ```
   World of Warcraft/_forever_/Interface/AddOns/BleakfibersActionBars-Forever
   ```
5. Launch World of Warcraft, log into your character, and type `/bfb` to configure your bars.

---

## 🌌 Bleakfiber Addon Suite Ecosystem

Bleakfiber's Action Bars integrates seamlessly with the entire **Bleakfiber Addon Suite**:

* **[Bleakfiber's Addon Config](https://github.com/Bleakfiber/BleakfibersAddonConfig-Forever)**: Centralized master configuration hub with unified mover mode and cross-addon profile syncing.
* **[Bleakfiber's Quest Tracker](https://github.com/Bleakfiber/BleakfibersQuestTracker-Forever)**: High-performance quest tracker with 360° Wayfinder navigation and interactive quest item buttons.
* **[Bleakfiber's Maps](https://github.com/Bleakfiber/BleakfibersMaps-Forever)**: Lightweight world map and minimap customization suite.
* **[Bleakfiber's Unit Toggles](https://github.com/Bleakfiber/BleakfibersUnitToggles-Forever)**: Instant Blizzard unit name & nameplate toggle suite with 20 CVar presets.

---

## 📜 License & Support

* **License**: Restricted - Source-Available (All Rights Reserved, No Derivatives). See [LICENSE.md](LICENSE.md) for full terms.
* **Issues & Feedback**: Encounter a bug or have a feature request? Open an issue on our [GitHub Issue Tracker](https://github.com/Bleakfiber/BleakfibersActionBars-Forever/issues).
* **Author**: Bleakfiber
