local MOD = Crow or LibStub("AceAddon-3.0"):GetAddon("Crow", true)
if not MOD then
    MOD = LibStub("AceAddon-3.0"):NewAddon("Crow", "AceConsole-3.0", "AceEvent-3.0")
    Crow = MOD
end
CrowOptions = {}
local CrowOptions = CrowOptions

local acereg = LibStub("AceConfigRegistry-3.0")
local acedia = LibStub("AceConfigDialog-3.0")

local selectedSpellList = nil
local selectedAuraGroup = nil

local UpdateAuraGroupListOptions
local UpdateAuraGroupCustomAuraOptions

local function RefreshAuraGroupOptions()
    if UpdateAuraGroupListOptions then UpdateAuraGroupListOptions() end
    if UpdateAuraGroupCustomAuraOptions then UpdateAuraGroupCustomAuraOptions() end
    if acereg and acereg.GetOptionsTable and acereg:GetOptionsTable("Crow") then
        acereg:NotifyChange("Crow")
    end
end

-- Settings listed here only require a lightweight reconfigure of existing frames.
-- Anything NOT in this table triggers a full MOD:UpdateContainers() redraw.
local noRedrawSettings = {
    durationOffset = true,
    barWidth = true,
    barHeight = true,
}

-- Central setter for aura group options.
-- Writes the value and decides between a soft refresh and a full redraw.
local function CommitGroupSetting(key, value)
    if not selectedAuraGroup
        or not MOD.db or not MOD.db.profile
        or not MOD.db.profile.AuraGroups[selectedAuraGroup]
    then return end
    MOD.db.profile.AuraGroups[selectedAuraGroup][key] = value
    if noRedrawSettings[key] then
        MOD:SoftRefreshGroup(selectedAuraGroup)
    else
        MOD:UpdateContainers(selectedAuraGroup)
    end
end

