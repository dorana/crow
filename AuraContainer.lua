local _addonName, addonTbl = ...

CrowAuraBarMixin = {}
addonTbl.CrowAuraBarMixin = CrowAuraBarMixin
addonTbl.Mixins = addonTbl.Mixins or {}
addonTbl.Mixins.CrowAuraBarMixin = CrowAuraBarMixin

function CrowAuraBarMixin:OnLoad()
    self:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local tex = self:GetStatusBarTexture()
    if tex then
        tex:SetHorizTile(false)
    end
    if not self.bg then
        local bg = self:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(self)
        bg:SetColorTexture(0, 0, 0, 0.5)
        self.bg = bg
    end
    if not self.TimeText then
        local timeText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timeText:SetPoint("RIGHT", self, "RIGHT", -4, 0)
        timeText:SetJustifyH("RIGHT")
        self.TimeText = timeText
    end
    if not self.NameText then
        local nameText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", self, "LEFT", 4, 0)
        nameText:SetPoint("RIGHT", self.TimeText, "LEFT", -4, 0)
        nameText:SetJustifyH("LEFT")
        self.NameText = nameText
    end
    self:SetMinMaxValues(0, 1)
    self:SetValue(1)
    self:SetStatusBarColor(0.25, 0.55, 0.95)
    self:Show()

    self:SetScript("OnUpdate", function(bar, elapsed)
        CrowAuraBarMixin.OnUpdate(bar, elapsed)
    end)
end

function CrowAuraBarMixin:OnUpdate(elapsed)
    local auraButton = self:GetParent()
    if not auraButton then return end

    local currentSettings = self.settings or auraButton.__crowSettings
    local isDurationShown = not currentSettings or currentSettings.showDuration ~= false
    local filterType = (currentSettings and currentSettings.filter) or "HELPFUL"

    if filterType == "HARMFUL" then
        self:SetStatusBarColor(0.8, 0.2, 0.2)
    else
        self:SetStatusBarColor(0.25, 0.55, 0.95)
    end

    -- Populate CrowNameText every tick so it works regardless of which hook path fired.
    -- Path 1: auraData cached by applyAuraToBar (our mixin or Blizzard's AuraButtonMixin).
    -- Path 2: auraInstanceID stamped on the button by Blizzard's container system.
    local nameLabel = auraButton.CrowNameText
    if nameLabel then
        local name
        local ad = auraButton.auraData
        if ad and type(ad.name) == "string" and ad.name ~= "" then
            name = ad.name
        end
        if not name then
            pcall(function()
                local container = auraButton:GetParent()
                local unit = (container and container.unit) or auraButton.unit or "player"
                local iid = auraButton.auraInstanceID
                if iid then
                    local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, iid)
                    if data and type(data.name) == "string" then name = data.name end
                end
            end)
        end
        if name then
            nameLabel:SetText(name)
        end
    end

    -- If native fill is registered Blizzard drives bar value and TimeText automatically;
    -- fall back to manual updates only when SetDurationBar was unavailable.
    if not self.__crowNativeFill then
        local cdStart = self.cdStart
        local cdDuration = self.cdDuration
        if type(cdStart) == "number" and type(cdDuration) == "number" and cdDuration > 0 then
            local now = GetTime and GetTime() or 0
            local remaining = math.max(0, (cdStart + cdDuration) - now)
            self:SetMinMaxValues(0, cdDuration)
            self:SetValue(remaining)
            if self.TimeText and isDurationShown then
                if remaining >= 3600 then
                    self.TimeText:SetFormattedText("%dh", math.floor(remaining / 3600))
                elseif remaining >= 60 then
                    self.TimeText:SetFormattedText("%dm", math.floor(remaining / 60))
                else
                    self.TimeText:SetFormattedText("%.0fs", remaining)
                end
                self.TimeText:Show()
            elseif self.TimeText then
                self.TimeText:Hide()
            end
        elseif self.TimeText then
            self.TimeText:Hide()
        end
    end
