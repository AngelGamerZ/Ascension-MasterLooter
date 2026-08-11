# MasterLooter

> Loot distribution, public roll tracking, SoftRes, GDKP, raid tools, and trade assistance for **Project Ascension** on **World of Warcraft 3.3.5a**.

[![Latest beta](https://img.shields.io/github/v/release/AngelGamerZ/Ascension-MasterLooter?include_prereleases&label=latest%20beta&color=d4a017)](https://github.com/AngelGamerZ/Ascension-MasterLooter/releases)
![WoW client](https://img.shields.io/badge/WoW-3.3.5a-6f42c1)
![Target](https://img.shields.io/badge/Project-Ascension-2f855a)
![Languages](https://img.shields.io/badge/languages-English%20%7C%20Deutsch-277da1)

MasterLooter keeps loot distribution clear and visible for the entire group. Players with the addon receive a compact roll window, while players without it can participate through ordinary public `/roll` commands.

[Download the latest beta](https://github.com/AngelGamerZ/Ascension-MasterLooter/releases) · [Report a problem](https://github.com/AngelGamerZ/Ascension-MasterLooter/issues)

## Features

- Synchronized **MS / OS / Pass** roll sessions for parties and raids
- Public `/roll 100` tracking for MS and a loot-master-defined `/roll X` range for OS
- Participation for players who do not have MasterLooter installed
- Compact roll windows for the loot master and every participating addon user
- Direct item assignment through the normal master-loot system
- Several identical items awarded to different winners from one roll session
- Automatic trade initiation and item placement with manual final acceptance
- Manual `+1` marks, award history, SoftRes, HardRes, priorities, and boosted rolls
- GDKP sessions, auctions, pots, cuts, price lists, and gold tracking
- Raid management, bag inspection, PackMule rules, profiles, and import/export tools
- Complete German and English interface, including chat messages and announcements
- Automatic language selection based on the game client, with an English fallback

## Screenshots

Screenshots will be added here soon.

| Loot-master window | Participant roll window |
|---|---|
| <img width="300" height="300" alt="Screenshot 2026-08-10 214210" src="https://github.com/user-attachments/assets/1e5ab36c-3b27-47bf-bf9c-52c5242be652" /> | _Screenshot coming soon_ |

| Settings and tools | Trade assistant and history |
|---|---|
| <img width="300" height="300" alt="Screenshot 2026-08-11 225032" src="https://github.com/user-attachments/assets/88797ee1-1989-4411-b4db-ecd0738c6ba6" /> | <img width="300" height="300" alt="Screenshot 2026-08-11 225044" src="https://github.com/user-attachments/assets/f6752ff2-6b98-445c-95da-23fb93f76be6" /> |

## How a roll works

1. The loot master drags an item into MasterLooter or uses **CTRL + right-click** on a supported bag or loot slot.
2. The duration, note, and OS roll maximum are selected before starting the roll.
3. Addon users receive the participant window. Everyone else uses the announced public roll commands.
4. MS always uses `/roll 100`. OS uses the range chosen by the loot master, for example `/roll 99`.
5. Rolls appear in the loot-master window and the remaining time is announced automatically.
6. The loot master selects a player and awards the item. A separate `+1` button is available when the award should count toward the streak list.
7. If the same item dropped several times, additional winners can be selected from the original roll without starting another session.

## Players without the addon

MasterLooter does not require every raid member to install it.

| Function | With the addon | Without the addon |
|---|:---:|:---:|
| Receive the compact roll window | Yes | No |
| Roll through public `/roll` | Yes | Yes |
| Appear in the loot master's results | Yes | Yes |
| Receive an item through master loot | Yes | Yes |
| Receive trade reminders | Yes | Yes, by whisper |

## Loot distribution and trading

- The loot master selects a winner directly from the roll table
- Items still inside the loot window are assigned through the normal master-loot system
- Winners outside direct range receive a whisper asking them to trade the loot master
- MasterLooter can initiate the correct trade and place pending winner items into free trade slots
- The final trade acceptance always remains a manual confirmation
- Awards, pending deliveries, completed trades, and unresolved items remain visible in the history

## Multiple identical items

One roll session can distribute several copies of the same item:

- The original results remain visible after the first award
- Already awarded players are marked
- The loot master selects the next winner and awards the next copy
- No additional roll session is required

## SoftRes, rules, and the streak list

- SoftRes and HardRes with multiple reservations and notes
- BISBEARD RollFor Base64/JSON imports
- TMB, DFT, ClassicPR/CSV, RRobin, and manual priority lists
- Boosted rolls and configurable distribution rules
- A dedicated manual `+1` button for every player row
- Private self-service queries for current group members

Whisper the active loot master:

- `SR` — show your own SoftRes entries
- `SL` — show your own streak count

`+1` is never added automatically when an item is awarded or traded.

## GDKP and raid tools

- GDKP sessions with sales, pot, adjustments, and payment tracking
- Single or parallel auctions with minimum bids and bid increments
- Anti-snipe extensions and auction queues
- Player cuts, management cuts, price lists, and exports
- Raid overview, ready checks, group conversion, promotion, demotion, and removal
- Bag inspection between participating MasterLooter users
- Addon version and presence overview

## Languages

MasterLooter is available in:

- English
- Deutsch

On first use, the addon follows the language of the WoW client. Unsupported client languages automatically use English. The language can be changed at any time in **MasterLooter → General**.

## Announcement channels

The loot master selects the desired channel from a dropdown in the settings. Available choices include automatic selection, Raid Warning, Raid, Group, Say, and Yell. MasterLooter uses the selected channel for roll starts, reminders, countdowns, results, and other group information.

## Installation

1. Download the newest archive from [GitHub Releases](https://github.com/AngelGamerZ/Ascension-MasterLooter/releases).
2. Close the game client completely.
3. Extract these folders into your Ascension installation:

   ```text
   Interface/AddOns/MasterLooter
   Interface/AddOns/MasterLooter_ItemData
   ```

4. Enable **Load out of date AddOns** on the character screen if required.
5. Enter the game and use `/ml`.

`MasterLooter_ItemData` is optional and helps the addon remember custom Ascension item information.

When updating, always replace the complete addon folders instead of mixing files from different versions.

## Useful commands

| Command | Action |
|---|---|
| `/ml` | Open MasterLooter |
| `/ml master` | Open the loot-master window |
| `/ml roll <item link> [seconds]` | Start a roll directly |
| `/ml loot` | Open captured loot |
| `/ml softres` | Open SoftRes |
| `/ml rules` | Open rules and the streak list |
| `/ml trade` | Open pending trades |
| `/ml gdkpui` | Open GDKP |
| `/ml auction` | Open GDKP auctions |
| `/ml raid` | Open raid management |
| `/ml bags` | Open bag inspection |
| `/ml history` | Open award history |
| `/ml version` | Show addon versions |

Minimap shortcuts and normal WoW key bindings provide quick access to the most frequently used windows.

## Support

If something does not work as expected, include the MasterLooter version, your Ascension realm, and the copied output from `/ml debug` when opening a [GitHub issue](https://github.com/AngelGamerZ/Ascension-MasterLooter/issues).