local options = {
    type = "group",
    name = "Crow",
    childGroups = "tab",
    args = {
        general = {
            type = "group",
            name = "General",
            order = 1,
            args = {
                info = {
                    type = "description",
                    name = "Crow — a modernized aura monitoring addon.\nConfigure aura groups in the 'Aura Groups' tab and spell lists in the 'Spells' tab.",
                    order = 1,
                    fontSize = "medium",
                },
                toggleMove = {
                    type = "execute",
                    name = function() return MOD.isMoving and "Lock Groups" or "Move Groups" end,
                    desc = "Toggle anchor frames to move aura groups on your screen",
                    func = function() MOD:ToggleMoveMode() end,
                    order = 2,
                },
            },
        },
        auraGroups = {
            type = "group",
            name = "Aura Groups",
            order = 2,
            args = {
                toggleMove = {
                    type = "execute",
                    name = function() return MOD.isMoving and "Lock Groups" or "Move Groups" end,
                    desc = "Toggle anchor frames to move aura groups on your screen",
                    func = function() MOD:ToggleMoveMode() end,
                    order = 1,
                },
                selectGroup = {
                    type = "select",
                    name = "Select Aura Group",
                    values = function()
                        local v = {}
                        if MOD.db and MOD.db.profile and MOD.db.profile.AuraGroups then
                            for k in pairs(MOD.db.profile.AuraGroups) do v[k] = k end
                        end
                        return v
                    end,
                    get = function() return selectedAuraGroup end,
                    set = function(_, v) selectedAuraGroup = v; RefreshAuraGroupOptions() end,
                    order = 2,
                },
                newGroup = {
                    type = "input",
                    name = "New Aura Group Name",
                    set = function(_, v)
                        if v ~= "" and not MOD.db.profile.AuraGroups[v] then
                            MOD.db.profile.AuraGroups[v] = {
                                enabled = true,
                                unit = "player",
                                filter = "HELPFUL",
                                anchor = "CENTER",
                                x = 0, y = 0,
                                flowDirection = (MOD.FlowDirection and MOD.FlowDirection.RIGHTDOWN) or 1,
                                showAsBars = false,
                                showMiniBar = false,
                                miniBarPosition = "BELOW",
                                showDuration = true,
                                durationOffset = 0,
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
                                rowSpacing = 4,
                                barWidth = 160,
                                barHeight = 20,
                                barIconPosition = "LEFT",
                                lists = {},
                            }
                            selectedAuraGroup = v
                            MOD:UpdateContainers()
                            RefreshAuraGroupOptions()
                        end
                    end,
                    order = 3,
                },
                deleteGroup = {
                    type = "execute",
                    name = "Delete Group",
                    func = function()
                        if selectedAuraGroup then
                            MOD.db.profile.AuraGroups[selectedAuraGroup] = nil
                            selectedAuraGroup = nil
                            MOD:UpdateContainers()
                            RefreshAuraGroupOptions()
                        end
                    end,
                    disabled = function() return not selectedAuraGroup end,
                    order = 4,
                },
                groupSettings = {
                    type = "group",
                    name = "Group Settings",
                    inline = true,
                    hidden = function()
                        return not selectedAuraGroup or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups or not MOD.db.profile.AuraGroups[selectedAuraGroup]
                    end,
                    args = {
                        enabled = {
                            type = "toggle",
                            name = "Enabled",
                            get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].enabled end,
                            set = function(_, v) 
                                CommitGroupSetting("enabled", v)
                            end,
                            order = 1,
                        },
                        showDummyAuras = {
                            type = "toggle",
                            name = "Show Dummy Auras",
                            desc = "Preview dummy auras for this group to assist with UI layout and configuration",
                            get = function()
                                if not selectedAuraGroup or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups or not MOD.db.profile.AuraGroups[selectedAuraGroup] then
                                    return false
                                end
                                return MOD.db.profile.AuraGroups[selectedAuraGroup].showDummyAuras or false
                            end,
                            set = function(_, v)
                                CommitGroupSetting("showDummyAuras", v)
                            end,
                            order = 1.5,
                        },
                        displayFormat = {
                            type = "select",
                            name = "Display Format",
                            desc = "Choose how auras in this group are displayed",
                            values = { ICONS = "Icons", BARS = "Bars" },
                            get = function()
                                return MOD.db.profile.AuraGroups[selectedAuraGroup].showAsBars and "BARS" or "ICONS"
                            end,
                            -- displayFormat maps to the showAsBars bool
                            set = function(_, v)
                                CommitGroupSetting("showAsBars", v == "BARS")
                            end,
                            order = 2,
                        },
                        unitGroup = {
                            type = "group",
                            name = "Unit",
                            inline = true,
                            order = 3,
                            args = {
                                unit = {
                                    type = "input",
                                    name = "Unit",
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].unit end,
                                    set = function(_, v) 
                                        CommitGroupSetting("unit", v)
                                    end,
                                    order = 1,
                                },
                                filter = {
                                    type = "select",
                                    name = "Filter",
                                    values = {
                                        HELPFUL = "Buffs (HELPFUL)",
                                        HARMFUL = "Debuffs (HARMFUL)",
                                        RAID = "Raid",
                                    },
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].filter or "HELPFUL" end,
                                    set = function(_, v)
                                        CommitGroupSetting("filter", v)
                                    end,
                                    order = 2,
                                },
                            },
                        },
                        locationGroup = {
                            type = "group",
                            name = "Location",
                            inline = true,
                            order = 4,
                            args = {
                                anchor = {
                                    type = "select",
                                    name = "Anchor Point",
                                    values = {
                                        CENTER = "Center",
                                        TOP = "Top",
                                        BOTTOM = "Bottom",
                                        LEFT = "Left",
                                        RIGHT = "Right",
                                        TOPLEFT = "Top Left",
                                        TOPRIGHT = "Top Right",
                                        BOTTOMLEFT = "Bottom Left",
                                        BOTTOMRIGHT = "Bottom Right",
                                    },
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].anchor or "CENTER" end,
                                    set = function(_, v)
                                        CommitGroupSetting("anchor", v)
                                        if MOD.isMoving and MOD.anchors[selectedAuraGroup] then
                                            MOD:UpdateAnchorPosition(selectedAuraGroup)
                                        end
                                    end,
                                    order = 1,
                                },
                                flowDirection = {
                                    type = "select",
                                    name = "Flow Direction",
                                    desc = "Direction in which auras grow in the layout",
                                    values = {
                                        [(MOD.FlowDirection and MOD.FlowDirection.RIGHTDOWN) or 1] = "Down and Right",
                                        [(MOD.FlowDirection and MOD.FlowDirection.RIGHTUP) or 2] = "Up and Right",
                                        [(MOD.FlowDirection and MOD.FlowDirection.LEFTDOWN) or 3] = "Down and Left",
                                        [(MOD.FlowDirection and MOD.FlowDirection.LEFTUP) or 4] = "Up and Left",
                                    },
                                    get = function()
                                        local val = MOD.db.profile.AuraGroups[selectedAuraGroup].flowDirection
                                        if val == nil then return (MOD.FlowDirection and MOD.FlowDirection.RIGHTDOWN) or 1 end
                                        if type(val) == "string" then
                                            local map = {
                                                RIGHTDOWN = (MOD.FlowDirection and MOD.FlowDirection.RIGHTDOWN) or 1,
                                                RIGHTUP = (MOD.FlowDirection and MOD.FlowDirection.RIGHTUP) or 2,
                                                LEFTDOWN = (MOD.FlowDirection and MOD.FlowDirection.LEFTDOWN) or 3,
                                                LEFTUP = (MOD.FlowDirection and MOD.FlowDirection.LEFTUP) or 4,
                                            }
                                            return map[val:upper()] or 1
                                        end
                                        return val
                                    end,
                                    set = function(_, v) 
                                        CommitGroupSetting("flowDirection", v)
                                    end,
                                    order = 2,
                                },
                                x = {
                                    type = "input",
                                    name = "X Coordinate",
                                    desc = "X offset from anchor point (updates in real time when dragged in Move mode)",
                                    get = function() return tostring(math.floor((MOD.db.profile.AuraGroups[selectedAuraGroup].x or 0) + 0.5)) end,
                                    set = function(_, v)
                                        local num = tonumber(v)
                                        if num then
                                            CommitGroupSetting("x", num)
                                            if MOD.isMoving and MOD.anchors[selectedAuraGroup] then
                                                MOD:UpdateAnchorPosition(selectedAuraGroup)
                                            end
                                        end
                                    end,
                                    order = 3,
                                },
                                y = {
                                    type = "input",
                                    name = "Y Coordinate",
                                    desc = "Y offset from anchor point (updates in real time when dragged in Move mode)",
                                    get = function() return tostring(math.floor((MOD.db.profile.AuraGroups[selectedAuraGroup].y or 0) + 0.5)) end,
                                    set = function(_, v)
                                        local num = tonumber(v)
                                        if num then
                                            CommitGroupSetting("y", num)
                                            if MOD.isMoving and MOD.anchors[selectedAuraGroup] then
                                                MOD:UpdateAnchorPosition(selectedAuraGroup)
                                            end
                                        end
                                    end,
                                    order = 4,
                                },
                            },
                        },
                        layoutGroup = {
                            type = "group",
                            name = "Layout",
                            inline = true,
                            order = 5,
                            args = {
                                iconSize = {
                                    type = "range",
                                    name = "Icon Size",
                                    desc = "Size of each aura icon in pixels",
                                    min = 1,
                                    max = 256,
                                    step = 1,
                                    hidden = function() return selectedAuraGroup and MOD.db.profile.AuraGroups[selectedAuraGroup] and MOD.db.profile.AuraGroups[selectedAuraGroup].showAsBars end,
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].iconSize or 40 end,
                                    set = function(_, v)
                                        CommitGroupSetting("iconSize", v)
                                    end,
                                    order = 1,
                                },
                                barWidth = {
                                    type = "range",
                                    name = "Bar Width",
                                    desc = "Width of each aura bar in pixels",
                                    min = 40,
                                    max = 1000,
                                    step = 1,
                                    hidden = function() return not selectedAuraGroup or not MOD.db.profile.AuraGroups[selectedAuraGroup] or not MOD.db.profile.AuraGroups[selectedAuraGroup].showAsBars end,
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].barWidth or 160 end,
                                    set = function(_, v)
                                        CommitGroupSetting("barWidth", v)
                                    end,
                                    order = 2,
                                },
                                barHeight = {
                                    type = "range",
                                    name = "Bar Height",
                                    desc = "Height of each aura bar in pixels",
                                    min = 10,
                                    max = 100,
                                    step = 1,
                                    hidden = function() return not selectedAuraGroup or not MOD.db.profile.AuraGroups[selectedAuraGroup] or not MOD.db.profile.AuraGroups[selectedAuraGroup].showAsBars end,
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].barHeight or 20 end,
                                    set = function(_, v)
                                        CommitGroupSetting("barHeight", v)
                                    end,
                                    order = 3,
                                },
                                barIconPosition = {
                                    type = "select",
                                    name = "Bar Icon Position",
                                    desc = "Show the aura icon to the Left, Right, or not at all",
                                    values = {
                                        LEFT  = "Left",
                                        RIGHT = "Right",
                                        NONE  = "None",
                                    },
                                    hidden = function()
                                        return not selectedAuraGroup
                                            or not MOD.db.profile.AuraGroups[selectedAuraGroup]
                                            or not MOD.db.profile.AuraGroups[selectedAuraGroup].showAsBars
                                    end,
                                    get = function()
                                        return string.upper(MOD.db.profile.AuraGroups[selectedAuraGroup].barIconPosition or "LEFT")
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("barIconPosition", v)
                                    end,
                                    order = 4,
                                },
                                maxAuras = {
                                    type = "range",
                                    name = "Max Auras",
                                    desc = "Maximum total number of auras to display",
                                    min = 1,
                                    max = 32,
                                    step = 1,
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].maxAuras or 10 end,
                                    set = function(_, v)
                                        CommitGroupSetting("maxAuras", v)
                                    end,
                                    order = 5,
                                },
                                aurasPerRow = {
                                    type = "range",
                                    name = "Auras per Row",
                                    desc = "Maximum number of auras per row/line before wrapping (stride)",
                                    min = 1,
                                    max = 32,
                                    step = 1,
                                    get = function() 
                                        local val = MOD.db.profile.AuraGroups[selectedAuraGroup].aurasPerRow
                                        if val ~= nil then return val end
                                        return MOD.db.profile.AuraGroups[selectedAuraGroup].showAsBars and 1 or 6
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("aurasPerRow", v)
                                    end,
                                    order = 6,
                                },
                                spacing = {
                                    type = "range",
                                    name = "Icon Spacing",
                                    desc = "Horizontal gap between aura icons within a row",
                                    min = 0, max = 50, step = 1,
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].spacing or 4 end,
                                    set = function(_, v) CommitGroupSetting("spacing", v) end,
                                    order = 7,
                                },
                                rowSpacing = {
                                    type = "range",
                                    name = "Row Spacing",
                                    desc = "Vertical gap between rows of auras",
                                    min = 0, max = 50, step = 1,
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].rowSpacing or MOD.db.profile.AuraGroups[selectedAuraGroup].spacing or 4 end,
                                    set = function(_, v) CommitGroupSetting("rowSpacing", v) end,
                                    order = 8,
                                },
                                sortMethod = {
                                    type = "select",
                                    name = "Sort Method",
                                    desc = "Method used to sort auras in this group",
                                    values = {
                                        ADDED_TIME = "Default (Added Time)",
                                        NAME = "Alphabetical",
                                        EXPIRATION = "Remaining Time",
                                    },
                                    get = function()
                                        return (MOD.db.profile.AuraGroups[selectedAuraGroup] and MOD.db.profile.AuraGroups[selectedAuraGroup].sortMethod) or "ADDED_TIME"
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("sortMethod", v)
                                    end,
                                    order = 9,
                                },
                                sortDirection = {
                                    type = "select",
                                    name = "Sort Direction",
                                    desc = "Direction to sort auras in this group",
                                    values = {
                                        ASCENDING = "Ascending",
                                        DESCENDING = "Descending",
                                    },
                                    get = function()
                                        return (MOD.db.profile.AuraGroups[selectedAuraGroup] and MOD.db.profile.AuraGroups[selectedAuraGroup].sortDirection) or "ASCENDING"
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("sortDirection", v)
                                    end,
                                    order = 10,
                                },
                            },
                        },
                        durationGroup = {
                            type = "group",
                            name = "Duration",
                            inline = true,
                            order = 6,
                            args = {
                                showDuration = {
                                    type = "toggle",
                                    name = "Show Duration",
                                    desc = "Show duration text on auras",
                                    get = function()
                                        local val = MOD.db.profile.AuraGroups[selectedAuraGroup].showDuration
                                        if val == nil then return true end
                                        return val
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("showDuration", v)
                                    end,
                                    order = 1,
                                },
                                durationOffset = {
                                    type = "range",
                                    name = "Duration Text Position",
                                    desc = "Vertical offset from the icon center. 0 = centered inside the icon, positive = up, negative = down.",
                                    min = -150,
                                    max = 150,
                                    step = 1,
                                    hidden = function()
                                        if not selectedAuraGroup or not MOD.db.profile.AuraGroups[selectedAuraGroup] then return true end
                                        local group = MOD.db.profile.AuraGroups[selectedAuraGroup]
                                        if group.showAsBars then return true end
                                        local val = group.showDuration
                                        if val == nil then return false end
                                        return not val
                                    end,
                                    get = function()
                                        return MOD.db.profile.AuraGroups[selectedAuraGroup].durationOffset or 0
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("durationOffset", v)
                                    end,
                                    order = 2,
                                },
                                showMiniBar = {
                                    type = "toggle",
                                    name = "Show Mini Bar",
                                    desc = "Add a small duration bar below or above each aura icon (icon mode only)",
                                    hidden = function()
                                        return not selectedAuraGroup
                                            or not MOD.db.profile.AuraGroups[selectedAuraGroup]
                                            or MOD.db.profile.AuraGroups[selectedAuraGroup].showAsBars
                                    end,
                                    get = function()
                                        return MOD.db.profile.AuraGroups[selectedAuraGroup].showMiniBar or false
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("showMiniBar", v)
                                    end,
                                    order = 3,
                                },
                                miniBarPosition = {
                                    type = "select",
                                    name = "Mini Bar Position",
                                    desc = "Whether the mini bar appears below or above the icon",
                                    values = { BELOW = "Below", ABOVE = "Above" },
                                    hidden = function()
                                        if not selectedAuraGroup or not MOD.db.profile.AuraGroups[selectedAuraGroup] then return true end
                                        local g = MOD.db.profile.AuraGroups[selectedAuraGroup]
                                        return g.showAsBars or not g.showMiniBar
                                    end,
                                    get = function()
                                        return string.upper(MOD.db.profile.AuraGroups[selectedAuraGroup].miniBarPosition or "BELOW")
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("miniBarPosition", v)
                                    end,
                                    order = 4,
                                },
                                showCooldownClock = {
                                    type = "toggle",
                                    name = "Show Cooldown Clock",
                                    desc = "Show the progression spinner on the buff icon",
                                    hidden = function()
                                        return not selectedAuraGroup or not MOD.db.profile.AuraGroups[selectedAuraGroup] or MOD.db.profile.AuraGroups[selectedAuraGroup].showAsBars
                                    end,
                                    get = function()
                                        local val = MOD.db.profile.AuraGroups[selectedAuraGroup].showCooldownClock
                                        if val == nil then return true end
                                        return val
                                    end,
                                    set = function(_, v)
                                        CommitGroupSetting("showCooldownClock", v)
                                    end,
                                    order = 5,
                                },
                            },
                        },
                        fontGroup = {
                            type = "group",
                            name = "Font",
                            inline = true,
                            order = 7,
                            args = {
                                fontSize = {
                                    type = "range",
                                    name = "Font Size",
                                    desc = "Font size of the duration text on the aura",
                                    min = 6,
                                    max = 48,
                                    step = 1,
                                    hidden = function()
                                        if not selectedAuraGroup or not MOD.db.profile.AuraGroups[selectedAuraGroup] then return true end
                                        local group = MOD.db.profile.AuraGroups[selectedAuraGroup]
                                        -- In bars mode the aura name always uses font size; only hide when
                                        -- duration is off AND we are in icon mode.
                                        if group.showAsBars then return false end
                                        local val = group.showDuration
                                        if val == nil then return false end
                                        return not val
                                    end,
                                    get = function() return MOD.db.profile.AuraGroups[selectedAuraGroup].fontSize or 12 end,
                                    set = function(_, v)
                                        CommitGroupSetting("fontSize", v)
                                    end,
                                    order = 1,
                                },
                            },
                        },
                        lists = {
                            type = "group",
                            name = "Spell Lists in Group",
                            inline = true,
                            order = 8,
                            args = {
                                addList = {
                                    type = "select",
                                    name = "Add Spell List",
                                    desc = "Select a spell list to add to this aura group",
                                    values = function()
                                        local v = {}
                                        if not selectedAuraGroup or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups[selectedAuraGroup] then
                                            return v
                                        end
                                        local currentLists = MOD.db.profile.AuraGroups[selectedAuraGroup].lists or {}
                                        local added = {}
                                        for _, l in ipairs(currentLists) do
                                            if l.name then
                                                added[l.name] = true
                                            end
                                        end
                                        if MOD.db.profile.SpellLists then
                                            for k in pairs(MOD.db.profile.SpellLists) do
                                                if not added[k] then
                                                    v[k] = k
                                                end
                                            end
                                        end
                                        return v
                                    end,
                                    get = function() return nil end,
                                    set = function(_, v)
                                        if v and v ~= "" then
                                            table.insert(MOD.db.profile.AuraGroups[selectedAuraGroup].lists, { name = v, filterType = "whitelist", type = "whitelist" })
                                            MOD:UpdateContainers()
                                            UpdateAuraGroupListOptions()
                                        end
                                    end,
                                    disabled = function()
                                        if not selectedAuraGroup or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups[selectedAuraGroup] then
                                            return true
                                        end
                                        local currentLists = MOD.db.profile.AuraGroups[selectedAuraGroup].lists or {}
                                        local added = {}
                                        for _, l in ipairs(currentLists) do
                                            if l.name then
                                                added[l.name] = true
                                            end
                                        end
                                        if MOD.db.profile.SpellLists then
                                            for k in pairs(MOD.db.profile.SpellLists) do
                                                if not added[k] then
                                                    return false
                                                end
                                            end
                                        end
                                        return true
                                    end,
                                    order = 1,
                                },
                                listItems = {
                                    type = "description",
                                    name = function()
                                        if not selectedAuraGroup or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups[selectedAuraGroup] then
                                            return ""
                                        end
                                        local lists = MOD.db.profile.AuraGroups[selectedAuraGroup].lists or {}
                                        if #lists == 0 then
                                            return "No spell lists added to this group."
                                        end
                                        return ""
                                    end,
                                    order = 2,
                                },
                            }
                        },
                        customAuras = {
                            type = "group",
                            name = "Custom Auras in Group",
                            inline = true,
                            order = 9,
                            args = {
                                newAuraName = {
                                    type = "input",
                                    name = "New Custom Aura Name",
                                    desc = "Name for the new custom aura (e.g. MainHand)",
                                    get = function() return CrowOptions._tempCustomAuraName or "" end,
                                    set = function(_, v) CrowOptions._tempCustomAuraName = v end,
                                    order = 1,
                                },
                                newAuraType = {
                                    type = "select",
                                    name = "Custom Aura Type",
                                    desc = "Select the type of custom aura",
                                    values = {
                                        WeaponEnchant = "Weapon Enchant",
                                        ItemEnchant = "Item Enchant",
                                        Custom = "Custom",
                                    },
                                    get = function() return CrowOptions._tempCustomAuraType or "WeaponEnchant" end,
                                    set = function(_, v) CrowOptions._tempCustomAuraType = v end,
                                    order = 2,
                                },
                                createAura = {
                                    type = "execute",
                                    name = "Add to Group",
                                    desc = "Add this custom aura to the selected group",
                                    func = function()
                                        if not selectedAuraGroup or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups or not MOD.db.profile.AuraGroups[selectedAuraGroup] then return end
                                        local group = MOD.db.profile.AuraGroups[selectedAuraGroup]
                                        group.customAuras = group.customAuras or {}
                                        local auraName = CrowOptions._tempCustomAuraName
                                        if not auraName or auraName:trim() == "" then
                                            auraName = "CustomAura" .. (#group.customAuras + 1)
                                        end
                                        local auraType = CrowOptions._tempCustomAuraType or "WeaponEnchant"
                                        local auraValues = {}
                                        local reg = MOD.CustomAuraRegistry and MOD.CustomAuraRegistry[auraType]
                                        if reg and reg.defaultValues then
                                            for k, v in pairs(reg.defaultValues) do
                                                auraValues[k] = v
                                            end
                                        else
                                            auraValues = { weaponSlot = 0, enableCancel = true }
                                        end
                                        local rules = (reg and reg.CreateRuleSet and reg.CreateRuleSet(auraName, auraValues)) or {
                                            type = auraType,
                                            name = auraName,
                                            values = auraValues,
                                        }
                                        table.insert(group.customAuras, {
                                            name = auraName,
                                            type = auraType,
                                            values = auraValues,
                                            rules = rules,
                                        })
                                        CrowOptions._tempCustomAuraName = ""
                                        MOD:UpdateContainers()
                                        RefreshAuraGroupOptions()
                                    end,
                                    order = 3,
                                },
                                auraItems = {
                                    type = "description",
                                    name = function()
                                        if not selectedAuraGroup or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups or not MOD.db.profile.AuraGroups[selectedAuraGroup] then
                                            return ""
                                        end
                                        local list = MOD.db.profile.AuraGroups[selectedAuraGroup].customAuras or {}
                                        if #list == 0 then
                                            return "No custom auras added to this group."
                                        end
                                        return ""
                                    end,
                                    order = 4,
                                }
                            }
                        }
                    }
                }
            },
        },
        spells = {
            type = "group",
            name = "Spells",
            order = 3,
            args = {
                selectList = {
                    type = "select",
                    name = "Select Spell List",
                    values = function()
                        local v = {}
                        if MOD.db and MOD.db.profile and MOD.db.profile.SpellLists then
                            for k in pairs(MOD.db.profile.SpellLists) do v[k] = k end
                        end
                        return v
                    end,
                    get = function() return selectedSpellList end,
                    set = function(_, v) selectedSpellList = v end,
                    order = 1,
                },
                newList = {
                    type = "input",
                    name = "New Spell List Name",
                    set = function(_, v)
                        if v ~= "" and not MOD.db.profile.SpellLists[v] then
                            MOD.db.profile.SpellLists[v] = {}
                            selectedSpellList = v
                        end
                    end,
                    order = 2,
                },
                deleteList = {
                    type = "execute",
                    name = "Delete List",
                    func = function()
                        if selectedSpellList then
                            MOD.db.profile.SpellLists[selectedSpellList] = nil
                            selectedSpellList = nil
                        end
                    end,
                    disabled = function() return not selectedSpellList end,
                    order = 3,
                },
                spellEntry = {
                    type = "group",
                    name = "Spell List Entries",
                    inline = true,
                    hidden = function()
                        return not selectedSpellList or not MOD.db or not MOD.db.profile or not MOD.db.profile.SpellLists or not MOD.db.profile.SpellLists[selectedSpellList]
                    end,
                    args = {
                        addSpell = {
                            type = "input",
                            name = "Add Spell ID",
                            set = function(_, v)
                                local id = tonumber(v)
                                if id then
                                    MOD.db.profile.SpellLists[selectedSpellList][id] = true
                                end
                            end,
                            order = 1,
                        },
                        spellListText = {
                            type = "description",
                            name = function()
                                if not selectedSpellList then return "" end
                                local text = ""
                                for id in pairs(MOD.db.profile.SpellLists[selectedSpellList]) do
                                    local name = C_Spell.GetSpellInfo(id) and C_Spell.GetSpellInfo(id).name or "Unknown"
                                    text = text .. id .. ": " .. name .. "\n"
                                end
                                return text == "" and "List is empty." or text
                            end,
                            order = 2,
                        }
                    }
                }
            },
        },
        profiles = {
            type = "group",
            name = "Profiles",
            order = 4,
            args = {} -- Will be filled by AceDBOptions
        },
    },
}

