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
    hidePvP = false,
    fadeOutEnabled = true,
    fadeOutDuration = 0.1
}

-- Saved variables will be initialized in ADDON_LOADED event
local db

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

local function shouldShowForPvP()
    return db.hidePvP and UnitIsPVP("player")
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
    return shouldShowForCombat() or shouldShowForDebuffs() or shouldShowForTarget() or shouldShowForHealth() or shouldShowForPower() or shouldShowForPvP()
end

-- Main function that delegates to class-specific handlers
local function shouldShowFrame()
    -- If addon is disabled, always show frame
    if not db.enabled then
        return true
    end

    -- Check basic conditions for all classes
    local showForBasic = shouldShowForBasicConditions()
    
    -- Add pet-specific conditions for classes with pets
    if playerClass == "HUNTER" then
        return showForBasic or shouldShowForPet(true)
    elseif playerClass == "WARLOCK" then
        return showForBasic or shouldShowForPet(false)
    else
        return showForBasic
    end
end

-- Helper functions for event management
local function registerUpdateEvents()
    frameHandler:RegisterEvent("UNIT_HEALTH_FREQUENT", "player")
    frameHandler:RegisterEvent("UNIT_POWER_FREQUENT", "player")
    frameHandler:RegisterEvent("PLAYER_TARGET_CHANGED")
    frameHandler:RegisterEvent("UNIT_AURA", "player")
    frameHandler:RegisterEvent("PLAYER_FLAGS_CHANGED")
end

local function unregisterUpdateEvents()
    frameHandler:UnregisterEvent("UNIT_HEALTH_FREQUENT", "player")
    frameHandler:UnregisterEvent("UNIT_POWER_FREQUENT", "player")
    frameHandler:UnregisterEvent("PLAYER_TARGET_CHANGED")
    frameHandler:UnregisterEvent("UNIT_AURA", "player")
    frameHandler:UnregisterEvent("PLAYER_FLAGS_CHANGED")
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
        if db.fadeOutEnabled then
            -- Fade out frames using configurable duration
            UIFrameFadeOut(PlayerFrame, db.fadeOutDuration, PlayerFrame:GetAlpha(), 0)
            if (playerClass == "HUNTER" or playerClass == "WARLOCK") and PetFrame then
                UIFrameFadeOut(PetFrame, db.fadeOutDuration, PetFrame:GetAlpha(), 0)
            end
        else
            -- Hide frames immediately
            PlayerFrame:SetAlpha(0)
            if (playerClass == "HUNTER" or playerClass == "WARLOCK") and PetFrame then
                PetFrame:SetAlpha(0)
            end
        end
    end
end

