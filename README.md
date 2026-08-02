# MasterLooter

MasterLooter is a loot and raid-management addon developed specifically for Project Ascension on the WoW 3.3.5a client.

It provides synchronized master-looter roll windows, authoritative rolls, direct loot assignment with trade fallback, SoftRes/HardRes, priorities, +1, boosted rolls, GDKP auctions, raid management, version checks, bag inspection, history, and import/export tools.

## Installation

Copy both folders into `Interface/AddOns/`:

- `MasterLooter`
- `MasterLooter_ItemData`

Players need the main addon for synchronized roll windows, but group members without it can participate through the announced public `/roll` commands. The loot master determines the OS range for each session; connected clients receive it automatically. The ItemData addon is optional.

Open the addon with `/ml` or `/masterlooter`.

## Images

Screenshots and branding assets will be added to [`assets/`](assets/) later.

## Development

```powershell
npx --yes --package fengari-node-cli fengari .\MasterLooter\Tests\TestHarness.lua
```

The current integration harness covers two isolated addon clients and 173 assertions across communication, queued, direct, chat-filtered, and relayed public group rolls, background loot capture, awards, trades, rules, GDKP, auctions, bag inspection, item data, and the compact Gargul-inspired roll layouts. `/ml rolldebug` opens a copyable diagnostics window exposing the raw roll event and its validation result for Ascension-specific diagnosis. Blizzard's native group-loot UI is deliberately outside the addon.

More details are available in [MasterLooter/README.md](MasterLooter/README.md).

The current implementation status and remaining expansion areas are documented in [FEATURE_STATUS.md](FEATURE_STATUS.md).