-- Detailing Aura Groups lists management
UpdateAuraGroupListOptions = function()
    local listArgs = options.args.auraGroups.args.groupSettings.args.lists.args
    if type(listArgs) ~= "table" then return end

    -- Remove old dynamic entries
    for k in pairs(listArgs) do
        if k:find("^item_") then listArgs[k] = nil end
    end

    if not selectedAuraGroup then 
        if acereg:GetOptionsTable("Crow") then acereg:NotifyChange("Crow") end
        return 
    end
    
    local group = MOD.db.profile.AuraGroups[selectedAuraGroup]
    if not group then 
        if acereg:GetOptionsTable("Crow") then acereg:NotifyChange("Crow") end
        return 
    end
    
    for i, l in ipairs(group.lists) do
        listArgs["item_" .. i] = {
            type = "group",
            name = i .. ". " .. l.name,
            inline = true,
            order = i + 10,
            args = {
                type = {
                    type = "select",
                    name = "Type",
                    values = { whitelist = "Whitelist", blacklist = "Blacklist" },
                    get = function() return l.filterType or l.type or "whitelist" end,
                    set = function(_, v) 
                        l.filterType = v
                        l.type = v
                        MOD:UpdateContainers()
                        UpdateAuraGroupListOptions()
                    end,
                    order = 1,
                    width = "half",
                },
                swap = {
                    type = "execute",
                    name = "Swap Type",
                    desc = "Swap between Whitelist and Blacklist",
                    func = function()
                        local current = (l.filterType or l.type or "whitelist"):lower()
                        local newType = (current == "whitelist") and "blacklist" or "whitelist"
                        l.filterType = newType
                        l.type = newType
                        MOD:UpdateContainers()
                        UpdateAuraGroupListOptions()
                    end,
                    order = 2,
                    width = "half",
                },
                up = {
                    type = "execute",
                    name = "Up",
                    desc = "Move this spell list up in priority order",
                    disabled = function() return i == 1 end,
                    func = function()
                        if i > 1 then
                            local temp = group.lists[i-1]
                            group.lists[i-1] = group.lists[i]
                            group.lists[i] = temp
                            MOD:UpdateContainers()
                            UpdateAuraGroupListOptions()
                        end
                    end,
                    order = 3,
                    width = "half",
                },
                down = {
                    type = "execute",
                    name = "Down",
                    desc = "Move this spell list down in priority order",
                    disabled = function() return i == #group.lists end,
                    func = function()
                        if i < #group.lists then
                            local temp = group.lists[i+1]
                            group.lists[i+1] = group.lists[i]
                            group.lists[i] = temp
                            MOD:UpdateContainers()
                            UpdateAuraGroupListOptions()
                        end
                    end,
                    order = 4,
                    width = "half",
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    desc = "Remove this spell list from the aura group",
                    func = function()
                        table.remove(group.lists, i)
                        MOD:UpdateContainers()
                        UpdateAuraGroupListOptions()
                    end,
                    order = 5,
                    width = "half",
                }
            }
        }
    end
    
    if acereg:GetOptionsTable("Crow") then
        acereg:NotifyChange("Crow")
    end