-- Options Panel Creation (defined before event handler)
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "HideCharacterFrameOptionsPanel", UIParent)
    panel.name = "HideCharacterFrame"

    -- Title (fixed at top)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("HideCharacterFrame Options")

    -- Version info (fixed at top)
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Configure when to hide the character frame")

    -- Create scroll frame using UIPanelScrollFrameTemplate (like DBM-GUI)
    local scrollFrame = CreateFrame("ScrollFrame", "HideCharacterFrameScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 16)

    -- Create scrollable content frame
    local content = CreateFrame("Frame", "HideCharacterFrameContent", scrollFrame)
    content:SetSize(450, 1) -- Fixed width, height will be set dynamically
    scrollFrame:SetScrollChild(content)

    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = _G[self:GetName() .. "ScrollBar"]
        local step = 20
        if delta == 1 then -- scroll up
            scrollBar:SetValue(scrollBar:GetValue() - step)
        elseif delta == -1 then -- scroll down
            scrollBar:SetValue(scrollBar:GetValue() + step)
        end
    end)

    local yOffset = -20
    local checkboxes = {}
    local sliders = {}
    
    -- Store references for later use
    panel.scrollFrame = scrollFrame
    panel.content = content

    -- Helper function to create a bordered group section
    local function CreateGroupSection(name, width, height, yPos)
        local group = CreateFrame("Frame", nil, content, "BackdropTemplate")
        group:SetPoint("TOPLEFT", content, "TOPLEFT", 5, yPos)
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

    local function CreateCheckbox(parent, key, label, xOffset, yPos)
        local cb = CreateFrame("CheckButton", "HideCharacterFrame_" .. key, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yPos)
        cb.Text:SetText(label)
        cb:SetChecked(db[key])

        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked()
            -- Update frame visibility immediately
            setFrameVisibility(shouldShowFrame())
        end)

        checkboxes[key] = cb
        return cb
    end

    local function CreateSlider(parent, key, label, min, max, step, xOffset, yPos)
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
        
        slider:SetScript("OnValueChanged", function(self, value)
            db[key] = value
            valueText:SetText(string.format("%.1f seconds", value))
        end)
        
        sliders[key] = slider
        return slider
    end

    -- General Options Section
    local generalGroup = CreateGroupSection("General Options", 450, 150, yOffset)
    CreateCheckbox(generalGroup, "enabled", "Enable HideCharacterFrame", 15, -35)
    CreateCheckbox(generalGroup, "fadeOutEnabled", "Enable Fade Out (not when deselecting target)", 15, -60)
    CreateSlider(generalGroup, "fadeOutDuration", "Fade Out Duration", 0.0, 2.0, 0.1, 15, -105)

    yOffset = yOffset - 170

    -- Visibility Conditions Section
    local visibilityGroup = CreateGroupSection("Visibility Conditions", 450, 245, yOffset)

    -- Description text
    local desc = visibilityGroup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", visibilityGroup, "TOPLEFT", 15, -30)
    desc:SetText("Show character frame when ANY of the following conditions are met:")
    desc:SetTextColor(0.8, 0.8, 0.8, 1)

    -- Checkboxes in two columns
    CreateCheckbox(visibilityGroup, "hideCombat", "Show in combat", 15, -55)
    CreateCheckbox(visibilityGroup, "hideFullHealth", "Show when health not full", 15, -80)
    CreateCheckbox(visibilityGroup, "hideFullPower", "Show when power not full (mana/energy/focus)", 15, -105)
    CreateCheckbox(visibilityGroup, "hideRageZero", "Show when rage above zero (Warrior/Druid only)", 15, -130)
    CreateCheckbox(visibilityGroup, "hideNoTarget", "Show when target selected", 15, -155)
    CreateCheckbox(visibilityGroup, "hideNoDebuff", "Show when debuffed", 15, -180)
    CreateCheckbox(visibilityGroup, "hidePvP", "Show when PvP enabled (useful for Hardcore)", 15, -205)

    yOffset = yOffset - 265

    -- Pet Options Section (only for classes with pets)
    if playerClass == "HUNTER" or playerClass == "WARLOCK" then
        local petHeight = playerClass == "HUNTER" and 110 or 80
        local petGroup = CreateGroupSection("Pet Options", 450, petHeight, yOffset)

        CreateCheckbox(petGroup, "hidePetFullHealth", "Show when pet health not full", 15, -35)

        if playerClass == "HUNTER" then
            CreateCheckbox(petGroup, "hidePetHappy", "Show when pet unhappy (Hunter only)", 15, -60)
        end

        yOffset = yOffset - (petHeight + 20)
    end

    -- Reset button (inside scrollable content)
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 15, yOffset - 10)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        for k, v in pairs(defaults) do
            db[k] = v
            if checkboxes[k] then
                checkboxes[k]:SetChecked(v)
            end
            if sliders[k] then
                sliders[k]:SetValue(v)
            end
        end
        setFrameVisibility(shouldShowFrame())
        print("|cFF00FF00HideCharacterFrame:|r Settings reset to defaults")
    end)

    -- Calculate total content height and set up scroll range
    local totalHeight = math.abs(yOffset) + 50 -- Add some padding
    content:SetHeight(totalHeight)
    
    -- Set up scroll range (like DBM-GUI pattern)
    local function updateScrollRange()
        local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
        local maxScroll = totalHeight - scrollFrame:GetHeight()
        
        if maxScroll > 0 then
            scrollBar:SetMinMaxValues(0, maxScroll)
            scrollBar:Show()
        else
            scrollBar:SetMinMaxValues(0, 0)
            scrollBar:Hide()
        end
        scrollBar:SetValue(0)
    end
    
    -- Update scroll range when frame is shown
    panel:SetScript("OnShow", updateScrollRange)
    updateScrollRange()

    return panel
end

local optionsPanel

frameHandler:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "ADDON_LOADED" then
        local addonName = unit
        if addonName == "HideCharacterFrame" then
            -- Initialize saved variables
            HideCharacterFrameDB = HideCharacterFrameDB or {}
            
            -- Ensure all settings exist
            for k, v in pairs(defaults) do
                if HideCharacterFrameDB[k] == nil then
                    HideCharacterFrameDB[k] = v
                end
            end
            
            -- Set up db reference
            db = HideCharacterFrameDB
            
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
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Handle target changes with special fade logic
        local visible = shouldShowFrame()
        if not visible and db.hideNoTarget and not UnitExists("target") then
            -- Check if hiding only because target was deselected (all other conditions false)
            local otherConditions = shouldShowForCombat() or shouldShowForDebuffs() or shouldShowForHealth() or shouldShowForPower() or shouldShowForPvP()
            
            -- Check pet conditions for classes with pets
            if playerClass == "HUNTER" then
                otherConditions = otherConditions or shouldShowForPet(true)
            elseif playerClass == "WARLOCK" then
                otherConditions = otherConditions or shouldShowForPet(false)
            end
            
            if not otherConditions then
                -- Only target deselected - hide immediately without fade
                PlayerFrame:SetAlpha(0)
                if (playerClass == "HUNTER" or playerClass == "WARLOCK") and PetFrame then
                    PetFrame:SetAlpha(0)
                end
                return
            end
        end
        setFrameVisibility(visible)
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
