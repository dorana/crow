local MOD = Crow or LibStub("AceAddon-3.0"):GetAddon("Crow", true)
if not MOD then
    MOD = LibStub("AceAddon-3.0"):NewAddon("Crow", "AceConsole-3.0", "AceEvent-3.0")
    Crow = MOD
end

function MOD:InitializeProfile()
    local defaults = {
        profile = {
            AuraGroups = {
                ["Player Buffs"] = {
                    enabled = true,
                    unit = "player",
                    filter = "HELPFUL",
                    anchor = "CENTER",
                    x = 0,
                    y = 100,
                    showAsBars = false,
                    showDuration = true,
                    durationPosition = "INSIDE",
                    fontSize = 12,
                    showCooldownClock = true,
                    sortMethod = "ADDED_TIME",
                    sortDirection = "ASCENDING",
                    showDummyAuras = false,
                    customAuras = {},
                    maxAuras = 10,
                    aurasPerRow = 6,
                    iconSize = 40,
                    spacing = 4,
                    barWidth = 160,
                    barHeight = 20,
                    flowDirection = 1,
                    lists = {}, -- { { name = "ListName", filterType = "whitelist" }, ... }
                },
                ["Player Debuffs"] = {
                    enabled = true,
                    unit = "player",
                    filter = "HARMFUL",
                    anchor = "CENTER",
                    x = 0,
                    y = 150,
                    showAsBars = false,
                    showDuration = true,
                    durationPosition = "INSIDE",
                    fontSize = 12,
                    showCooldownClock = true,
                    sortMethod = "ADDED_TIME",
                    sortDirection = "ASCENDING",
                    showDummyAuras = false,
                    customAuras = {},
                    maxAuras = 10,
                    aurasPerRow = 6,
                    iconSize = 40,
                    spacing = 4,
                    barWidth = 160,
                    barHeight = 20,
                    flowDirection = 1,
                    lists = {},
                },
            },
            SpellLists = {}, -- ["ListName"] = { [spellId] = true, ... }
        }
    }
    
    self.db = LibStub("AceDB-3.0"):New("CrowDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
end
