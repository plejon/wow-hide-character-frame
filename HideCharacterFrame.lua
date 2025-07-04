local frameHandler = CreateFrame("FRAME");
local _, playerClass = UnitClass("player");

-- Default settings
local defaults = {
    enabled = true,
    hideCombat = true,
    hideFullHealth = true,
    hideFullPower = true,
    hideNoTarget = true,
    hideNoDebuff = true,
    hidePetFullHealth = true,
    hidePetHappy = true,
    hideRageZero = true,
    fadeOutDuration = 0.1
}

-- Initialize saved variables
HideCharacterFrameDB = HideCharacterFrameDB or defaults

-- Ensure all settings exist
for k, v in pairs(defaults) do
    if HideCharacterFrameDB[k] == nil then
        HideCharacterFrameDB[k] = v
    end
end

local db = HideCharacterFrameDB

-- Generic utility functions for basic checks
local function shouldShowForCombat()
    return db.hideCombat and UnitAffectingCombat("player")
end

local function shouldShowForDebuffs()
    if db.hideNoDebuff then
        local name = UnitDebuff("player", 1)
        return name ~= nil
    end
    return false
end

local function shouldShowForTarget()
    return db.hideNoTarget and UnitExists("target")
end

local function shouldShowForHealth()
    return db.hideFullHealth and UnitHealth("player") < UnitHealthMax("player")
end

local function shouldShowForPower()
    local _, powerToken = UnitPowerType("player")

    if powerToken == "RAGE" then
        local currentRage = UnitPower("player")
        return db.hideRageZero and currentRage > 0
    else
        -- Normal power handling for non-rage classes
        return db.hideFullPower and UnitPower("player") < UnitPowerMax("player")
    end
end

-- Common pet logic for classes with pets
local function shouldShowForPet(includeHappiness)
    if not UnitExists("pet") then
        return false
    end

    -- Show frame if pet is dead
    if UnitIsDead("pet") then
        return true
    end

    -- Pet health check
    if db.hidePetFullHealth then
        local petHealth = UnitHealth("pet")
        local petMaxHealth = UnitHealthMax("pet")
        if petHealth < petMaxHealth then
            return true
        end
    end

    -- Pet happiness check (Hunter only)
    if includeHappiness and db.hidePetHappy then
        local petHappiness = GetPetHappiness()
        if petHappiness and petHappiness < 3 then
            return true
        end
    end

    return false
end

-- Generic logic for basic conditions
local function shouldShowForBasicConditions()
    return shouldShowForCombat() or shouldShowForDebuffs() or shouldShowForTarget() or shouldShowForHealth() or shouldShowForPower()
end

-- Hunter-specific logic
local function shouldShowForHunter()
    return shouldShowForBasicConditions() or shouldShowForPet(true)
end

-- Warlock-specific logic
local function shouldShowForWarlock()
    return shouldShowForBasicConditions() or shouldShowForPet(false)
end

-- Generic class logic (for classes without special handling)
local function shouldShowForGenericClass()
    return shouldShowForBasicConditions()
end

-- Main function that delegates to class-specific handlers
local function shouldShowFrame()
    -- If addon is disabled, always show frame
    if not db.enabled then
        return true
    end

    -- Delegate to appropriate class-specific function
    if playerClass == "HUNTER" then
        return shouldShowForHunter()
    elseif playerClass == "WARLOCK" then
        return shouldShowForWarlock()
    else
        return shouldShowForGenericClass()
    end
end

-- Helper functions for event management
local function registerUpdateEvents()
    frameHandler:RegisterEvent("UNIT_HEALTH_FREQUENT", "player")
    frameHandler:RegisterEvent("UNIT_POWER_FREQUENT", "player")
    frameHandler:RegisterEvent("PLAYER_TARGET_CHANGED")
    frameHandler:RegisterEvent("UNIT_AURA", "player")
end

local function unregisterUpdateEvents()
    frameHandler:UnregisterEvent("UNIT_HEALTH_FREQUENT", "player")
    frameHandler:UnregisterEvent("UNIT_POWER_FREQUENT", "player")
    frameHandler:UnregisterEvent("PLAYER_TARGET_CHANGED")
    frameHandler:UnregisterEvent("UNIT_AURA", "player")
end