end

UpdateAuraGroupCustomAuraOptions = function()
    local customAuraGroup = options.args.auraGroups.args.groupSettings.args.customAuras
    if not customAuraGroup or type(customAuraGroup.args) ~= "table" then return end
    local customAuraArgs = customAuraGroup.args

    -- Remove old dynamic entries
    for k in pairs(customAuraArgs) do
        if k:find("^aura_") then customAuraArgs[k] = nil end
    end

    if not selectedAuraGroup then 
        if acereg:GetOptionsTable("Crow") then acereg:NotifyChange("Crow") end
        return 
    end
    local group = MOD.db and MOD.db.profile and MOD.db.profile.AuraGroups and MOD.db.profile.AuraGroups[selectedAuraGroup]
    if not group then 
        if acereg:GetOptionsTable("Crow") then acereg:NotifyChange("Crow") end
        return 
    end

    group.customAuras = group.customAuras or {}
    for i, a in ipairs(group.customAuras) do
        local typeName = (MOD.CustomAuraRegistry and MOD.CustomAuraRegistry[a.type] and MOD.CustomAuraRegistry[a.type].name) or tostring(a.type or "Custom")
        local displayName = string.format("%s:%s", tostring(a.name or "Custom"), tostring(a.type or "CustomAura"))
        customAuraArgs["aura_" .. i] = {
            type = "group",
            name = i .. ". " .. displayName,
            inline = true,
            order = i + 10,
            args = {
                name = {
                    type = "description",
                    name = "|cffffd100Name:|r " .. tostring(a.name or ""),
                    order = 1,
                    width = "normal",
                },
                type = {
                    type = "description",
                    name = "|cffffd100Type:|r " .. tostring(typeName),
                    order = 2,
                    width = "normal",
                },
                open = {
                    type = "execute",
                    name = "Options",
                    desc = "Open the options window for this custom aura",
                    func = function()
                        CrowOptions:OpenCustomAuraWindow(selectedAuraGroup, i)
                    end,
                    order = 3,
                    width = "half",
                },
                up = {
                    type = "execute",
                    name = "Up",
                    desc = "Move this custom aura up in the list",
                    disabled = function() return i == 1 end,
                    func = function()
                        if i > 1 then
                            local temp = group.customAuras[i-1]
                            group.customAuras[i-1] = group.customAuras[i]
                            group.customAuras[i] = temp
                            MOD:UpdateContainers()
                            RefreshAuraGroupOptions()
                        end
                    end,
                    order = 4,
                    width = "half",
                },
                down = {
                    type = "execute",
                    name = "Down",
                    desc = "Move this custom aura down in the list",
                    disabled = function() return i == #group.customAuras end,
                    func = function()
                        if i < #group.customAuras then
                            local temp = group.customAuras[i+1]
                            group.customAuras[i+1] = group.customAuras[i]
                            group.customAuras[i] = temp
                            MOD:UpdateContainers()
                            RefreshAuraGroupOptions()
                        end
                    end,
                    order = 5,
                    width = "half",
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    desc = "Remove this custom aura from the group",
                    func = function()
                        table.remove(group.customAuras, i)
                        MOD:UpdateContainers()
                        RefreshAuraGroupOptions()
                    end,
                    order = 6,
                    width = "half",
                }
            }
        }
    end

    if acereg:GetOptionsTable("Crow") then
        acereg:NotifyChange("Crow")
    end
