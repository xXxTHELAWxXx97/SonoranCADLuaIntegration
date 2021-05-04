local UnitCache = {}
local CallCache = {}
local PlayerUnitMapping = {}

function GetUnitCache() return UnitCache end
function GetCallCache() return CallCache end
function SetUnitCache(k, v) 
    local key = findUnitById(k)
    if key ~= nil and UnitCache[key] ~= nil then
        UnitCache[key] = v
    else
        table.insert(UnitCache, v)
    end
end
function SetCallCache(k, v) CallCache[k] = v end
function GetUnitByPlayerId(player) return PlayerUnitMapping[player] end

local function findUnitById(identIds)
    for k, v in pairs(UnitCache) do
        if has_value(identIds, v.id) then
            return k
        end
    end
    return nil
end

local function GetSourceByApiId(apiIds)
    for x=1, #apiIds do
        for i=0, GetNumPlayerIndices()-1 do
            local player = GetPlayerFromIndex(i)
            if player then
                local identifiers = GetIdentifiers(player)
                for type, id in pairs(identifiers) do
                    if id == apiIds[x] then
                        return player
                    end
                end
            end
        end
    end
    return nil
end 

-- Global function wrapper
function GetUnitById(ids) return findUnitById(ids) end

AddEventHandler("playerDropped", function()
    local id = GetUnitByPlayerId(source)
    local unit = findUnitById(id)
    if unit then
        TriggerEvent("SonoranCAD::core:RemovePlayer", source, UnitCache[unit])
        UnitCache[unit] = nil
    end
end)


registerApiType("GET_ACTIVE_UNITS", "emergency")
Citizen.CreateThread(function()
    Wait(500)
    if not Config.apiSendEnabled then
        debugLog("Disabling active units routine")
        return
    end
    local OldUnits = {}
    local NewUnits = {}
    for k, v in pairs(UnitCache) do
        OldUnits[k] = v
    end
    while true do
        if GetNumPlayerIndices() > 0 then
            local payload = { serverId = Config.serverId}
            performApiRequest({payload}, "GET_ACTIVE_UNITS", function(runits)
                local allUnits = json.decode(runits)
                if allUnits ~= nil then
                    for k, v in pairs(allUnits) do
                        local playerId = GetSourceByApiId(v.data.apiIds)
                        if playerId then
                            PlayerUnitMapping[playerId] = v.id
                            table.insert(NewUnits, v)
                            TriggerEvent("SonoranCAD::core:AddPlayer", playerId, v)
                        end
                    end
                end
                for k, v in pairs(OldUnits) do
                    debugLog(("Removing player %s, not on units list"):format(k))
                    TriggerEvent("SonoranCAD::core:RemovePlayer", k, v)
                end
            end)
        end
        UnitCache = {}
        for k, v in pairs(NewUnits) do
            table.insert(UnitCache, v)
        end
        Citizen.Wait(60000)
    end
end)