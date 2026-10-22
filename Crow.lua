Crow = LibStub("AceAddon-3.0"):NewAddon("Crow", "AceConsole-3.0", "AceEvent-3.0")
local MOD = Crow
MOD.containers = {}
MOD.anchors = {}
MOD.dummyFrames = {}
MOD.isMoving = false

MOD.CustomAuraType = {
    WeaponEnchant = "WeaponEnchant",
    ItemEnchant = "ItemEnchant",
    Custom = "Custom",
}

MOD.CustomAuraRegistry = {
    [MOD.CustomAuraType.WeaponEnchant] = {
        name = "Weapon Enchant",
        description = "Monitors temporary weapon enchantments applied to specific inventory slots.",
        defaultValues = {
            weaponSlot = 0,
            enableCancel = true,
        },
        slotOptions = {
            [0] = "Main Hand (Slot 1)",
            [1] = "Off Hand (Slot 2)",
            [2] = "Ranged / 3rd Slot (Slot 3)",
        },
        CreateRuleSet = function(name, values)
            return {
                type = MOD.CustomAuraType.WeaponEnchant,
                name = tostring(name or "WeaponEnchant"),
                values = {
                    weaponSlot = tonumber(values and values.weaponSlot) or 0,
                    enableCancel = (values and values.enableCancel ~= false),
                }
            }
        end,
    },
    [MOD.CustomAuraType.ItemEnchant] = {
        name = "Item Enchant",
        description = "Monitors item-based temporary enchantments.",
        defaultValues = {
            slotIndex = 0,
        },
        slotOptions = {
            [0] = "Main Hand",
            [1] = "Off Hand",
            [2] = "Ranged / Other",
        },
        CreateRuleSet = function(name, values)
            return {
                type = MOD.CustomAuraType.ItemEnchant,
                name = tostring(name or "ItemEnchant"),
                values = {
                    slotIndex = tonumber(values and values.slotIndex) or 0,
                }
            }
        end,
    },
    [MOD.CustomAuraType.Custom] = {
        name = "Custom",
        description = "Generic custom aura tracking.",
        defaultValues = {
            spellID = "",
            showDuration = true,
        },
        CreateRuleSet = function(name, values)
            return {
                type = MOD.CustomAuraType.Custom,
                name = tostring(name or "Custom"),
                values = {
                    spellID = (values and values.spellID) or "",
                    showDuration = (values and values.showDuration ~= false),
                }
            }
        end,
    }
}

MOD.DUMMY_AURAS = {
    HELPFUL = {},
    HARMFUL = {}
}

function MOD:SafeGetAuraProperty(data, prop)
    if type(data) ~= "table" then return nil end
    local ok, val = pcall(function() return data[prop] end)
    if not ok then return nil end
    local okSafe = pcall(function()
        local _ = (val ~= nil)
        if type(val) == "string" then
            local _ = #val
        elseif type(val) == "number" then
            local _ = val + 0
        end
    end)
    if not okSafe then return nil end
    return val
end

function MOD:SafeRenderDummy(dummyButton, auraData, settings)
    if not dummyButton or type(auraData) ~= "table" then return false end
    
    local ok = pcall(function()
        local icon = self:SafeGetAuraProperty(auraData, "icon")
        local count = self:SafeGetAuraProperty(auraData, "count")
        local duration = self:SafeGetAuraProperty(auraData, "duration")
        local expiration = self:SafeGetAuraProperty(auraData, "expiration")
        local name = self:SafeGetAuraProperty(auraData, "name")

        if dummyButton.Icon and icon then
            dummyButton.Icon:SetTexture(icon)
            local iconPos = settings and settings.showAsBars and string.upper(settings.barIconPosition or "LEFT")
            if iconPos ~= "NONE" then
                dummyButton.Icon:Show()
            end
        end

        if dummyButton.CountText then
            if type(count) == "number" and count > 1 then
                dummyButton.CountText:SetText(tostring(count))
                dummyButton.CountText:Show()
            else
                dummyButton.CountText:SetText("")
                dummyButton.CountText:Hide()
            end
        end

        local showDuration = not settings or settings.showDuration ~= false
        local durTextStr = ""
        if showDuration and type(expiration) == "number" and expiration > 0 then
            if expiration >= 3600 then
                durTextStr = string.format("%dh", math.floor(expiration / 3600))
            elseif expiration >= 60 then
                durTextStr = string.format("%dm", math.floor(expiration / 60))
            else
                durTextStr = string.format("%ds", math.floor(expiration))
            end
        end

        if dummyButton.DurationText then
            if showDuration and durTextStr ~= "" then
                dummyButton.DurationText:SetText(durTextStr)
                dummyButton.DurationText:Show()
            else
                dummyButton.DurationText:SetText("")
                dummyButton.DurationText:Hide()
            end
        end

        if dummyButton.Bar then
            if name then
                local nl = dummyButton.CrowNameText
                if nl then nl:SetText(tostring(name)); nl:Show() end
            end
            if dummyButton.Bar.TimeText then
                if showDuration and durTextStr ~= "" then
                    dummyButton.Bar.TimeText:SetText(durTextStr)
                    dummyButton.Bar.TimeText:Show()
                else
                    dummyButton.Bar.TimeText:SetText("")
                    dummyButton.Bar.TimeText:Hide()
                end
            end
            if type(duration) == "number" and duration > 0 and type(expiration) == "number" then
                dummyButton.Bar:SetMinMaxValues(0, duration)
                dummyButton.Bar:SetValue(math.min(duration, math.max(0, expiration)))
            else
                dummyButton.Bar:SetMinMaxValues(0, 1)
                dummyButton.Bar:SetValue(1)
            end
        end

        if dummyButton.MiniBar then
            if type(duration) == "number" and duration > 0 and type(expiration) == "number" then
                dummyButton.MiniBar:SetMinMaxValues(0, duration)
                dummyButton.MiniBar:SetValue(math.min(duration, math.max(0, expiration)))
            else
                dummyButton.MiniBar:SetMinMaxValues(0, 1)
                dummyButton.MiniBar:SetValue(1)
            end
        end

        local showCooldownClock = not settings or settings.showCooldownClock ~= false
        if dummyButton.Cooldown then
            if showCooldownClock and type(duration) == "number" and duration > 0 and type(expiration) == "number" then
                local now = (GetTime and GetTime()) or 0
                local start = now - (duration - expiration)
                dummyButton.Cooldown:SetCooldown(start, duration)
                dummyButton.Cooldown:Show()
            else
                dummyButton.Cooldown:Clear()
                dummyButton.Cooldown:Hide()
            end
        end

        dummyButton:Show()
    end)
    return ok
end

function MOD:HideDummyAuras(groupName)
    if self.dummyFrames and self.dummyFrames[groupName] then
        for _, btn in ipairs(self.dummyFrames[groupName]) do
            btn:Hide()
            btn:ClearAllPoints()
        end
    end
end

