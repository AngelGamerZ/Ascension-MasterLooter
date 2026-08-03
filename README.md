# MasterLooter

MasterLooter is a loot and raid-management addon developed specifically for Project Ascension on the WoW 3.3.5a client.

It provides synchronized master-looter roll windows, public rolls for players without the addon, persistent loot and auction queues, verified direct assignment, automatic filling of verified trades, a MS/OS item ledger, SoftRes/HardRes, priorities, +1, boosted rolls, GDKP, raid management, diagnostics, bag inspection, history, and safe import/export tools.

## Installation

Copy both folders into `Interface/AddOns/`:

- `MasterLooter`
- `MasterLooter_ItemData`

Players need the main addon for synchronized roll windows, but group members without it can participate through the announced public `/roll` commands. The loot master determines the OS range for each session; connected clients receive it automatically. The ItemData addon is optional.

Open the standalone overview and settings with `/ml` or `/masterlooter`. Use `/ml master`, `/lootmaster`, or `/mlmaster` to open the loot-master workflow directly. CTRL-right-clicking a legacy bag item opens the workflow with that item selected.

## Images

Screenshots and branding assets will be added to [`assets/`](assets/) later.

## Development

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\MasterLooter\Tests\Smoke.ps1
```

The suite covers two isolated addon clients plus focused negative and boundary tests for communication, public group rolls, recovery, loot slots, awards, trades, rules, the item ledger, GDKP, auctions, administration, manifests, syntax, and forbidden modern APIs. `/ml rolldebug` and `/ml commdebug` open copyable diagnostics windows. Blizzard's native group-loot UI remains outside the addon.

More details are available in [MasterLooter/README.md](MasterLooter/README.md).

The current implementation status and remaining expansion areas are documented in [FEATURE_STATUS.md](FEATURE_STATUS.md).
