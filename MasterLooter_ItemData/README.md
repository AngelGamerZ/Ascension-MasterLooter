# MasterLooter Item Data

This load-on-demand companion keeps a sparse, realm-observed WotLK 3.3.5a item
index. It does not scan arbitrary item-ID ranges. Items are learned from real
links and, when a compatible AtlasLoot family cache is present, difficulty
families are read at runtime without copying the cache into this addon.

Public API: `MasterLooterItemData:Get`, `GetFamily`, `Search`, `LearnLink`.
