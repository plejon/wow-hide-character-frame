local frameHandler = CreateFrame("FRAME");
local function shouldShowFrame()
    -- Never hide if player has a debuff
    local name = UnitDebuff("player", 1)
    if name then
        return true
    end

    -- Get power type information
    local _, powerToken = UnitPowerType("player")
    
    -- Special handling for rage
    if powerToken == "RAGE" then
        local currentRage = UnitPower("player")
        -- Don't show frame if rage is 0, unless other conditions are met
        if currentRage == 0 then
            return UnitHealth("player") < UnitHealthMax("player")
                or UnitExists("target")
                or UnitAffectingCombat("player")
        end
        -- Show frame if rage is above 0
        return true
    end
    
    -- Normal handling for other power types
    return UnitHealth("player") < UnitHealthMax("player") 
        or UnitPower("player") < UnitPowerMax("player")
        or UnitExists("target")
        or UnitAffectingCombat("player")
end

frameHandler:SetScript("OnEvent", function(self, event, unit)
    if(event == "PLAYER_REGEN_DISABLED") then
        frameHandler:UnregisterEvent("UNIT_HEALTH_FREQUENT", "player");
        frameHandler:UnregisterEvent("UNIT_POWER_FREQUENT", "player");
        frameHandler:UnregisterEvent("PLAYER_TARGET_CHANGED");
        frameHandler:UnregisterEvent("UNIT_AURA", "player");
        PlayerFrame:SetAlpha(1);
    elseif(event == "PLAYER_LOGIN") then
        frameHandler:RegisterEvent("UNIT_HEALTH_FREQUENT", "player");
        frameHandler:RegisterEvent("UNIT_POWER_FREQUENT", "player");
        frameHandler:RegisterEvent("PLAYER_TARGET_CHANGED");
        frameHandler:RegisterEvent("UNIT_AURA", "player");
        PlayerFrame:SetAlpha(shouldShowFrame() and 1 or 0);
    else
        if(event == "PLAYER_REGEN_ENABLED") then
            frameHandler:RegisterEvent("UNIT_HEALTH_FREQUENT", "player");
            frameHandler:RegisterEvent("UNIT_POWER_FREQUENT", "player");
            frameHandler:RegisterEvent("PLAYER_TARGET_CHANGED");
            frameHandler:RegisterEvent("UNIT_AURA", "player");
        end
        
        -- Only update if the UNIT_AURA event is for the player
        if event ~= "UNIT_AURA" or unit == "player" then
            PlayerFrame:SetAlpha(shouldShowFrame() and 1 or 0);
        end
    end
end);

frameHandler:RegisterEvent("PLAYER_LOGIN");
frameHandler:RegisterEvent("UNIT_HEALTH_FREQUENT", "player");
frameHandler:RegisterEvent("UNIT_POWER_FREQUENT", "player");
frameHandler:RegisterEvent("PLAYER_TARGET_CHANGED");
frameHandler:RegisterEvent("PLAYER_REGEN_ENABLED");
frameHandler:RegisterEvent("PLAYER_REGEN_DISABLED");
frameHandler:RegisterEvent("UNIT_AURA", "player");