function MOD:UpdateDummyAuras(groupName, container, settings)
    if not settings or not settings.showDummyAuras then
        self:HideDummyAuras(groupName)
        return
    end

    self.dummyFrames = self.dummyFrames or {}
    self.dummyFrames[groupName] = self.dummyFrames[groupName] or {}
    local groupDummyFrames = self.dummyFrames[groupName]
    local dataset = {}

    if settings.customAuras and #settings.customAuras > 0 then
        for _, ca in ipairs(settings.customAuras) do
            if ca.type == "WeaponEnchant" or ca.type == (MOD.CustomAuraType and MOD.CustomAuraType.WeaponEnchant) then
                local slot = (ca.values and ca.values.weaponSlot) or 0
                slot = tonumber(slot) or 0
                local slotNames = { [0] = "Main Hand", [1] = "Off Hand", [2] = "Ranged" }
                local icons = { [0] = 135274, [1] = 132333, [2] = 136085 }
                table.insert(dataset, {
                    name = (ca.name and ca.name ~= "") and ca.name or ("Enchant: " .. (slotNames[slot] or "Weapon")),
                    icon = icons[slot] or 135274,
                    duration = 3600,
                    expiration = 1800,
                    count = 0,
                })
            else
                table.insert(dataset, {
                    name = (ca.name and ca.name ~= "") and ca.name or "Custom Aura",
                    icon = 134400,
                    duration = 60,
                    expiration = 45,
                    count = 0,
                })
            end
        end
    end


    local maxAuras = settings.maxAuras or 10
    local numDummies = math.min(maxAuras, #dataset)
    if numDummies < 1 then numDummies = math.min(maxAuras, 6) end

    local isBar = settings.showAsBars
    local elemWidth = isBar and (settings.barWidth or 160) or (settings.iconSize or 40)
    local elemHeight = isBar and (settings.barHeight or 20) or ((settings.iconSize or 40) + (settings.showMiniBar and 22 or 0))
    local spacing    = settings.spacing    or 4
    local rowSpacing = settings.rowSpacing or 4
    local aurasPerRow = tonumber(settings.aurasPerRow) or (isBar and 1 or 6)
    if aurasPerRow < 1 then aurasPerRow = 1 end

    local flowDir = settings.flowDirection or MOD.FlowDirection.RIGHTDOWN
    local layoutAnchorPoint = "TOPLEFT"
    local xMultiplier = 1
    local yMultiplier = -1

    if flowDir == MOD.FlowDirection.RIGHTDOWN or flowDir == "RIGHTDOWN" or flowDir == 1 then
        layoutAnchorPoint = "TOPLEFT"
        xMultiplier = 1
        yMultiplier = -1
    elseif flowDir == MOD.FlowDirection.RIGHTUP or flowDir == "RIGHTUP" or flowDir == 2 then
        layoutAnchorPoint = "BOTTOMLEFT"
        xMultiplier = 1
        yMultiplier = 1
    elseif flowDir == MOD.FlowDirection.LEFTDOWN or flowDir == "LEFTDOWN" or flowDir == 3 then
        layoutAnchorPoint = "TOPRIGHT"
        xMultiplier = -1
        yMultiplier = -1
    elseif flowDir == MOD.FlowDirection.LEFTUP or flowDir == "LEFTUP" or flowDir == 4 then
        layoutAnchorPoint = "BOTTOMRIGHT"
        xMultiplier = -1
        yMultiplier = 1
    end

    for i = 1, numDummies do
        local btn = groupDummyFrames[i]
        if not btn then
            local ok, frame = pcall(CreateFrame, "Button", nil, container, "CrowAuraButtonTemplate")
            if not (ok and frame) then
                frame = CreateFrame("Button", nil, container)
                Mixin(frame, CrowAuraButtonMixin)
                if frame.OnLoad then frame:OnLoad() end
            end
            btn = frame
            groupDummyFrames[i] = btn
        end

        btn:SetParent(container)
        if isBar then
            self:ConfigureAuraBar(btn, settings)
        else
            self:ConfigureAuraButton(btn, settings)
        end

        local col = (i - 1) % aurasPerRow
        local row = math.floor((i - 1) / aurasPerRow)
        local xOffset = col * (elemWidth  + spacing)    * xMultiplier
        local yOffset = row * (elemHeight + rowSpacing) * yMultiplier

        btn:ClearAllPoints()
        btn:SetPoint(layoutAnchorPoint, container, layoutAnchorPoint, xOffset, yOffset)
        btn:SetSize(elemWidth, elemHeight)

        local auraData = dataset[((i - 1) % #dataset) + 1]
        self:SafeRenderDummy(btn, auraData, settings)
    end

    -- Hide any extra dummy buttons from previous larger renders
    for i = numDummies + 1, #groupDummyFrames do
        if groupDummyFrames[i] then
            groupDummyFrames[i]:Hide()
            groupDummyFrames[i]:ClearAllPoints()
        end
    end
end

MOD.FlowDirection = {
    RIGHTDOWN = 1,
    RIGHTUP = 2,
    LEFTDOWN = 3,
    LEFTUP = 4,
}
CrowFlowDirection = MOD.FlowDirection

function MOD:OnInitialize()
    
    if self.InitializeProfile then
        self:InitializeProfile()
    end
    if self.SetupOptions then
        self:SetupOptions()
    end
end

function MOD:OnEnable()
    print("|cff6699ffCrow|r: Enabled.")
    
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    self:UpdateContainers()
    
    MOD:RegisterChatCommand("crow", function(input)
        input = input and input:trim():lower() or ""
        if input == "move" or input == "unlock" or input == "lock" then
            if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
                print("|cff6699ffCrow|r: Move mode cannot be used in combat.")
                return
            end
            MOD:ToggleMoveMode()
        else
            MOD:ToggleOptions()
        end
    end)
    
    BuffFrame:SetShown(false)
    DebuffFrame:SetShown(false)
    
    BuffFrame:HookScript("OnShow", function(self)
        self:Hide()
    end)
    
    DebuffFrame:HookScript("OnShow", function(self)
        self:Hide()
    end)
end

function MOD:OnUnitAura(event, unit)
end

function MOD:PLAYER_REGEN_DISABLED()
    if CrowOptions and CrowOptions.Close then
        CrowOptions:Close()
    else
        local acedia = LibStub("AceConfigDialog-3.0", true)
        if acedia then
            acedia:Close("Crow")
        end
    end
    if self.isMoving then
        self:SetMoveMode(false)
    end
end

-- Refresh only groups whose unit is "target" so their aura containers reflect
-- the newly targeted unit without touching any other group.
function MOD:PLAYER_TARGET_CHANGED()
    if not self.db or not self.db.profile or not self.db.profile.AuraGroups then return end
    for name, settings in pairs(self.db.profile.AuraGroups) do
        if settings.enabled and settings.unit == "target" then
            local container = self.containers and self.containers[name]
            if container then
                if container.SetUnit then
                    pcall(container.SetUnit, container, "target")
                end
                if container.UpdateAllAuras then
                    pcall(container.UpdateAllAuras, container)
                end
            end
        end
    end
end

function MOD:OnProfileChanged(event, db, newProfile)
    -- Hide all dummy frames
    if self.dummyFrames then
        for name, _ in pairs(self.dummyFrames) do
            self:HideDummyAuras(name)
        end
    end

    -- Tear down and hide all existing active containers and their children
    for name, container in pairs(self.containers) do
        if container then
            container:Hide()
            container:ClearAllPoints()
            if container.ClearAuraGroups then
                pcall(container.ClearAuraGroups, container)
            elseif container.RemoveAuraGroup then
                pcall(container.RemoveAuraGroup, container, name)
            end
            if container.ClearItemEnchantments then
                pcall(container.ClearItemEnchantments, container)
            end
            for _, child in ipairs({ container:GetChildren() }) do
                if child.Hide then child:Hide() end
            end
        end
    end

    -- Tear down and hide all existing anchors
    for name, anchor in pairs(self.anchors) do
        if anchor then
            anchor:Hide()
            anchor:ClearAllPoints()
        end
    end

    -- Re-instantiate containers and layout for the new profile
    self:UpdateContainers()

    -- Re-synchronize move mode anchors if move mode is active
    if self.isMoving then
        self:ShowAnchors()
    end

    -- Notify Options module if available
    if CrowOptions and CrowOptions.OnProfileChanged then
        CrowOptions:OnProfileChanged()
    end

    local acereg = LibStub("AceConfigRegistry-3.0", true)
    if acereg and acereg.NotifyChange then
        pcall(acereg.NotifyChange, acereg, "Crow")
    end
end

function MOD:CreateAuraContainer(name)
    local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate");
    container.groupName = name
    container.buttons = {}
    return container
end

function MOD:RecreateContainer(name)
    local oldContainer = self.containers[name]
    if oldContainer then
        oldContainer:Hide()
        oldContainer:ClearAllPoints()
        if oldContainer.ClearAuraGroups then
            pcall(oldContainer.ClearAuraGroups, oldContainer)
        elseif oldContainer.RemoveAuraGroup then
            pcall(oldContainer.RemoveAuraGroup, oldContainer, name)
        end
        if oldContainer.ClearItemEnchantments then
            pcall(oldContainer.ClearItemEnchantments, oldContainer)
        end
        for _, child in ipairs({ oldContainer:GetChildren() }) do
            if child.Hide then child:Hide() end
        end
    end
    local container = self:CreateAuraContainer(name)
    self.containers[name] = container
    return container
end

function MOD:Debug(a, ...)
	if type(a) == "table" then
		for k, v in pairs(a) do
			print(tostring(k) .. " = " .. tostring(v))
		end -- if first parameter is a table, print out its fields
	else
		local s = tostring(a) -- otherwise first argument is a string but just make sure
		local parm = { ... }
		for i = 1, #parm do
			s = s .. " " .. tostring(parm[i])
		end -- append remaining arguments converted to strings
		print(s)
	end
end

function MOD:ConfigureAuraBar(auraButton, settings)
    if not auraButton or auraButton.__crowConfiguring then return end
    auraButton.__crowConfiguring = true
    
    local barWidth = (settings and settings.barWidth) or 160
    local barHeight = (settings and settings.barHeight) or 20
    local showDuration = not settings or settings.showDuration ~= false
    local fontSize = (settings and settings.fontSize) or 12
    local showCooldownClock = not settings or settings.showCooldownClock ~= false
    local barIconPosition = string.upper((settings and settings.barIconPosition) or "LEFT")
        
    
    pcall(auraButton.SetSize, auraButton, barWidth, barHeight)
    auraButton.__crowIsBar = true
    auraButton.__crowSettings = settings
    auraButton.__crowSize = barHeight
    
    local icon = auraButton.Icon or auraButton.icon or (auraButton.GetIcon and select(2, pcall(auraButton.GetIcon, auraButton)))
    if not icon then
        icon = auraButton:CreateTexture(nil, "BACKGROUND")
        auraButton.Icon = icon
    end
    
    if icon then
        icon:ClearAllPoints()
        if barIconPosition == "NONE" then
            icon:Hide()
        else
            pcall(icon.SetSize, icon, barHeight, barHeight)
            if barIconPosition == "RIGHT" then
                icon:SetPoint("RIGHT", auraButton, "RIGHT", 0, 0)
            else -- LEFT
                icon:SetPoint("LEFT", auraButton, "LEFT", 0, 0)
            end
            icon:Show()
        end
    end
    
    if auraButton.SetIcon and icon then
        pcall(auraButton.SetIcon, auraButton, icon)
    end
    
    local cd = auraButton.Cooldown or auraButton.cooldown
    if not cd then
        cd = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        auraButton.Cooldown = cd
    end
    cd:ClearAllPoints()
    if barIconPosition ~= "NONE" and icon then
        cd:SetAllPoints(icon)
    end
    cd:EnableMouse(false)
    if cd.EnableMouseMotion then
        cd:EnableMouseMotion(false)
    end
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawBling(false)

    if not auraButton.Bar then
        local bar = CreateFrame("StatusBar", nil, auraButton, "CrowAuraBarTemplate")
        Mixin(bar, CrowAuraBarMixin)
        if bar.OnLoad then
            bar:OnLoad()
        end
        auraButton.Bar = bar

        auraButton.Bar.__crowNeedsTicker = true
    end
    local bar = auraButton.Bar


    if not auraButton.__crowUpdateAuraHooked and auraButton.UpdateAura then
        auraButton.__crowUpdateAuraHooked = true
        hooksecurefunc(auraButton, "UpdateAura", function(btn, auraData)
            local b = btn.Bar
            if not b or not auraData then return end

            -- auraData already carries the name; no need for a secondary lookup
            if b.NameText then
                local name = type(auraData.name) == "string" and auraData.name ~= "" and auraData.name
                if name then
                    b.NameText:SetText(name)
                end
            end

            -- Use GetAuraDataByAuraInstanceID only for timing data
            local container = btn:GetParent()
            local unit = (container and container.unit) or "player"
            pcall(function()
                if not auraData.auraInstanceID then return end
                local cleanData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraData.auraInstanceID)
                if cleanData and type(cleanData.duration) == "number" and cleanData.duration > 0 then
                    b.cdDuration = cleanData.duration
                    b.cdStart = cleanData.expirationTime - cleanData.duration
                end
            end)
        end)
    end
    bar.settings = settings
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local barTex = bar:GetStatusBarTexture()
    if barTex then
        barTex:SetHorizTile(false)
    end
    if not bar.bg then
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetColorTexture(0, 0, 0, 0.5)
        bar.bg = bg
    end
    -- OnUpdate is driven by the central ticker to avoid secure taint; avoid setting scripts on secure frames.
    
    if not cd.__crowHooked then
        cd.__crowHooked = true
        hooksecurefunc(cd, "SetCooldown", function(self, start, duration, modRate)
            local b = auraButton.Bar
            if b then
                b.cdStart = start
                b.cdDuration = duration
                CrowAuraBarMixin.OnUpdate(b, 0)
            end
        end)
        if cd.SetCooldownUNIX then
            hooksecurefunc(cd, "SetCooldownUNIX", function(self, start, duration, modRate)
                local b = auraButton.Bar
                if b then
                    b.cdStart = start
                    b.cdDuration = duration
                    CrowAuraBarMixin.OnUpdate(b, 0)
                end
            end)
        end
        if cd.SetCooldownDuration then
            hooksecurefunc(cd, "SetCooldownDuration", function(self, duration, modRate)
                local b = auraButton.Bar
                if b then
                    b.cdStart = GetTime()
                    b.cdDuration = duration
                    CrowAuraBarMixin.OnUpdate(b, 0)
                end
            end)
        end
        if cd.SetCooldownFromExpirationTime then
            hooksecurefunc(cd, "SetCooldownFromExpirationTime", function(self, expirationTime, duration, modRate)
                local b = auraButton.Bar
                if b then
                    b.cdDuration = duration
                    b.cdStart = (expirationTime and duration) and (expirationTime - duration) or GetTime()
                    CrowAuraBarMixin.OnUpdate(b, 0)
                end
            end)
        end
        if cd.Clear then
            hooksecurefunc(cd, "Clear", function(self)
                local b = auraButton.Bar
                if b then
                    b.cdStart = 0
                    b.cdDuration = 0
                    b:SetMinMaxValues(0, 1)
                    b:SetValue(1)
                end
            end)
        end
    end

    if barIconPosition == "NONE" then
        cd:SetDrawSwipe(false)
        cd:SetDrawEdge(false)
        cd:Hide()
    elseif showCooldownClock then
        cd:SetDrawSwipe(true)
        cd:SetDrawEdge(true)
        cd:Show()
    else
        cd:SetDrawSwipe(false)
        cd:SetDrawEdge(false)
        cd:Show()
    end
    
    if auraButton.SetDurationCooldown then
        pcall(auraButton.SetDurationCooldown, auraButton, cd)
    end

    -- Register our bar as the application bar so Blizzard drives its fill the same way it drives duration text
    if auraButton.SetApplicationBar and auraButton.Bar then
        pcall(auraButton.SetApplicationBar, auraButton, auraButton.Bar)
    end

    local borderKeys = {
        "DebuffBorder", "debuffBorder",
        "TempEnchantBorder", "tempEnchantBorder",
        "Symbol", "symbol",
        "Stealable", "stealable",
        "IconBorder", "iconBorder",
        "BorderFrame", "BorderTexture",
        "Overlay", "overlay"
    }
    for _, key in ipairs(borderKeys) do
        local b = auraButton[key]
        if b and b ~= icon then
            b:ClearAllPoints()
            if barIconPosition == "NONE" then
                b:Hide()
            else
                b:SetAllPoints(icon)
                if b.SetSize then
                    pcall(b.SetSize, b, barHeight, barHeight)
                end
            end
        end
    end

    if not auraButton.CountText then
        local countText = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        countText:SetJustifyH("RIGHT")
        auraButton.CountText = countText
    end
    if barIconPosition ~= "NONE" and icon then
        auraButton.CountText:ClearAllPoints()
        auraButton.CountText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    end
    if auraButton.SetApplicationCount then
        pcall(auraButton.SetApplicationCount, auraButton, auraButton.CountText, {})
    elseif auraButton.SetApplicationsText then
        pcall(auraButton.SetApplicationsText, auraButton, auraButton.CountText)
    elseif auraButton.SetCountText then
        pcall(auraButton.SetCountText, auraButton, auraButton.CountText)
    end
    if barIconPosition == "NONE" then
        auraButton.CountText:Hide()
    else
        auraButton.CountText:Show()
    end

    bar:ClearAllPoints()
    if barIconPosition == "NONE" then
        bar:SetAllPoints(auraButton)
        pcall(bar.SetSize, bar, barWidth, barHeight)
    elseif barIconPosition == "RIGHT" then
        bar:SetPoint("LEFT", auraButton, "LEFT", 0, 0)
        bar:SetPoint("RIGHT", icon, "LEFT", -2, 0)
        bar:SetPoint("TOP", auraButton, "TOP", 0, 0)
        bar:SetPoint("BOTTOM", auraButton, "BOTTOM", 0, 0)
        pcall(bar.SetSize, bar, math.max(10, barWidth - barHeight - 2), barHeight)
    else -- LEFT
        bar:SetPoint("LEFT", icon, "RIGHT", 2, 0)
        bar:SetPoint("RIGHT", auraButton, "RIGHT", 0, 0)
        bar:SetPoint("TOP", auraButton, "TOP", 0, 0)
        bar:SetPoint("BOTTOM", auraButton, "BOTTOM", 0, 0)
        pcall(bar.SetSize, bar, math.max(10, barWidth - barHeight - 2), barHeight)
    end
    bar:Show()

    -- Register bar with Blizzard's native duration system.
    -- RemainingTime: bar is full when the aura is fresh and drains to empty as it expires.
    if auraButton.SetDurationBar then
        local barOptions = {
            direction     = (Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime) or 1,
            interpolation = (Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate)       or 0,
        }
        local ok = pcall(auraButton.SetDurationBar, auraButton, bar, barOptions)
        bar.__crowNativeFill = ok
    end

    if bar.TimeText then
        if showDuration then
            local fontFile, fontHeight, fontFlags = bar.TimeText:GetFont()
            if not fontFile or fontFile == "" then fontFile = "Fonts\\FRIZQT__.TTF" end
            bar.TimeText:SetFont(fontFile, fontSize, fontFlags)
            bar.TimeText:Show()
            if auraButton.SetDurationText then
                pcall(auraButton.SetDurationText, auraButton, bar.TimeText)
            end
        else
            bar.TimeText:Hide()
            bar.TimeText:SetText("")
            if auraButton.ClearDurationText then
                pcall(auraButton.ClearDurationText, auraButton)
            elseif auraButton.SetDurationText then
                pcall(auraButton.SetDurationText, auraButton, nil)
            end
        end
    end
    
    -- Spell name label: child of the bar so it renders above the bar's fill texture.
    -- SetSpellName accepts any FontString reference regardless of parent frame.
    if not auraButton.CrowNameText then
        auraButton.CrowNameText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        auraButton.CrowNameText:SetJustifyH("LEFT")
    end
    local nameLabel = auraButton.CrowNameText
    local nameFont = nameLabel:GetFont()
    if not nameFont or nameFont == "" then nameFont = "Fonts\\FRIZQT__.TTF" end
    nameLabel:SetFont(nameFont, fontSize, "OUTLINE")
    nameLabel:ClearAllPoints()
    nameLabel:SetPoint("LEFT",   bar, "LEFT",   4,  0)
    nameLabel:SetPoint("TOP",    bar, "TOP",    0,  0)
    nameLabel:SetPoint("BOTTOM", bar, "BOTTOM", 0,  0)
    if showDuration and bar.TimeText then
        nameLabel:SetPoint("RIGHT", bar.TimeText, "LEFT", -4, 0)
    else
        nameLabel:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    end
    nameLabel:Show()
    -- SetSpellName lets Blizzard's aura system write the name directly into this FontString.
    if auraButton.SetSpellName then
        pcall(auraButton.SetSpellName, auraButton, nameLabel)
    elseif auraButton.SetNameText then
        pcall(auraButton.SetNameText, auraButton, nameLabel)
    elseif auraButton.SetAuraName then
        pcall(auraButton.SetAuraName, auraButton, nameLabel)
    end
    -- Hide the template's built-in NameText inside the bar to avoid duplicates.
    if bar.NameText then bar.NameText:Hide() end

    if auraButton.DurationText and auraButton.DurationText ~= bar.TimeText then
        auraButton.DurationText:Hide()
        auraButton.DurationText:SetText("")
    end

    auraButton.__crowConfiguring = false
end

function MOD:ConfigureAuraButton(auraButton, sizeOrSettings, maybeSettings)
    if not auraButton or auraButton.__crowConfiguring then return end
    auraButton.__crowConfiguring = true


    local size, settings
    if type(sizeOrSettings) == "table" then
        settings = sizeOrSettings
        size = settings.iconSize or 40
    else
        size = sizeOrSettings or 40
        settings = maybeSettings or auraButton.__crowSettings or {}
    end

    local showDuration = not settings or settings.showDuration ~= false
    local fontSize = (settings and settings.fontSize) or 12
    local showCooldownClock = not settings or settings.showCooldownClock ~= false

    local showMiniBar = settings.showMiniBar and not settings.showAsBars
    local miniBarPos  = string.upper((settings.miniBarPosition) or "BELOW")
    local miniBarGap  = 2
    local miniBarH    = 20
    local totalHeight = showMiniBar and (size + miniBarGap + miniBarH) or size

    auraButton.__crowIsBar = false
    auraButton.__crowSettings = settings
    auraButton.__crowSize = size
    pcall(auraButton.SetSize, auraButton, size, totalHeight)
    
    if auraButton.Bar then
        auraButton.Bar:Hide()
    end
    if auraButton.CountText then
        auraButton.CountText:Hide()
    end
    
    local icon = auraButton.Icon or auraButton.icon or (auraButton.GetIcon and select(2, pcall(auraButton.GetIcon, auraButton)))
    if not icon then
        icon = auraButton:CreateTexture(nil, "BACKGROUND")
        auraButton.Icon = icon
    end
    
    if icon then
        icon:ClearAllPoints()
        if showMiniBar then
            pcall(icon.SetSize, icon, size, size)
            if miniBarPos == "ABOVE" then
                icon:SetPoint("BOTTOM", auraButton, "BOTTOM", 0, 0)
            else -- BELOW
                icon:SetPoint("TOP", auraButton, "TOP", 0, 0)
            end
        else
            icon:SetAllPoints(auraButton)
            pcall(icon.SetSize, icon, size, size)
        end
    end

    -- iconRef: reference frame for cooldown, duration text, and borders.
    -- When mini bar is active the button is taller than the icon, so restrict
    -- all icon-level decorations to the icon sub-region.
    local iconRef = (showMiniBar and icon) or auraButton
    
    if auraButton.SetIcon and icon then
        pcall(auraButton.SetIcon, auraButton, icon)
    end
    
    local cd = auraButton.Cooldown or auraButton.cooldown
    if not cd then
        cd = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        auraButton.Cooldown = cd
    end
    cd:ClearAllPoints()
    cd:SetAllPoints(iconRef)
    cd:EnableMouse(false)
    if cd.EnableMouseMotion then
        cd:EnableMouseMotion(false)
    end
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawBling(false)

    if showCooldownClock then
        cd:SetDrawSwipe(true)
        cd:SetDrawEdge(true)
        cd:Show()
    else
        cd:SetDrawSwipe(false)
        cd:SetDrawEdge(false)
        cd:Show()
    end

    if auraButton.SetDurationCooldown then
        pcall(auraButton.SetDurationCooldown, auraButton, cd)
    end
    
    local durText = auraButton.DurationText or auraButton.Duration or auraButton.TimerText or auraButton.Text
    if not durText then
        durText = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        auraButton.DurationText = durText
    end

    local durationOffset = tonumber(settings and settings.durationOffset) or 0

    durText:ClearAllPoints()
    durText:SetPoint("CENTER", iconRef, "CENTER", 0, durationOffset)
    durText:SetJustifyH("CENTER")

    if showDuration then
        local fontFile, fontHeight, fontFlags = durText:GetFont()
        if not fontFile or fontFile == "" then fontFile = "Fonts\\FRIZQT__.TTF" end
        local flags = (fontFlags and fontFlags ~= "") and fontFlags or "OUTLINE"
        durText:SetFont(fontFile, fontSize, flags)
        durText:Show()
        if auraButton.SetDurationText then
            pcall(auraButton.SetDurationText, auraButton, durText)
        end
    else
        durText:Hide()
        durText:SetText("")
        if auraButton.ClearDurationText then
            pcall(auraButton.ClearDurationText, auraButton)
        elseif auraButton.SetDurationText then
            pcall(auraButton.SetDurationText, auraButton, nil)
        end
    end
    local borderKeys = {
        "Border", "border",
        "DebuffBorder", "debuffBorder",
        "TempEnchantBorder", "tempEnchantBorder",
        "Symbol", "symbol",
        "Stealable", "stealable",
        "IconBorder", "iconBorder",
        "BorderFrame", "BorderTexture",
        "Overlay", "overlay"
    }
    for _, key in ipairs(borderKeys) do
        local b = auraButton[key]
        if b and b ~= icon then
            b:ClearAllPoints()
            b:SetAllPoints(iconRef)
            if b.SetSize then
                pcall(b.SetSize, b, size, size)
            end
        end
    end

    if auraButton.GetRegions then
        for _, region in ipairs({ auraButton:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= icon then
                region:ClearAllPoints()
                region:SetAllPoints(iconRef)
                if region.SetSize then
                    pcall(region.SetSize, region, size, size)
                end
            end
        end
    end

    -- Mini bar: a compact StatusBar below (or above) the icon that drains as the aura expires.
    if showMiniBar then
        if not auraButton.MiniBar then
            local mb = CreateFrame("StatusBar", nil, auraButton, "CrowAuraBarTemplate")
            Mixin(mb, CrowAuraBarMixin)
            if mb.OnLoad then mb:OnLoad() end
            auraButton.MiniBar = mb
            mb.__crowNeedsTicker = true
        end
        local mb = auraButton.MiniBar
        mb.settings = settings
        mb:ClearAllPoints()
        mb:SetSize(size, miniBarH)
        if miniBarPos == "ABOVE" then
            mb:SetPoint("BOTTOM", icon, "TOP", 0, miniBarGap)
        else
            mb:SetPoint("TOP", icon, "BOTTOM", 0, -miniBarGap)
        end
        if mb.TimeText then mb.TimeText:Hide() end
        if mb.NameText then mb.NameText:Hide() end
        if auraButton.SetDurationBar then
            local mbOpts = {
                direction     = (Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime) or 1,
                interpolation = (Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate)       or 0,
            }
            local ok = pcall(auraButton.SetDurationBar, auraButton, mb, mbOpts)
            mb.__crowNativeFill = ok
        end
        mb:Show()
        -- Lower mini bar's frame level below the parent button's so the parent's
        -- OVERLAY regions (duration text FontString) render on top of it.
        pcall(function()
            mb:SetFrameLevel(math.max(0, auraButton:GetFrameLevel() - 1))
        end)
    else
        if auraButton.MiniBar then auraButton.MiniBar:Hide() end
    end

    auraButton.__crowConfiguring = false
end

local function ResolveSortMethod(method)
    local enumTable = (Enum and Enum.AuraContainerSortMethod) or _G.AuraContainerSortMethod
    if enumTable then
        if method == "EXPIRATION" or method == "TIME" or method == "REMAINING_TIME" then
            return enumTable.ExpirationOnly or enumTable.Expiration or enumTable.Time or 1
        elseif method == "NAME" or method == "ALPHABETICAL" then
            return enumTable.Name or enumTable.Alphabetical or 2
        elseif method == "ADDED_TIME" or method == "DEFAULT" or method == "INDEX" then
            return enumTable.Default or enumTable.AddedTime or enumTable.Index or 0
        end
    end
    if method == "EXPIRATION" or method == "TIME" or method == "REMAINING_TIME" then
        return 1
    elseif method == "NAME" or method == "ALPHABETICAL" then
        return 2
    end
    return 0
end

local function ResolveSortDirection(direction)
    local enumTable = (Enum and Enum.AuraContainerSortDirection) or _G.AuraContainerSortDirection
    if enumTable then
        if direction == "DESCENDING" or direction == "REVERSE" then
            return enumTable.Reverse or enumTable.Descending or 1
        else
            return enumTable.Normal or enumTable.Ascending or 0
        end
    end
    if direction == "DESCENDING" or direction == "REVERSE" then
        return 1
    end
    return 0
end

function MOD:ConfigureContainerButtons(container, settings)
    if not container.buttons then container.buttons = {} end
                local filteredList = {}
                local lists = settings.lists
                if lists and #lists > 0 then
                    local reversedLists = {}
                    for idx = #lists, 1, -1 do
                        table.insert(reversedLists, lists[idx])
                    end
                    for _, listInfo in ipairs(reversedLists) do
                        local spellList = (self.db or MOD.db) and (self.db or MOD.db).profile and (self.db or MOD.db).profile.SpellLists and (self.db or MOD.db).profile.SpellLists[listInfo.name]
                        if spellList then
                            local isWhitelist = (listInfo.filterType == "whitelist" or listInfo.type == "whitelist")
                            for spellId in pairs(spellList) do
                                local id = tonumber(spellId) or spellId
                                filteredList[id] = isWhitelist
                            end
                        end
                    end
                end
                
                local includeList = {}
                local excludeList = {}
                for spellId, isWhitelist in pairs(filteredList) do
                    if isWhitelist then
                        includeList[spellId] = true
                    else
                        excludeList[spellId] = true
                    end
                end
                
                

                local candidateFilters = {}
                if next(includeList) ~= nil then
                    candidateFilters.includeSpellIDs = includeList
                end
                if next(excludeList) ~= nil then
                    candidateFilters.excludeSpellIDs = excludeList
                end

                local spacing    = settings.spacing    or 4
                local rowSpacing = settings.rowSpacing or 4
                local iconSize = settings.iconSize or 40
                local isBar = settings.showAsBars
                local elemWidth = isBar and (settings.barWidth or 160) or iconSize
                local elemHeight = isBar and (settings.barHeight or 20) or (iconSize + (settings.showMiniBar and 22 or 0))
                local aurasPerRow = tonumber(settings.aurasPerRow) or (isBar and 1 or 6)
                if aurasPerRow < 1 then aurasPerRow = 1 end

                local function MyAuraButtonInitializer(auraButton)
                    if isBar then
                        MOD:ConfigureAuraBar(auraButton, settings)
                    else
                        MOD:ConfigureAuraButton(auraButton, settings)
                    end
                
                    if auraButton.SetCancelAuraButtons then
                        auraButton:SetCancelAuraButtons("RightButtonUp")
                    end
                end

                local layout = {
                    elementWidth  = elemWidth,
                    elementHeight = elemHeight,
                    elementSpacing = spacing,
                    lineSpacing    = rowSpacing,
                    groupSpacing     = 0,
                    groupLineSpacing = 0,
                }

                local itemOptions = {
                    templateNames = { "CrowAuraButtonTemplate" },
                    initializeFrame = MyAuraButtonInitializer,
                    layout = layout,
                }

                if container.SetItemEnchantmentLayout then
                    pcall(container.SetItemEnchantmentLayout, container, layout)
                end
                if container.SetFlowLayoutElementSpacing then
                    pcall(container.SetFlowLayoutElementSpacing, container, spacing)
                end
                if container.SetFlowLayoutLineSpacing then
                    pcall(container.SetFlowLayoutLineSpacing, container, rowSpacing)
                end
                if container.SetFlowLayoutSpacing then
                    pcall(container.SetFlowLayoutSpacing, container, spacing, rowSpacing)
                end
                if container.SetElementSpacing then
                    pcall(container.SetElementSpacing, container, spacing)
                end
                if container.SetLineSpacing then
                    pcall(container.SetLineSpacing, container, rowSpacing)
                end
                if container.SetSpacing then
                    pcall(container.SetSpacing, container, spacing)
                end
                if container.SetGroupSpacing then
                    pcall(container.SetGroupSpacing, container, 0)
                end
                if container.SetFlowLayoutGroupSpacing then
                    pcall(container.SetFlowLayoutGroupSpacing, container, 0)
                end

                local rawSortMethod = (settings and settings.sortMethod) or "ADDED_TIME"
                local rawSortDirection = (settings and settings.sortDirection) or "ASCENDING"
                local sortMethodVal = ResolveSortMethod(rawSortMethod)
                local sortDirectionVal = ResolveSortDirection(rawSortDirection)

                local options = {
                    templateNames = { "CrowAuraButtonTemplate" },
                    maxFrameCount = settings.maxAuras,           
                    sortMethod = sortMethodVal,
                    sortDirection = sortDirectionVal,
                    sortType = rawSortMethod,
                    sortOrder = rawSortDirection,
                    initializeFrame = MyAuraButtonInitializer,
                    layout = layout,
                    candidateFilters = candidateFilters
                }
                
                if container.RemoveAuraGroup then
                    pcall(container.RemoveAuraGroup, container, container.groupName)
                end
                if container.ClearAuraGroups then
                    pcall(container.ClearAuraGroups, container)
                end
                if container.ClearItemEnchantments then
                    pcall(container.ClearItemEnchantments, container)
                end
                if container.UpdateAuraGroup then
                    pcall(container.UpdateAuraGroup, container, container.groupName, settings.filter, options)
                end

                if settings.customAuras and #settings.customAuras > 0 then
                    local addedSlots = {}
                    for _, ca in ipairs(settings.customAuras) do
                        if ca.type == "WeaponEnchant" or ca.type == (MOD.CustomAuraType and MOD.CustomAuraType.WeaponEnchant)
                           or ca.type == "ItemEnchant" or ca.type == (MOD.CustomAuraType and MOD.CustomAuraType.ItemEnchant) then
                            local slot = (ca.values and (ca.values.weaponSlot or ca.values.slotIndex)) or 0
                            slot = tonumber(slot) or 0
                            local alreadyExists = addedSlots[slot]
                                or (container.itemEnchantments and container.itemEnchantments[slot] ~= nil)
                                or (container.HasItemEnchantment and container:HasItemEnchantment(slot))
                                or (container.GetItemEnchantment and container:GetItemEnchantment(slot) ~= nil)

                            if not alreadyExists then
                                addedSlots[slot] = true
                                local ok, we = pcall(container.AddItemEnchantment, container, slot, itemOptions)
                                if ok and we and we.SetCancelAuraButtons and (not ca.values or ca.values.enableCancel ~= false) then
                                    we:SetCancelAuraButtons("RightButtonUp")
                                end
                            end
                        end
                    end
                end

                container:AddAuraGroup(container.groupName, settings.filter, options)

                if container.SetAuraGroupLayout then
                    pcall(container.SetAuraGroupLayout, container, container.groupName, layout)
                end
                if container.SetItemEnchantmentLayout then
                    pcall(container.SetItemEnchantmentLayout, container, layout)
                end

                if container.SetAuraGroupSortMethod then
                    pcall(container.SetAuraGroupSortMethod, container, container.groupName, sortMethodVal, sortDirectionVal)
                end
                if container.UpdateAllAuras then
                    pcall(container.UpdateAllAuras, container)
                end

                for _, child in ipairs({ container:GetChildren() }) do
                    if isBar then
                        MOD:ConfigureAuraBar(child, settings)
                    else
                        MOD:ConfigureAuraButton(child, settings)
                    end
                end
end


function MOD:UpdateContainers(groupName)
    if not self.db or not self.db.profile or not self.db.profile.AuraGroups then
        return
    end
    
    -- Hide disabled or removed containers
    for name, c in pairs(self.containers) do
        local settings = self.db.profile.AuraGroups[name]
        if groupName == nil or groupName == name then
            if not settings or not settings.enabled then
                c:Hide()
                c:ClearAllPoints()
                self:HideDummyAuras(name)
                if self.anchors[name] then
                    self.anchors[name]:Hide()
                end
            end
        end
    end
    
    for name, settings in pairs(self.db.profile.AuraGroups) do
        if groupName == nil or groupName == name then
            if settings.enabled then
                local container = self:RecreateContainer(name)
                container.dbSettings = settings
                container.groupName = name
                container.unit = settings.unit or "player"
                if container.SetUnit then
                    container:SetUnit(container.unit)
                end
    
                local isBar = settings.showAsBars
                local elemWidth = isBar and (settings.barWidth or 160) or (settings.iconSize or 40)
                local elemHeight = isBar and (settings.barHeight or 20) or ((settings.iconSize or 40) + (settings.showMiniBar and 22 or 0))
                local spacing    = settings.spacing    or 4
                local rowSpacing = settings.rowSpacing or 4
                local aurasPerRow = tonumber(settings.aurasPerRow) or (isBar and 1 or 6)
                if aurasPerRow < 1 then aurasPerRow = 1 end
    
                local flowDir = settings.flowDirection or MOD.FlowDirection.RIGHTDOWN
                local hGrowth, vGrowth
                local layoutAnchorPoint = "TOPLEFT"
                local FlowDir = (AnchorUtil and AnchorUtil.FlowDirection) or {
                    Left = 1,
                    Right = 2,
                    Up = 3,
                    Down = 4,
                }
    
                if flowDir == MOD.FlowDirection.RIGHTDOWN or flowDir == "RIGHTDOWN" or flowDir == 1 then
                    hGrowth = FlowDir.Right
                    vGrowth = FlowDir.Down
                    layoutAnchorPoint = "TOPLEFT"
                elseif flowDir == MOD.FlowDirection.RIGHTUP or flowDir == "RIGHTUP" or flowDir == 2 then
                    hGrowth = FlowDir.Right
                    vGrowth = FlowDir.Up
                    layoutAnchorPoint = "BOTTOMLEFT"
                elseif flowDir == MOD.FlowDirection.LEFTDOWN or flowDir == "LEFTDOWN" or flowDir == 3 then
                    hGrowth = FlowDir.Left
                    vGrowth = FlowDir.Down
                    layoutAnchorPoint = "TOPRIGHT"
                elseif flowDir == MOD.FlowDirection.LEFTUP or flowDir == "LEFTUP" or flowDir == 4 then
                    hGrowth = FlowDir.Left
                    vGrowth = FlowDir.Up
                    layoutAnchorPoint = "BOTTOMRIGHT"
                else
                    hGrowth = FlowDir.Right
                    vGrowth = FlowDir.Down
                    layoutAnchorPoint = "TOPLEFT"
                end
    
                if container.SetFlowLayoutAxis then
                    local axis = (AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowLayoutAxis.Horizontal) or 0
                    container:SetFlowLayoutAxis(axis)
                end
    
                if container.SetFlowLayoutAnchorPoint then
                    container:SetFlowLayoutAnchorPoint(layoutAnchorPoint)
                end
    
                if container.SetFlowLayoutGrowthDirection and FlowDir then
                    container:SetFlowLayoutGrowthDirection(hGrowth, vGrowth)
                end
    
                local maxLineSize = (aurasPerRow * elemWidth) + (math.max(0, aurasPerRow - 1) * spacing)
                if container.SetFlowLayoutMaximumLineSize then
                    container:SetFlowLayoutMaximumLineSize(maxLineSize)
                end
                if container.SetFlowLayoutElementSpacing then
                    pcall(container.SetFlowLayoutElementSpacing, container, spacing)
                end
                if container.SetFlowLayoutLineSpacing then
                    pcall(container.SetFlowLayoutLineSpacing, container, rowSpacing)
                end
                if container.SetFlowLayoutSpacing then
                    pcall(container.SetFlowLayoutSpacing, container, spacing, rowSpacing)
                end
                if container.SetElementSpacing then
                    pcall(container.SetElementSpacing, container, spacing)
                end
                if container.SetLineSpacing then
                    pcall(container.SetLineSpacing, container, rowSpacing)
                end
                if container.SetSpacing then
                    pcall(container.SetSpacing, container, spacing)
                end
                if container.SetGroupSpacing then
                    pcall(container.SetGroupSpacing, container, 0)
                end
                if container.SetFlowLayoutGroupSpacing then
                    pcall(container.SetFlowLayoutGroupSpacing, container, 0)
                end
                
                
                -- Basic filter for the container
                local filter = settings.filter or "HELPFUL"
                local maxCount = settings.maxAuras or 10
                if container.AddAuraFilter then
                    container:AddAuraFilter(filter, { maxFrameCount = maxCount })
                end
                if container.SetFilter then
                    container:SetFilter(filter)
                end
                
                -- Positioning
                container:ClearAllPoints()
                local anchor = settings.anchor or "CENTER"
                container:SetSize(elemWidth, elemHeight)
                container:SetPoint(anchor, UIParent, anchor, settings.x or 0, settings.y or 0)
                
                -- Setup buttons/bars
                self:ConfigureContainerButtons(container, settings)
                
                -- Setup dummy auras if preview is enabled
                self:UpdateDummyAuras(name, container, settings)
                
                container:Show()
                if container.UpdateAllAuras then
                    container:UpdateAllAuras()
                end
                if container.Update then
                    container:Update()
                end
            end
        end
    end
    
    if self.isMoving then
        self:ShowAnchors()
    end

    -- Initialize central ticker after secure frame creation completes using pcall-safe checks
    local function tryInitTicker()
        local okTimer, timerMod = pcall(function() return C_Timer end)
        if not okTimer or type(timerMod) ~= "table" or type(timerMod.After) ~= "function" then
            return
        end
        if self._crowTickerInitScheduled then return end
        self._crowTickerInitScheduled = true
        timerMod.After(0, function()
            pcall(function()
                self._crowTickerInitScheduled = nil
                Crow._activeBars = Crow._activeBars or setmetatable({}, { __mode = "k" })
                for _, container in pairs(self.containers) do
                    for _, child in ipairs({ container:GetChildren() }) do
                        local bar = child.Bar
                        if bar and bar.__crowNeedsTicker then
                            Crow._activeBars[bar] = true
                            bar.__crowNeedsTicker = nil
                        end
                        local mb = child.MiniBar
                        if mb and mb.__crowNeedsTicker then
                            Crow._activeBars[mb] = true
                            mb.__crowNeedsTicker = nil
                        end
                    end
                end
                local okNewTicker, NewTicker = pcall(function() return C_Timer and C_Timer.NewTicker end)
                if okNewTicker and type(NewTicker) == "function" then
                    -- create ticker in a pcall to avoid boolean tests on tainted globals
                    pcall(function()
                        if not Crow._activeBarTicker then
                            Crow._activeBarTicker = NewTicker(0.2, function()
                                for b in pairs(Crow._activeBars) do
                                    if type(b) == "table" then
                                        -- Avoid testing the 'IsShown' boolean (may be a secret boolean); just attempt an update safely
                                        pcall(CrowAuraBarMixin.OnUpdate, b, 0.2)
                                    end
                                end
                            end)
                        end
                    end)
                end
            end)
        end)
    end
    pcall(tryInitTicker)
end

function MOD:GetOrCreateAnchor(name)
    local anchor = self.anchors[name]
    if anchor then return anchor end
    
    local ok, frame = pcall(CreateFrame, "Button", "CrowAnchor_" .. name, UIParent, "BackdropTemplate")
    if not (ok and frame) then
        frame = CreateFrame("Button", "CrowAnchor_" .. name, UIParent)
    end
    anchor = frame
    self.anchors[name] = anchor
    anchor.groupName = name
    
    anchor:SetSize(40, 40)
    anchor:SetFrameStrata("HIGH")
    anchor:SetClampedToScreen(true)
    anchor:EnableMouse(true)
    anchor:SetMovable(true)
    anchor:RegisterForDrag("LeftButton")
    
    local bg = anchor:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(anchor)
    bg:SetColorTexture(0.1, 0.1, 0.25, 0.85)
    anchor.bg = bg
    
    local border = anchor:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.3, 0.6, 1.0, 0.8)
    anchor.border = border
    
    bg:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1, 1)
    
    local text = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    text:SetText(name)
    anchor.text = text

    local hArrow = anchor:CreateTexture(nil, "OVERLAY")
    hArrow:SetVertexColor(1, 0.82, 0, 0.95)
    anchor.hArrow = hArrow

    local vArrow = anchor:CreateTexture(nil, "OVERLAY")
    vArrow:SetVertexColor(1, 0.82, 0, 0.95)
    anchor.vArrow = vArrow
    
    anchor:SetScript("OnDragStart", function(self)
        self:StartMoving()
        self.isMoving = true
    end)
    
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isMoving = false
        MOD:UpdateGroupPositionFromAnchor(self.groupName, self, true)
    end)
    
    anchor:SetScript("OnUpdate", function(self)
        if self.isMoving then
            MOD:UpdateGroupPositionFromAnchor(self.groupName, self, false)
        end
    end)
    
    anchor:SetScript("OnEnter", function(self)
        local settings = MOD.db and MOD.db.profile and MOD.db.profile.AuraGroups and MOD.db.profile.AuraGroups[self.groupName]
        local flowDirName = "Down and Right"
        if settings then
            local fd = settings.flowDirection
            if fd == 2 or fd == "RIGHTUP" then flowDirName = "Up and Right"
            elseif fd == 3 or fd == "LEFTDOWN" then flowDirName = "Down and Left"
            elseif fd == 4 or fd == "LEFTUP" then flowDirName = "Up and Left"
            end
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.groupName, 1, 1, 1)
        GameTooltip:AddLine("Growth: " .. flowDirName, 1, 0.82, 0)
        GameTooltip:AddLine("Drag to move this aura group.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    
    anchor:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return anchor
end

function MOD:UpdateAnchorPosition(name)
    local anchor = self.anchors[name]
    local settings = self.db.profile.AuraGroups[name]
    if not anchor or not settings then return end
    
    local isBar = settings.showAsBars
    local elemWidth = isBar and (settings.barWidth or 160) or (settings.iconSize or 40)
    local elemHeight = isBar and (settings.barHeight or 20) or ((settings.iconSize or 40) + (settings.showMiniBar and 22 or 0))
    
    anchor:SetSize(elemWidth, elemHeight)
    anchor:ClearAllPoints()
    local anchorPoint = settings.anchor or "CENTER"
    anchor:SetPoint(anchorPoint, UIParent, anchorPoint, settings.x or 0, settings.y or 0)
    
    if anchor.text then
        anchor.text:SetText(name)
        local fontFile, _, fontFlags = anchor.text:GetFont()
        if not fontFile or fontFile == "" then fontFile = "Fonts\\FRIZQT__.TTF" end
        local fontSize = math.min(12, math.max(8, math.floor(elemHeight * 0.3)))
        if not isBar and elemHeight <= 45 then
            fontSize = math.min(10, math.max(8, math.floor(elemHeight * 0.26)))
        end
        anchor.text:SetFont(fontFile, fontSize, "OUTLINE")
    end

    local flowDir = settings.flowDirection or MOD.FlowDirection.RIGHTDOWN
    -- Arrow-Left-Up / Arrow-Right-Up do not exist as standalone interface textures.
    -- Derive horizontal arrows by rotating Arrow-Up-Up 90° (CCW = left, CW = right).
    local vTex = "Interface\\Buttons\\Arrow-Down-Up"
    local hRot = -math.pi / 2  -- clockwise 90° → right
    local vRot = 0

    if flowDir == MOD.FlowDirection.RIGHTDOWN or flowDir == "RIGHTDOWN" or flowDir == 1 then
        vTex = "Interface\\Buttons\\Arrow-Down-Up"; vRot = 0
        hRot = -math.pi / 2  -- right
    elseif flowDir == MOD.FlowDirection.RIGHTUP or flowDir == "RIGHTUP" or flowDir == 2 then
        vTex = "Interface\\Buttons\\Arrow-Up-Up"; vRot = 0
        hRot = -math.pi / 2  -- right
    elseif flowDir == MOD.FlowDirection.LEFTDOWN or flowDir == "LEFTDOWN" or flowDir == 3 then
        vTex = "Interface\\Buttons\\Arrow-Down-Up"; vRot = 0
        hRot = math.pi / 2   -- left
    elseif flowDir == MOD.FlowDirection.LEFTUP or flowDir == "LEFTUP" or flowDir == 4 then
        vTex = "Interface\\Buttons\\Arrow-Up-Up"; vRot = 0
        hRot = math.pi / 2   -- left
    end

    local arrowSize = math.min(16, math.max(9, math.floor(elemHeight * 0.42)))
    if anchor.hArrow then
        anchor.hArrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
        anchor.hArrow:SetRotation(hRot)
        anchor.hArrow:SetSize(arrowSize, arrowSize)
        anchor.hArrow:Show()
    end
    if anchor.vArrow then
        anchor.vArrow:SetTexture(vTex)
        anchor.vArrow:SetRotation(vRot)
        anchor.vArrow:SetSize(arrowSize, arrowSize)
        anchor.vArrow:Show()
    end

    if isBar then
        if anchor.vArrow and anchor.hArrow then
            anchor.vArrow:ClearAllPoints()
            anchor.vArrow:SetPoint("RIGHT", anchor, "RIGHT", -4, 0)
            anchor.hArrow:ClearAllPoints()
            anchor.hArrow:SetPoint("RIGHT", anchor.vArrow, "LEFT", -2, 0)
        end
        if anchor.text then
            anchor.text:ClearAllPoints()
            anchor.text:SetPoint("LEFT", anchor, "LEFT", 6, 0)
            if anchor.hArrow then
                anchor.text:SetPoint("RIGHT", anchor.hArrow, "LEFT", -4, 0)
            else
                anchor.text:SetPoint("RIGHT", anchor, "RIGHT", -6, 0)
            end
            anchor.text:SetJustifyH("LEFT")
        end
    else
        if anchor.hArrow and anchor.vArrow then
            anchor.hArrow:ClearAllPoints()
            anchor.hArrow:SetPoint("BOTTOM", anchor, "BOTTOM", -arrowSize / 2 - 1, 2)
            anchor.vArrow:ClearAllPoints()
            anchor.vArrow:SetPoint("BOTTOM", anchor, "BOTTOM", arrowSize / 2 + 1, 2)
        end
        if anchor.text then
            anchor.text:ClearAllPoints()
            anchor.text:SetPoint("TOP", anchor, "TOP", 0, -3)
            anchor.text:SetPoint("LEFT", anchor, "LEFT", 2, 0)
            anchor.text:SetPoint("RIGHT", anchor, "RIGHT", -2, 0)
            anchor.text:SetJustifyH("CENTER")
        end
    end
end

function MOD:UpdateGroupPositionFromAnchor(groupName, anchorFrame, isFinal)
    local settings = self.db.profile.AuraGroups[groupName]
    if not settings then return end
    
    local anchorPoint = settings.anchor or "CENTER"
    local x, y = 0, 0
    
    local uLeft = UIParent:GetLeft() or 0
    local uBottom = UIParent:GetBottom() or 0
    local uWidth = UIParent:GetWidth() or 0
    local uHeight = UIParent:GetHeight() or 0
    
    local aLeft = anchorFrame:GetLeft()
    local aBottom = anchorFrame:GetBottom()
    local aWidth = anchorFrame:GetWidth() or 0
    local aHeight = anchorFrame:GetHeight() or 0
    
    if not aLeft or not aBottom then return end
    
    local aCenterX = aLeft + aWidth / 2
    local aCenterY = aBottom + aHeight / 2
    local uCenterX = uLeft + uWidth / 2
    local uCenterY = uBottom + uHeight / 2
    
    if anchorPoint == "CENTER" then
        x = aCenterX - uCenterX
        y = aCenterY - uCenterY
    elseif anchorPoint == "TOPLEFT" then
        x = aLeft - uLeft
        y = (aBottom + aHeight) - (uBottom + uHeight)
    elseif anchorPoint == "TOPRIGHT" then
        x = (aLeft + aWidth) - (uLeft + uWidth)
        y = (aBottom + aHeight) - (uBottom + uHeight)
    elseif anchorPoint == "BOTTOMLEFT" then
        x = aLeft - uLeft
        y = aBottom - uBottom
    elseif anchorPoint == "BOTTOMRIGHT" then
        x = (aLeft + aWidth) - (uLeft + uWidth)
        y = aBottom - uBottom
    elseif anchorPoint == "TOP" then
        x = aCenterX - uCenterX
        y = (aBottom + aHeight) - (uBottom + uHeight)
    elseif anchorPoint == "BOTTOM" then
        x = aCenterX - uCenterX
        y = aBottom - uBottom
    elseif anchorPoint == "LEFT" then
        x = aLeft - uLeft
        y = aCenterY - uCenterY
    elseif anchorPoint == "RIGHT" then
        x = (aLeft + aWidth) - (uLeft + uWidth)
        y = aCenterY - uCenterY
    end
    
    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    
    settings.x = x
    settings.y = y
    
    local container = self.containers[groupName]
    if container then
        container:ClearAllPoints()
        container:SetPoint(anchorPoint, UIParent, anchorPoint, x, y)
    end
    
    local acereg = LibStub("AceConfigRegistry-3.0", true)
    if acereg and acereg:GetOptionsTable("Crow") then
        acereg:NotifyChange("Crow")
    end
end

-- Reconfigures buttons in a single group without recreating any frames.
-- Use for settings that only affect visual properties of existing buttons
-- (e.g. font size, position offsets) to avoid the flicker of a full redraw.
function MOD:SoftRefreshGroup(groupName)
    local settings = self.db and self.db.profile and self.db.profile.AuraGroups and self.db.profile.AuraGroups[groupName]
    local container = self.containers and self.containers[groupName]
    if not settings or not container then return end
    local isBar = settings.showAsBars
    for _, child in ipairs({ container:GetChildren() }) do
        if isBar then
            self:ConfigureAuraBar(child, settings)
        else
            self:ConfigureAuraButton(child, settings)
        end
    end
    if settings.showDummyAuras then
        self:UpdateDummyAuras(groupName, container, settings)
    end
end

function MOD:ShowAnchors()
    for name, settings in pairs(self.db.profile.AuraGroups) do
        if settings.enabled then
            local anchor = self:GetOrCreateAnchor(name)
            self:UpdateAnchorPosition(name)
            anchor:Show()
        end
    end
end

function MOD:HideAnchors()
    for _, anchor in pairs(self.anchors) do
        anchor:Hide()
    end
end

function MOD:ToggleMoveMode()
    self:SetMoveMode(not self.isMoving)
end

function MOD:SetMoveMode(enable)
    if enable and ((InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))) then
        print("|cff6699ffCrow|r: Move mode cannot be used in combat.")
        return
    end
    self.isMoving = enable
    if self.isMoving then
        self:ShowAnchors()
        print("|cff6699ffCrow|r: Move mode enabled. Drag group anchors to reposition.")
    else
        self:HideAnchors()
        self:UpdateContainers()
        print("|cff6699ffCrow|r: Groups locked.")
    end
    
    local acereg = LibStub("AceConfigRegistry-3.0", true)
    if acereg and acereg:GetOptionsTable("Crow") then
        acereg:NotifyChange("Crow")
    end
end

function MOD:ShouldShowAura(groupName, aura)
    local settings = self.db.profile.AuraGroups[groupName]
    if not settings or not settings.lists or #settings.lists == 0 then return true end
    
    for _, listInfo in ipairs(settings.lists) do
        local list = self.db.profile.SpellLists[listInfo.name]
        if list and list[aura.spellId] then
            return listInfo.filterType == "whitelist"
        end
    end
    
    -- Default behavior: if there's a whitelist, hide by default. If only blacklists, show by default.
    local hasWhitelist = false
    for _, l in ipairs(settings.lists) do
        if l.filterType == "whitelist" then hasWhitelist = true; break end
    end
    return not hasWhitelist
end

function MOD:ToggleOptions()
    if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        print("|cff6699ffCrow|r: Options cannot be opened in combat.")
        return
    end
    if CrowOptions and CrowOptions.Open then
        CrowOptions:Open()
    else
        print("Crow: Options not loaded.")
    end
end
