# MasterLooter

> Loot distribution, public roll tracking, raid tools, SoftRes, GDKP, and trade assistance for **Project Ascension** on the **World of Warcraft 3.3.5a client**.

[![Latest beta](https://img.shields.io/github/v/release/AngelGamerZ/Ascension-MasterLooter?include_prereleases&label=latest%20beta&color=d4a017)](https://github.com/AngelGamerZ/Ascension-MasterLooter/releases)
![WoW client](https://img.shields.io/badge/WoW-3.3.5a-6f42c1)
![Target](https://img.shields.io/badge/Project-Ascension-2f855a)
![Status](https://img.shields.io/badge/status-public%20beta-c97a12)

MasterLooter is a clean-room addon built specifically around Ascension's legacy client and custom item environment. It supports players both **with and without the addon**: connected players receive a compact roll window, while everyone else can participate through ordinary public `/roll` commands.

[Download the latest beta](https://github.com/AngelGamerZ/Ascension-MasterLooter/releases) · [Feature status](FEATURE_STATUS.md) · [Implementation matrix](IMPLEMENTATION_PARITY.md) · [Report a problem](https://github.com/AngelGamerZ/Ascension-MasterLooter/issues)

## Highlights

- Synchronized **MS / OS / Pass** roll sessions for party and raid groups
- Public `/roll 100` tracking for MS and a loot-master-defined `/roll X` range for OS
- Full participation for players who do not have MasterLooter installed
- Compact Gargul-inspired participant and loot-master workflows designed for 3.3.5a
- Direct assignment through Blizzard's native master-loot API
- Multiple identical drops awarded to different winners from a **single roll session**
- Automatic trade initiation and item placement with deliberately manual trade acceptance
- SoftRes, HardRes, priority lists, boosted rolls, manual `+1`, and award history
- GDKP sessions, auctions, pots, cuts, price lists, and gold ledgers
- Raid management, bag inspection, PackMule rules, imports, profiles, and diagnostics

## Screenshots

Screenshots will be added here as the visual design is finalized. The table already defines the intended image locations.

| Loot-master workflow | Participant roll window |
|---|---|
| _Add `assets/screenshots/loot-master-window.png`_ | _Add `assets/screenshots/participant-roll-window.png`_ |

| Settings and tools | Trade assistant and history |
|---|---|
| _Add `assets/screenshots/settings-and-tools.png`_ | _Add `assets/screenshots/trade-and-history.png`_ |

When the files are ready, replace the placeholder text with:

```html
<img src="assets/screenshots/loot-master-window.png" alt="MasterLooter loot-master window" width="100%">
```

## How a roll works

1. The loot master selects an item by dragging it into MasterLooter or using **CTRL + right-click** on a supported bag or loot slot.
2. The loot master chooses the duration, note, and OS roll maximum, then starts the session.
3. Players with MasterLooter receive the compact participant window. Players without it use the announced public roll commands.
4. MS always uses `/roll 100`. OS uses the range chosen by the loot master, for example `/roll 99`.
5. MasterLooter tracks system roll messages, updates the winner table, and posts periodic time reminders followed by a one-second countdown from ten.
6. The loot master clicks a player row and chooses **Award item**. The separate `+1` button remains a deliberate manual action.
7. If several identical items dropped, the original rolls remain visible. The loot master can immediately select the next winner and award the next native loot slot without rerolling.

## Addon and non-addon participation

| Capability | With MasterLooter | Without MasterLooter |
|---|:---:|:---:|
| Receive the participant roll window | Yes | No |
| Roll through public `/roll` | Yes | Yes |
| Appear in the loot master's roll table | Yes | Yes |
| Receive an awarded item through native master loot | Yes | Yes |
| Receive trade reminders | Yes | Yes, by whisper |
| Use synchronized rules, bag inspection, and version checks | Yes | No |

## Loot and roll management

### Roll sessions

- MS, OS, and Pass with a host-controlled OS maximum
- Party and raid system-roll parsing, including localized 3.3.5a messages
- Addon acknowledgements, sender validation, replay protection, and session recovery
- Periodic announcements and a final ten-second countdown
- Automatic participant-window closure when the timer expires
- Queue-safe handling of consecutive items and delayed events from older sessions

### Item interaction

- Drag and drop from supported item sources
- CTRL + right-click from Blizzard/Ascension loot slots and bag items
- Shift-hover equipment comparison in the participant roll window
- Native modified item clicks, including CTRL-click dressing-room preview and chat-link insertion
- Runtime support for Ascension custom item links through the optional item-data companion

### Sequential identical drops

One roll session can distribute several copies of the same item:

- Every original roll remains in the table
- Awarded players are visibly marked and cannot receive the same roll's next copy accidentally
- Each award uses its own native loot slot and delivery identity
- In-flight slots are reserved independently, so the next winner can be selected immediately
- Ascension slot compaction and reused numeric slot positions are handled without starting a new roll

## Awards, trades, and the item ledger

- Direct awards are verified through the native `LOOT_SLOT_CLEARED` event
- If direct assignment is unavailable, the exact item can be taken for a controlled trade fallback
- Winners outside interaction range receive a whisper asking them to trade the loot master
- In range, MasterLooter can initiate the correct trade automatically
- Pending winner items are placed into free trade slots after the correct partner is verified
- Addon-to-addon coordination uses a validated handshake, but recipients do not need the addon
- **Trade acceptance and final completion always remain manual**
- Persistent loot lifecycle states cover dropped, acquired, awarded, traded, disenchanted, lost, and unresolved items
- Delivery identities prevent duplicate history and ledger entries

## Rules and distribution systems

| System | Included capabilities |
|---|---|
| SoftRes / HardRes | Limits, notes, multiple reservations, ranking integration, consumption, and self-service lookup |
| Priority lists | TMB, DFT, ClassicPR/CSV, RRobin, and manual priorities |
| `+1` / streak list | Manual row button, audit trail, synchronization, and player self-service lookup |
| Boosted rolls | Persistent points, ranking integration, and trusted synchronization |
| AutoRoll | MS/OS/Pass recommendations while the protected public roll remains a user click |
| PackMule | Quality, binding, target, disenchanter, exception, and round-robin rules |

`+1` is never increased by an award or completed trade. The loot master must click the dedicated `+1` button for every mark that should count.

## SoftRes and external imports

- BISBEARD RollFor Base64/JSON imports, including multiple SoftRes and HardRes entries
- TMB, DFT, ClassicPR/CSV, and RRobin priority imports
- Optional LootReserve listener integration for active reservations
- Validated MasterLooter import/export format with backups and restore support
- CSV/TSV exports for award history, priorities, and the streak ledger

Raid members can privately query the active master looter:

- Whisper `SR` to see their own SoftRes entries
- Whisper `SL` to see their own manual streak count

These queries disclose only the requester's data and only work for current group members while the recipient is the active master looter.

## GDKP and raid administration

- Persistent GDKP sessions, sales, pot, adjustments, and payment states
- Single and parallel auctions with minimum bids, increments, queues, and anti-snipe extensions
- Gold ledger, weighted cuts, management cuts, price lists, and export/import
- Raid overview, ready check, conversion, promotion, demotion, removal, and explicit group actions
- Bag inspection between participating MasterLooter clients
- Version overview and addon-presence tracking

## Installation

1. Download the newest archive from [GitHub Releases](https://github.com/AngelGamerZ/Ascension-MasterLooter/releases).
2. Close the game client completely.
3. Extract these folders into your Ascension installation:

   ```text
   Interface/AddOns/MasterLooter
   Interface/AddOns/MasterLooter_ItemData
   ```

4. Enable **Load out of date AddOns** on the character screen if your Ascension build requires it.
5. Enter the game and run `/ml`.

`MasterLooter` is the main addon. `MasterLooter_ItemData` is optional and provides a realm-, locale-, and client-aware cache for custom Ascension item information.

When upgrading, replace the complete addon folders. Mixing Lua files from different beta versions can produce misleading version and module errors.

## Commands and shortcuts

| Command | Action |
|---|---|
| `/ml` | Open the standalone overview and settings hub |
| `/ml master` | Open the loot-master workflow |
| `/lootmaster` or `/mlmaster` | Open the loot-master workflow directly |
| `/ml roll <item link> [seconds]` | Start a roll directly |
| `/ml loot` | Open the captured-loot window |
| `/ml sr <player> <item ID>` | Set a SoftRes entry |
| `/ml plus <player> [value]` | Change a player's manual `+1` value |
| `/ml gdkp start\|sale\|finish` | Control a GDKP session |
| `/ml auction`, `/ml raid`, `/ml bags` | Open additional administration tools |
| `/ml version` | Show build and protocol versions |
| `/ml debug` | Open the copyable full-addon diagnostic window |
| `/ml debug clear` | Clear previous trace data and start a fresh diagnostic capture |
| `/ml rolldebug` | Open roll-message diagnostics |
| `/ml commdebug` | Open communication diagnostics |
| `/ml tooltipdebug` | Open the tooltip and loot-event timeline |
| `/ml sync <player>` | Request a trusted rules snapshot |
| `/ml trust <player>` | Select a trusted rules-data sender |

Minimap shortcuts provide direct access to settings, imports, history, SoftRes, and the loot-master window. In-game key bindings are also available through WoW's normal key-binding menu.

## Diagnostics and reliability

MasterLooter includes copyable diagnostics for the complete addon rather than only individual symptoms:

- Loaded Lua and TOC versions
- Module initialization and runtime errors
- Active roll session and public-roll parser state
- Loot capture, queue, native click hooks, awards, and trades
- Communication trace with bounded packet history
- Tooltip ownership and event timeline
- UI window state and stored positions

The test harness covers isolated multi-client communication plus focused boundary tests for rolls, loot slots, sequential identical awards, trades, imports, GDKP, rules, UI geometry, tooltips, manifests, Lua parsing, and forbidden modern APIs.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\MasterLooter\Tests\Smoke.ps1
```

## Important 3.3.5a limitations

- Protected actions such as public rolls and master-loot assignment require a real user click.
- The client does not expose a fully authoritative remaining trade timer; displayed trade windows are estimates.
- Other players' bags cannot be inspected unless their client also runs MasterLooter and permits the exchange.
- The item-data companion learns real runtime links and does not claim to contain every custom item from every Ascension season.
- Automated tests cannot replace a final two-client live test on the target Ascension realm.

## Project documentation

- [Current feature status](FEATURE_STATUS.md)
- [Implementation and parity matrix](IMPLEMENTATION_PARITY.md)
- [Ascension 3.3.5a feasibility analysis](ASCENSION_335A_MACHBARKEITSANALYSE.md)
- [Clean-room reverse-engineering report](REVERSE_ENGINEERING_REPORT.md)
- [Detailed addon documentation](MasterLooter/README.md)
- [Live test checklist](MasterLooter/LIVE_TEST_CHECKLIST.md)
- [Changelog](MasterLooter/CHANGELOG.md)

## Development status

MasterLooter is currently distributed as a **public beta**. Core functionality is implemented, but releases should still be validated with multiple real clients on the target Ascension realm before raid use.

This project is an independent clean-room implementation for Ascension 3.3.5a. It does not copy Gargul source code, assets, or network protocols.