end

function CrowOptions:OpenCustomAuraWindow(groupName, customAuraRef)
    if not groupName or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups or not MOD.db.profile.AuraGroups[groupName] then
        groupName = selectedAuraGroup
    end
    if not groupName or not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups or not MOD.db.profile.AuraGroups[groupName] then
        return
    end

    local group = MOD.db.profile.AuraGroups[groupName]
    group.customAuras = group.customAuras or {}

    local editIndex = nil
    local currentAura = nil

    if type(customAuraRef) == "number" then
        editIndex = customAuraRef
        currentAura = group.customAuras[editIndex]
    elseif type(customAuraRef) == "table" then
        currentAura = customAuraRef
        for idx, a in ipairs(group.customAuras) do
            if a == customAuraRef then
                editIndex = idx
                break
            end
        end
    end

    local auraName = (currentAura and currentAura.name) or "MainHand"
    local auraType = (currentAura and currentAura.type) or "WeaponEnchant"
    local auraValues = {}

    local function CopyDictionary(src)
        local dest = {}
        if type(src) == "table" then
            for k, v in pairs(src) do
                if type(v) == "table" then
                    dest[k] = CopyDictionary(v)
                else
                    dest[k] = v
                end
            end
        end
        return dest
    end

    if currentAura and currentAura.values then
        auraValues = CopyDictionary(currentAura.values)
    else
        local reg = MOD.CustomAuraRegistry and MOD.CustomAuraRegistry[auraType]
        if reg and reg.defaultValues then
            auraValues = CopyDictionary(reg.defaultValues)
        else
            auraValues = { weaponSlot = 0, enableCancel = true }
        end
    end

    if self.customAuraFrame then
        if self.customAuraFrame.Release then
            pcall(self.customAuraFrame.Release, self.customAuraFrame)
        elseif self.customAuraFrame.Hide then
            self.customAuraFrame:Hide()
        end
        self.customAuraFrame = nil
    end

    local acegui = LibStub("AceGUI-3.0", true)
    if acegui then
        local frame = acegui:Create("Window")
        frame:SetTitle(editIndex and ("Edit Custom Aura: " .. tostring(auraName)) or "Add Custom Aura")
        frame:SetLayout("Flow")
        frame:SetWidth(460)
        frame:SetHeight(400)
        frame:EnableResize(false)
        self.customAuraFrame = frame

        -- 1. Name Field
        local nameEdit = acegui:Create("EditBox")
        nameEdit:SetLabel("Custom Aura Name")
        nameEdit:SetText(auraName)
        nameEdit:SetFullWidth(true)
        nameEdit:SetCallback("OnTextChanged", function(widget, event, text)
            auraName = text
        end)
        nameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
            auraName = text
        end)
        frame:AddChild(nameEdit)

        -- 2. DropDown for selecting Custom Aura Type
        local typeDropdown = acegui:Create("Dropdown")
        typeDropdown:SetLabel("Custom Aura Type")
        typeDropdown:SetList({
            WeaponEnchant = "Weapon Enchant",
            ItemEnchant = "Item Enchant",
            Custom = "Custom",
        })
        typeDropdown:SetValue(auraType)
        typeDropdown:SetFullWidth(true)
        frame:AddChild(typeDropdown)

        -- 3. Dynamic Custom Area Container under the dropdown
        local customArea = acegui:Create("InlineGroup")
        customArea:SetTitle("Weapon Enchant Settings")
        customArea:SetFullWidth(true)
        customArea:SetLayout("Flow")
        frame:AddChild(customArea)

        local function RefreshCustomArea()
            customArea:ReleaseChildren()

            if auraType == "WeaponEnchant" then
                customArea:SetTitle("Weapon Enchant Settings")

                local descLabel = acegui:Create("Label")
                descLabel:SetText("Configure temporary weapon enchantment tracking for a specific weapon slot.")
                descLabel:SetFullWidth(true)
                customArea:AddChild(descLabel)

                local slotDropdown = acegui:Create("Dropdown")
                slotDropdown:SetLabel("Weapon Slot")
                slotDropdown:SetList({
                    ["0"] = "Main Hand (Slot 1)",
                    ["1"] = "Off Hand (Slot 2)",
                    ["2"] = "Ranged / 3rd Slot (Slot 3)",
                })
                slotDropdown:SetValue(tostring(auraValues.weaponSlot or 0))
                slotDropdown:SetFullWidth(true)
                slotDropdown:SetCallback("OnValueChanged", function(widget, event, key)
                    auraValues.weaponSlot = tonumber(key) or 0
                end)
                customArea:AddChild(slotDropdown)

                local cancelCheck = acegui:Create("CheckBox")
                cancelCheck:SetLabel("Allow Right-Click to Cancel / Dismiss Enchant")
                cancelCheck:SetValue(auraValues.enableCancel ~= false)
                cancelCheck:SetFullWidth(true)
                cancelCheck:SetCallback("OnValueChanged", function(widget, event, val)
                    auraValues.enableCancel = val
                end)
                customArea:AddChild(cancelCheck)

            elseif auraType == "ItemEnchant" then
                customArea:SetTitle("Item Enchant Settings")

                local descLabel = acegui:Create("Label")
                descLabel:SetText("Configure item-based temporary enchantment tracking.")
                descLabel:SetFullWidth(true)
                customArea:AddChild(descLabel)

                local itemSlotDropdown = acegui:Create("Dropdown")
                itemSlotDropdown:SetLabel("Item Slot Index")
                itemSlotDropdown:SetList({
                    ["0"] = "Main Hand",
                    ["1"] = "Off Hand",
                    ["2"] = "Ranged / Other",
                })
                itemSlotDropdown:SetValue(tostring(auraValues.slotIndex or 0))
                itemSlotDropdown:SetFullWidth(true)
                itemSlotDropdown:SetCallback("OnValueChanged", function(widget, event, key)
                    auraValues.slotIndex = tonumber(key) or 0
                end)
                customArea:AddChild(itemSlotDropdown)

            elseif auraType == "Custom" then
                customArea:SetTitle("Custom Aura Settings")

                local spellEdit = acegui:Create("EditBox")
                spellEdit:SetLabel("Spell ID or Spell Name")
                spellEdit:SetText(tostring(auraValues.spellID or ""))
                spellEdit:SetFullWidth(true)
                spellEdit:SetCallback("OnTextChanged", function(widget, event, text)
                    auraValues.spellID = text
                end)
                customArea:AddChild(spellEdit)

                local durCheck = acegui:Create("CheckBox")
                durCheck:SetLabel("Show Duration")
                durCheck:SetValue(auraValues.showDuration ~= false)
                durCheck:SetFullWidth(true)
                durCheck:SetCallback("OnValueChanged", function(widget, event, val)
                    auraValues.showDuration = val
                end)
                customArea:AddChild(durCheck)
            end
        end

        typeDropdown:SetCallback("OnValueChanged", function(widget, event, key)
            auraType = key
            local reg = MOD.CustomAuraRegistry and MOD.CustomAuraRegistry[auraType]
            if reg and reg.defaultValues then
                for k, v in pairs(reg.defaultValues) do
                    if auraValues[k] == nil then
                        auraValues[k] = v
                    end
                end
            end
            RefreshCustomArea()
        end)

        RefreshCustomArea()

        -- 4. Action Buttons (Save / Cancel)
        local btnGroup = acegui:Create("SimpleGroup")
        btnGroup:SetLayout("Flow")
        btnGroup:SetFullWidth(true)
        frame:AddChild(btnGroup)

        local saveBtn = acegui:Create("Button")
        saveBtn:SetText("Save")
        saveBtn:SetWidth(120)
        saveBtn:SetCallback("OnClick", function()
            local finalName = auraName
            if not finalName or finalName:trim() == "" then
                finalName = auraType .. (#group.customAuras + 1)
            end

            local reg = MOD.CustomAuraRegistry and MOD.CustomAuraRegistry[auraType]
            local rules = (reg and reg.CreateRuleSet and reg.CreateRuleSet(finalName, auraValues)) or {
                type = auraType,
                name = finalName,
                values = CopyDictionary(auraValues),
            }

            local auraData = {
                name = finalName,
                type = auraType,
                values = CopyDictionary(auraValues),
                rules = rules,
            }

            if editIndex and group.customAuras[editIndex] then
                group.customAuras[editIndex] = auraData
            else
                table.insert(group.customAuras, auraData)
            end

            MOD:UpdateContainers()
            RefreshAuraGroupOptions()
            frame:Hide()
        end)
        btnGroup:AddChild(saveBtn)

        local cancelBtn = acegui:Create("Button")
        cancelBtn:SetText("Cancel")
        cancelBtn:SetWidth(120)
        cancelBtn:SetCallback("OnClick", function()
            frame:Hide()
        end)
        btnGroup:AddChild(cancelBtn)

        frame:SetCallback("OnClose", function(widget)
            acegui:Release(widget)
            CrowOptions.customAuraFrame = nil
        end)

        frame:Show()
    else
        local frame = self._nativeCustomAuraFrame
        if not frame then
            frame = CreateFrame("Frame", "CrowCustomAuraFrame", UIParent, "BackdropTemplate")
            frame:SetSize(450, 380)
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            frame:SetFrameStrata("DIALOG")
            frame:SetMovable(true)
            frame:EnableMouse(true)
            frame:RegisterForDrag("LeftButton")
            frame:SetScript("OnDragStart", frame.StartMoving)
            frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
            
            local bg = frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(frame)
            bg:SetColorTexture(0.08, 0.08, 0.12, 0.95)
            
            local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            title:SetPoint("TOP", frame, "TOP", 0, -10)
            title:SetText("Custom Aura Options")
            
            local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
            closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
            closeBtn:SetScript("OnClick", function() frame:Hide() end)
            
            self._nativeCustomAuraFrame = frame
        end
        frame:Show()
    end
end

function CrowOptions:Open()
    if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        print("|cff6699ffCrow|r: Options cannot be opened in combat.")
        return
    end
    if not acereg:GetOptionsTable("Crow") then
        MOD:SetupOptions()
    end
    acedia:Open("Crow")
end

function CrowOptions:Close()
    if acedia and acedia.Close then
        pcall(acedia.Close, acedia, "Crow")
    end
end

function CrowOptions:OnProfileChanged()
    if selectedAuraGroup and (not MOD.db or not MOD.db.profile or not MOD.db.profile.AuraGroups or not MOD.db.profile.AuraGroups[selectedAuraGroup]) then
        selectedAuraGroup = nil
    end
    if selectedSpellList and (not MOD.db or not MOD.db.profile or not MOD.db.profile.SpellLists or not MOD.db.profile.SpellLists[selectedSpellList]) then
        selectedSpellList = nil
    end
    RefreshAuraGroupOptions()
end

function MOD:SetupOptions()
    if not MOD.db and self.InitializeProfile then
        self:InitializeProfile()
    end
    if MOD.db then
        options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(MOD.db)
        options.args.profiles.order = 99  -- always last tab
    end
    acereg:RegisterOptionsTable("Crow", options)
    -- Register a lightweight button in Blizzard Interface Options that opens
    -- the Ace popup; this avoids embedding the full panel inside Blizzard's UI.
    acedia:AddToBlizOptions("Crow", "Crow")
    RefreshAuraGroupOptions()
end
