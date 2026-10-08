# Bleakfiber's Action Bars - Forever

**Bleakfiber's Action Bars** is a modular, high-performance standalone action bar suite engineered specifically for **World of Warcraft: Forever** (Interface 16001).

Built from the ground up to eliminate interface clutter, Bleakfiber's Action Bars replaces Blizzard's bulky action bar frames with clean, minimalist, pixel-perfect square buttons styled in the signature **Dark Slate & Gold** (`#141A21` / `#D1AE47`) BleakUI aesthetic. Featuring ElvUI-level customization, a lightning-fast visual quick keybinder, and zero required external dependencies, it gives you absolute control over your combat interface.

Runs 100% standalone out of the box, and automatically embeds into **Bleakfiber's Addon Config** when installed.

---

## Key Highlights

- **Zero Required External Dependencies**: Pure, lightweight native WoW Lua engine. Runs completely standalone or seamlessly leverages LibSharedMedia when present.
- **Comprehensive Bar Coverage**:
  - Up to **15 Action Bars** with configurable button counts, columns, sizes, and padding.
  - **Dedicated Bags Bar**: Independent, skinnable, movable container for character bags and keyring with custom horizontal/vertical layout, scale, alpha, and slot visibility toggles.
  - Dedicated **Pet Bar** and **Stance / Shapeshift Bar** with class-aware smart defaults, horizontal/vertical orientations, and Shaman Totem Bar & Paladin Aura support.
  - Flexible **Micro Menu** supporting up to 20 discovered micro buttons with customizable rows, columns, and dimensions.
  - **Extra Action Button** & **Vehicle Leave Button** with independent movers and layout toggles.
- **Visual Quick Keybinder (`/bab bind`)**:
  - Hover over any action, pet, stance, micro, or bag button and press any key, mouse button, or scroll wheel to bind immediately.
  - Press `ESC` while hovering to instantly unbind.
  - Includes character-specific bindings toggle, Discard, and Save options without ever opening Blizzard's keybinding menu.
- **Interactive Unified Movers (`/bab movers`)**:
  - Dedicated draggable mover overlays with coordinate readouts for every bar and element.
  - Fully integrated with the `Bleakfibers Addon Suite` Master Mover registry.
- **Complete Blizzard Art Suppression**:
  - Safely eliminates Blizzard gryphons, default action bar artwork, endcaps, and native containers.
  - Cleans up legacy collapsing frame artifacts (such as empty MicroMenu and BagsBar borders and backgrounds).
- **Class & Stance Paging**:
  - Full paging support for Druid shapeshift forms, Rogue stealth/shadow dance, Warrior stances, and Priest forms.
  - Modifier paging support (Shift, Ctrl, Alt).
  - Custom visibility macro drivers (e.g., `[combat] show; hide`, `[vehicleui] hide; show`) with instant presets.
- **Deep Combat & Aesthetic Fine-Tuning**:
  - **Cast on Key Down**: Toggle instant spell activation on button press down rather than release (`ActionButtonUseKeyDown`).
  - **Cooldown Pulse Animation**: High-performance GPU pulse effect that expands the icon and pulses a golden flare when abilities come off cooldown.
  - **Spell Activation Proc Glow**: Sleek Dark Slate & Gold proc border overlays for active reactive procs (`ActionButtonSpellAlertManager` / `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`).
  - **Global Fade**: Customizable resting alpha slider with immediate fade-in on mouseover or entering combat.
  - **Click-Through**: Pass mouse clicks directly through inactive bars to the 3D game world.
  - **Built-in Cooldown Numbers**: Numeric cooldown countdown with custom fonts, sizes, and 4 threshold colors (<3s, <60s, <1hr, days).
  - **Range & Usability Colors**: Configurable out-of-range, out-of-mana, and not-usable colors, plus icon desaturation.
  - **Typography Precision**: Independent font size sliders for Hotkeys, Stack Counts, and Macro Names.
  - **Lock ActionBars Toggle**: Instantly prevent dragging spells off bars during combat.
- **Dual-Mode Configuration**:
  - **Standalone Mode**: Draggable Dark Slate & Gold options window (`/bab`).
  - **Master Hub Integration**: Embeds directly into **`BleakfibersAddonConfig-Forever`** with full multi-profile synchronization.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/bab` or `/bfab` | Toggle options window |
| `/bab movers` | Toggle bar mover overlays (unlock / lock) |
| `/bab bind` or `/bab keybind` | Toggle interactive quick keybinding mode |
| `/bab reset` | Reset bar positions to defaults |
| `/bab standalone` | Open standalone options window |

---

## Installation

1. Download the latest release `.zip`.
2. Extract the archive into your World of Warcraft directory:
   `World of Warcraft\_classic_\Interface\AddOns\` (or Forever client directory).
3. Ensure the folder is named **`BleakfibersActionBars-Forever`**.
4. Log into the game and type `/bab` or `/bab movers` to start configuring!