-- Function to set frame visibility with fade out effect
local function setFrameVisibility(visible)
    if visible then
        -- Show frames immediately
        PlayerFrame:SetAlpha(1)
        if (playerClass == "HUNTER" or playerClass == "WARLOCK") and PetFrame then
            PetFrame:SetAlpha(1)
        end
    else
        -- Fade out frames using configurable duration
        UIFrameFadeOut(PlayerFrame, db.fadeOutDuration, PlayerFrame:GetAlpha(), 0)
        if (playerClass == "HUNTER" or playerClass == "WARLOCK") and PetFrame then
            UIFrameFadeOut(PetFrame, db.fadeOutDuration, PetFrame:GetAlpha(), 0)
        end
    end
end

-- Options Panel Creation (defined before event handler)
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "HideCharacterFrameOptionsPanel", UIParent)
    panel.name = "HideCharacterFrame"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("HideCharacterFrame Options")

    -- Version info
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Configure when to hide the character frame")

    local yOffset = -60
    local checkboxes = {}

    -- Helper function to create a bordered group section
    local function CreateGroupSection(name, width, height, yPos)
        local group = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        group:SetPoint("TOPLEFT", 16, yPos)
        group:SetSize(width, height)

        -- Create border backdrop (Classic Era compatible)
        if group.SetBackdrop then
            group:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 16,
                insets = { left = 3, right = 3, top = 5, bottom = 3 }
            })
            group:SetBackdropColor(0, 0, 0, 0.2)
            group:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        else
            -- Fallback for versions without backdrop support - create simple border
            local border = CreateFrame("Frame", nil, group)
            border:SetAllPoints(group)
            border:SetFrameLevel(group:GetFrameLevel() - 1)

            -- Create a simple colored border
            local bg = group:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(group)
            bg:SetColorTexture(0, 0, 0, 0.2)

            -- Create border lines
            local top = group:CreateTexture(nil, "BORDER")
            top:SetHeight(1)
            top:SetPoint("TOPLEFT", group, "TOPLEFT", 0, 0)
            top:SetPoint("TOPRIGHT", group, "TOPRIGHT", 0, 0)
            top:SetColorTexture(0.4, 0.4, 0.4, 1)

            local bottom = group:CreateTexture(nil, "BORDER")
            bottom:SetHeight(1)
            bottom:SetPoint("BOTTOMLEFT", group, "BOTTOMLEFT", 0, 0)
            bottom:SetPoint("BOTTOMRIGHT", group, "BOTTOMRIGHT", 0, 0)
            bottom:SetColorTexture(0.4, 0.4, 0.4, 1)

            local left = group:CreateTexture(nil, "BORDER")
            left:SetWidth(1)
            left:SetPoint("TOPLEFT", group, "TOPLEFT", 0, 0)
            left:SetPoint("BOTTOMLEFT", group, "BOTTOMLEFT", 0, 0)
            left:SetColorTexture(0.4, 0.4, 0.4, 1)

            local right = group:CreateTexture(nil, "BORDER")
            right:SetWidth(1)
            right:SetPoint("TOPRIGHT", group, "TOPRIGHT", 0, 0)
            right:SetPoint("BOTTOMRIGHT", group, "BOTTOMRIGHT", 0, 0)
            right:SetColorTexture(0.4, 0.4, 0.4, 1)
        end

        -- Group title
        local groupTitle = group:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        groupTitle:SetPoint("TOPLEFT", group, "TOPLEFT", 10, -10)
        groupTitle:SetText(name)
        groupTitle:SetTextColor(1, 0.82, 0, 1) -- Gold color like Questie

        return group, groupTitle
    end

    local function CreateCheckbox(parent, key, label, tooltip, xOffset, yPos)
        local cb = CreateFrame("CheckButton", "HideCharacterFrame_" .. key, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yPos)
        cb.Text:SetText(label)
        cb:SetChecked(db[key])

        if tooltip then
            cb.tooltipText = tooltip
        end

        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked()
            -- Update frame visibility immediately
            setFrameVisibility(shouldShowFrame())
        end)

        checkboxes[key] = cb
        return cb
    end

    local function CreateSlider(parent, key, label, tooltip, min, max, step, xOffset, yPos)
        local slider = CreateFrame("Slider", "HideCharacterFrame_" .. key, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yPos)
        slider:SetMinMaxValues(min, max)
        slider:SetValue(db[key])
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        
        -- Set label
        slider.Text:SetText(label)
        
        -- Set low/high labels
        slider.Low:SetText(tostring(min))
        slider.High:SetText(tostring(max))
        
        -- Value display
        local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        valueText:SetPoint("TOP", slider, "BOTTOM", 0, -5)
        valueText:SetText(string.format("%.1f seconds", db[key]))
        
        if tooltip then
            slider.tooltipText = tooltip
        end
        
        slider:SetScript("OnValueChanged", function(self, value)
            db[key] = value
            valueText:SetText(string.format("%.1f seconds", value))
        end)
        
        return slider
    end

    -- General Options Section
    local generalGroup = CreateGroupSection("General Options", 450, 120, yOffset)
    CreateCheckbox(generalGroup, "enabled", "Enable HideCharacterFrame", "Master toggle - Enable or disable the entire addon", 15, -35)
    CreateSlider(generalGroup, "fadeOutDuration", "Fade Out Duration", "How long frames take to fade out (0 = instant)", 0.0, 2.0, 0.1, 15, -75)

    yOffset = yOffset - 140

    -- Visibility Conditions Section
    local visibilityGroup = CreateGroupSection("Visibility Conditions", 450, 220, yOffset)

    -- Description text
    local desc = visibilityGroup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", visibilityGroup, "TOPLEFT", 15, -30)
    desc:SetText("Show character frame when ANY of the following conditions are met:")
    desc:SetTextColor(0.8, 0.8, 0.8, 1)

    -- Checkboxes in two columns
    CreateCheckbox(visibilityGroup, "hideCombat", "Show in combat", "Always show frame when fighting enemies", 15, -55)
    CreateCheckbox(visibilityGroup, "hideFullHealth", "Show when health not full", "Show frame when you're injured", 15, -80)
    CreateCheckbox(visibilityGroup, "hideFullPower", "Show when power not full (mana/energy/focus)", "Show frame when mana/energy/focus < max", 15, -105)
    CreateCheckbox(visibilityGroup, "hideRageZero", "Show when rage above zero (Warrior/Druid only)", "For warriors/druids: Show when you have rage", 15, -130)
    CreateCheckbox(visibilityGroup, "hideNoTarget", "Show when target selected", "Show frame when you have something targeted", 15, -155)
    CreateCheckbox(visibilityGroup, "hideNoDebuff", "Show when debuffed", "Show frame when you have negative effects", 15, -180)

    yOffset = yOffset - 240

    -- Pet Options Section (only for classes with pets)
    if playerClass == "HUNTER" or playerClass == "WARLOCK" then
        local petHeight = playerClass == "HUNTER" and 110 or 80
        local petGroup = CreateGroupSection("Pet Options", 450, petHeight, yOffset)

        CreateCheckbox(petGroup, "hidePetFullHealth", "Show when pet health not full", "Show frame when your pet is injured", 15, -35)

        if playerClass == "HUNTER" then
            CreateCheckbox(petGroup, "hidePetHappy", "Show when pet unhappy (Hunter only)", "Hunter only: Show when pet happiness is low", 15, -60)
        end

        yOffset = yOffset - (petHeight + 20)
    end

    -- Reset button
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("TOPLEFT", 20, yOffset - 10)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        for k, v in pairs(defaults) do
            db[k] = v
            if checkboxes[k] then
                checkboxes[k]:SetChecked(v)
            end
        end
        setFrameVisibility(shouldShowFrame())
        print("|cFF00FF00HideCharacterFrame:|r Settings reset to defaults")
    end)

    return panel
