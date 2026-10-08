# Bleakfiber's Action Bars - Forever

[![Interface](https://img.shields.io/badge/Interface-16001-blue.svg)](https://github.com/Bleakfiber/BleakfibersActionBars-Forever)
[![Version](https://img.shields.io/badge/Version-1.1.0-brightgreen.svg)](https://github.com/Bleakfiber/BleakfibersActionBars-Forever/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Modular, minimalist standalone action bar suite for **World of Warcraft: Forever** (Interface 16001).

---

## Overview

Bleakfiber's Action Bars provides a streamlined, dark slate and gold action bar replacement with ElvUI-level customization, built-in numeric cooldown timers, cooldown pulse animations, spell activation proc glow borders, dedicated bags and totem bar support, full stance and modifier paging, an interactive quick keybinding overlay, and clean Blizzard art suppression.

## Architecture

- **`Core.lua`**: Main action bar engine, button skinning, pure GPU texture backdrops, mover overlay system, Blizzard art suppression, cooldown pulse, proc glow, and combat lockdown safeguards.
- **`UI.lua`**: Native Dark Slate & Gold options UI, widget factory, tabbed settings, and standalone fallback window.
- **`Config.lua`**: Database schema, reactive accessors, slash command parsing, and soft-linked Master Hub registration into `BleakfibersAddonConfig-Forever`.
- **`Libs/`**: Embedded fallback libraries for optional Ace3 and LibSharedMedia support.

## Key Features

- **Up to 15 Action Bars** with independent columns, counts, sizes, and padding.
- **Dedicated Bags Bar** with horizontal/vertical layouts and individual slot toggles.
- **Pet & Stance Bars** with class-aware smart default visibility, orientation controls, and Shaman Totem Bar & Paladin Aura support.
- **Cast on Key Down** toggle (`ActionButtonUseKeyDown`) for instant spell activation on button press.
- **Cooldown Pulse Animation** with subtle GPU icon expansion and flare when abilities ready.
- **Spell Activation Proc Glow** featuring tailored Dark Slate & Gold proc border overlays.
- **Micro Menu** supporting up to 20 buttons with custom grid layouts.
- **Extra Action & Vehicle Leave Buttons** with independent movers.
- **Interactive Quick Keybinder** (`/bab bind`) with hover binding and mousewheel support.
- **Unified Movers System** (`/bab movers`) with coordinate readouts.
- **Global Fade & Click-Through** toggles.
- **Cooldown Display & Colors** with 4 distinct thresholds.
- **Range & Usability Colors** with out-of-range icon desaturation.
- **Blizzard Art Suppression** removing gryphons, default backgrounds, and collapsing frame artifacts (`MicroMenu.BorderArt`).

## Slash Commands

- `/bab` or `/bfab`: Toggle options UI
- `/bab movers`: Toggle bar mover overlays
- `/bab bind`: Toggle quick keybind mode
- `/bab reset`: Reset mover positions

## License

MIT License. Designed and maintained by Bleakfiber.