end

CrowAuraButtonMixin = {}
addonTbl.CrowAuraButtonMixin = CrowAuraButtonMixin
addonTbl.Mixins.CrowAuraButtonMixin = CrowAuraButtonMixin

function CrowAuraButtonMixin:OnLoad()
    self:SetupRegions()
end

function CrowAuraButtonMixin:SetupRegions()
    if not self.Icon then
        local icon = self:CreateTexture(nil, "BACKGROUND")
        self.Icon = icon
    end
    if self.SetIcon and self.Icon then
        pcall(self.SetIcon, self, self.Icon)
    end

    if not self.Cooldown then
        local cd = CreateFrame("Cooldown", nil, self, "CooldownFrameTemplate")
        cd:SetHideCountdownNumbers(true)
        cd:SetDrawBling(false)
        cd:EnableMouse(false)
        if cd.EnableMouseMotion then
            cd:EnableMouseMotion(false)
        end
        self.Cooldown = cd
    end
    if self.SetDurationCooldown and self.Cooldown then
        pcall(self.SetDurationCooldown, self, self.Cooldown)
    end

    if not self.DurationText then
        local durText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.DurationText = durText
    end

    if not self.CountText then
        local countText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        countText:SetJustifyH("RIGHT")
        self.CountText = countText
    end
    if self.SetApplicationCount then
        pcall(self.SetApplicationCount, self, self.CountText, {})
    elseif self.SetApplicationsText then
        pcall(self.SetApplicationsText, self, self.CountText)
    elseif self.SetCountText then
        pcall(self.SetCountText, self, self.CountText)
    end

    if not self.Bar then
        local bar = CreateFrame("StatusBar", nil, self, "CrowAuraBarTemplate")
        Mixin(bar, CrowAuraBarMixin)
        if bar.OnLoad then
            bar:OnLoad()
        end
        self.Bar = bar
        -- Mark bar to be registered for the central update ticker after secure layout creation finishes
        self.Bar.__crowNeedsTicker = true
    end
    if self.Bar and not self.Bar:GetPoint() then
        if self.Icon then
            self.Bar:SetPoint("LEFT", self.Icon, "RIGHT", 2, 0)
            self.Bar:SetPoint("RIGHT", self, "RIGHT", 0, 0)
            self.Bar:SetPoint("TOP", self, "TOP", 0, 0)
            self.Bar:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
        else
            self.Bar:SetAllPoints(self)
        end
    end
    if self.Bar then
        self.Bar:Show()
    end
    
    if self.SetNameText and self.Bar and self.Bar.NameText then
        pcall(self.SetNameText, self, self.Bar.NameText)
    elseif self.SetAuraName and self.Bar and self.Bar.NameText then
        pcall(self.SetAuraName, self, self.Bar.NameText)
    elseif self.SetSpellName and self.Bar and self.Bar.NameText then
        pcall(self.SetSpellName, self, self.Bar.NameText)
    end
end

function CrowAuraButtonMixin:Update(aura)
    if self.Bar then
        CrowAuraBarMixin.OnUpdate(self.Bar, 0)
    end
end

local function applyAuraToBar(btn, aura)
    local b = btn.Bar
    if not b then return end
    btn.auraData = aura  -- cache so the ticker can read it regardless of hook path
    if aura then
        local name = type(aura.name) == "string" and aura.name ~= "" and aura.name
        if name then
            local nl = btn.CrowNameText
            if nl then nl:SetText(name) end
        end
    end
    CrowAuraBarMixin.OnUpdate(b, 0)
end

function CrowAuraButtonMixin:UpdateAura(aura)
    applyAuraToBar(self, aura)
end

function CrowAuraButtonMixin:SetAura(aura)
    applyAuraToBar(self, aura)
end

function CrowAuraButtonMixin:OnUpdate(elapsed)
    if self.Bar and self.Bar:IsShown() then
        CrowAuraBarMixin.OnUpdate(self.Bar, elapsed)
    end
end