end

local optionsPanel

frameHandler:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "ADDON_LOADED" then
        local addonName = unit
        if addonName == "HideCharacterFrame" then
            -- Create and register options panel
            optionsPanel = CreateOptionsPanel()

            -- Register with Interface Options (Classic compatibility)
            if InterfaceOptions_AddCategory then
                InterfaceOptions_AddCategory(optionsPanel)
            elseif Settings and Settings.RegisterCanvasLayoutCategory then
                -- Modern WoW Settings API
                local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
                Settings.RegisterAddOnCategory(category)
            end

            frameHandler:UnregisterEvent("ADDON_LOADED")
        end
    elseif(event == "PLAYER_REGEN_DISABLED") then
        unregisterUpdateEvents();
        setFrameVisibility(true);
    elseif(event == "PLAYER_LOGIN") then
        registerUpdateEvents();
        setFrameVisibility(shouldShowFrame());
    else
        if(event == "PLAYER_REGEN_ENABLED") then
            registerUpdateEvents();
        end

        -- Only update if the UNIT_AURA event is for the player
        if event ~= "UNIT_AURA" or unit == "player" then
            setFrameVisibility(shouldShowFrame());
        end
    end
end);

frameHandler:RegisterEvent("ADDON_LOADED");
frameHandler:RegisterEvent("PLAYER_LOGIN");
frameHandler:RegisterEvent("PLAYER_REGEN_ENABLED");
frameHandler:RegisterEvent("PLAYER_REGEN_DISABLED");
registerUpdateEvents();
