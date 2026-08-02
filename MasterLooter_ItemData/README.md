# MasterLooter Item Data

This load-on-demand companion keeps a sparse, realm-observed item index. It does
not scan the Ascension ID range. Items are learned from real links and, when the
official Ascension AtlasLoot cache is present, its difficulty families are read
at runtime without copying the cache into this addon.

Public API: `MasterLooterItemData:Get`, `GetFamily`, `Search`, `LearnLink`.
