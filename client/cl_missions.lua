-- cl_delivery.lua
-- Module "Delivery Manager" (client)
-- Dépendances : QBCore, PolyZone/BoxZone, qb-menu (déjà utilisées dans ton projet)
-- Utilise Config.BoxGroups, Config.Vehicle, Config.Warehouse, Config.ZonesPerMission (voir README ci-dessous)

local QBCore = exports['qb-core']:GetCoreObject()

-- Mission state
local Mission = {
    active = false,
    zones = {},         -- list of zone objects selected for this mission (from Config.BoxGroups)
    zoneIndex = 1,      -- current zone index inside Mission.zones
    spotIndex = 1,      -- current spot index inside current zone.locations (for multi)
    boxesRemaining = 0, -- boxes to pick at current spot
    carryingBox = false,
    carriedProp = nil,  -- entity of attached prop
    totalDelivered = 0, -- total boxes delivered this mission
    blip = nil,         -- active blip for current spot / return
    zonePoly = nil      -- active BoxZone for current spot
}

-- Config defaults (override via your config.lua)
if not Config.ZonesPerMission then Config.ZonesPerMission = 3 end
if not Config.Warehouse then
    Config.Warehouse = {
        location = vector4(Config.Vehicle.location.x, Config.Vehicle.location
            .y, Config.Vehicle.location.z, Config.Vehicle.location.w)
    }
end
if not Config.PricePerBox then Config.PricePerBox = 50 end -- default price

-- Helper: choose n random unique zones from Config.BoxGroups
local function GetRandomZones(count)
    local copy = {}
    for _, v in ipairs(Config.BoxGroups) do table.insert(copy, v) end
    local chosen = {}

    count = math.min(count, #copy)
    for i = 1, count do
        local idx = math.random(#copy)
        table.insert(chosen, copy[idx])
        table.remove(copy, idx)
    end
    return chosen
end

-- Helper: cleanup active blip and zone
local function ClearActiveMarkers()
    if Mission.blip and DoesBlipExist(Mission.blip) then
        RemoveBlip(Mission.blip)
    end
    Mission.blip = nil

    if Mission.zonePoly and Mission.zonePoly.destroy then
        -- BoxZone has no destroy in some versions; set to nil so GC can collect
        Mission.zonePoly:destroy()
    end
end

-- Helper: create blip for a coordinate (vector4 or vector3)
local function CreateBlip(coords, label)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, 1)
    SetBlipScale(b, 0.7)
    SetBlipColour(b, 5)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label or "Livraison")
    EndTextCommandSetBlipName(b)
    return b
end

-- Utility: check nearest mission vehicle (by model) within radius
local function GetNearestMissionVehicle(radius)
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local vehModelHash = GetHashKey(Config.Vehicle.name)
    local found = nil

    local vehicles = QBCore.Functions.GetVehicles() -- QBCore helper (may vary); fallback enumeration otherwise
    if vehicles and type(vehicles) == "table" then
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) and GetEntityModel(veh) == vehModelHash then
                local vcoords = GetEntityCoords(veh)
                if #(vcoords - pcoords) <= radius then
                    return veh
                end
            end
        end
    else
        -- fallback scan around player: enumerate vehicles in area (less efficient)
        local handle, veh = FindFirstVehicle()
        local success
        repeat
            if DoesEntityExist(veh) and GetEntityModel(veh) == vehModelHash then
                local vcoords = GetEntityCoords(veh)
                if #(vcoords - pcoords) <= radius then
                    found = veh
                    break
                end
            end
            success, veh = FindNextVehicle(handle)
        until not success
        EndFindVehicle(handle)
    end

    return found
end

-- Attach a box prop to player (visual)
local function AttachBoxToPlayer()
    if Mission.carryingBox then return end
    local ped = PlayerPedId()
    local propModel = `prop_cs_cardbox_01` -- box prop (change if you want)
    RequestModel(propModel)
    local t = GetGameTimer()
    while not HasModelLoaded(propModel) and (GetGameTimer() - t) < 2000 do Wait(10) end
    if not HasModelLoaded(propModel) then return end

    local x, y, z = table.unpack(GetEntityCoords(ped))
    local box = CreateObject(propModel, x, y, z + 0.2, true, true, true)
    SetEntityAsMissionEntity(box, true, true)
    AttachEntityToEntity(box, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1,
        true)

    Mission.carryingBox = true
    Mission.carriedProp = box
end

-- Remove/detach carried prop
local function RemoveCarriedBox()
    if Mission.carriedProp and DoesEntityExist(Mission.carriedProp) then
        DetachEntity(Mission.carriedProp, true, true)
        DeleteObject(Mission.carriedProp)
    end
    Mission.carriedProp = nil
    Mission.carryingBox = false
end

-- Player picks up a box at spot
local function OnTakeBox()
    if Mission.boxesRemaining <= 0 then return end
    if Mission.carryingBox then
        QBCore.Functions.Notify("Tu portes déjà une boîte.", "error")
        return
    end

    -- pick box
    AttachBoxToPlayer()
    Mission.boxesRemaining = Mission.boxesRemaining - 1
    QBCore.Functions.Notify("Tu as pris une boîte. Rapporte-la au camion.", "success")
end

-- Player loads a carried box into the mission vehicle
local function OnLoadBoxIntoVehicle()
    if not Mission.carryingBox then
        QBCore.Functions.Notify("Tu ne portes pas de boîte.", "error")
        return
    end

    local veh = GetNearestMissionVehicle(6.0)
    if not veh then
        QBCore.Functions.Notify("Pas de camion à proximité.", "error")
        return
    end

    -- load (visual: delete prop)
    RemoveCarriedBox()
    Mission.totalDelivered = Mission.totalDelivered + 1
    QBCore.Functions.Notify("Boîte chargée dans le camion.", "success")

    -- If boxes remain at this spot -> stay on same spot
    if Mission.boxesRemaining > 0 then
        -- update blip ONLY (do not destroy the active zonePoly)
        if Mission.blip and DoesBlipExist(Mission.blip) then
            RemoveBlip(Mission.blip)
        end

        local zone = Mission.zones[Mission.zoneIndex]
        local coords = (zone.type == "single") and zone.locations or zone.locations[Mission.spotIndex]

        Mission.blip = CreateBlip(coords, ("Point de collecte"))

        return
    end

    -- No more boxes in this spot -> next
    NextSpotOrZone()
end

-- Create blip for current spot (or return to warehouse)
function CreateBlipForCurrentSpot()
    ClearActiveMarkers()
    local zone = Mission.zones[Mission.zoneIndex]

    if not zone then return end

    local coords
    if zone.type == "single" then
        coords = zone.locations
    else
        coords = zone.locations[Mission.spotIndex]
    end
    if not coords then return end

    Mission.blip = CreateBlip(coords,
        string.format("Livraison: %s (Zone %d/%d)", zone.name or "Zone", Mission.zoneIndex, #Mission.zones))
end

-- Create interactive zone (BoxZone) for the current spot
function CreateZoneForCurrentSpot()
    -- Clear previous zone + blip
    ClearActiveMarkers()

    local zone = Mission.zones[Mission.zoneIndex]
    if not zone then return end

    local coords
    if zone.type == "single" then
        coords = zone.locations
    else
        coords = zone.locations[Mission.spotIndex]
    end
    if not coords then return end

    Mission.blip = CreateBlip(coords, ("Point de collecte"))

    -- BoxZone: width/length 3x3 (adjust if needed)
    -- Keep the created zone object to nil later
    Mission.zonePoly = BoxZone:Create(coords, 3.0, 3.0, {
        name = "aiko_delivery_spot",
        debugPoly = Config.Debug or false,
        heading = coords.w or 0.0
    })

    Mission.zonePoly:onPlayerInOut(function(isInside)
        if isInside and Mission.active then
            if Mission.carryingBox then
                exports['qb-core']:DrawText('[E] Charger la boîte dans le camion', 'left')
            else
                exports['qb-core']:DrawText('[E] Prendre une boîte', 'left')
            end

            -- listen keypress
            CreateThread(function()
                while Mission.active and Mission.zonePoly and Mission.zonePoly:isPointInside(GetEntityCoords(PlayerPedId())) do
                    if IsControlJustReleased(0, 38) then -- E
                        if Mission.carryingBox then
                            OnLoadBoxIntoVehicle()
                        else
                            OnTakeBox()
                        end
                    end
                    Wait(40)
                end
                exports['qb-core']:HideText()
            end)
        else
            -- left zone
            exports['qb-core']:HideText()
        end
    end)
end

-- Advance to next spot in the zone or to next zone
function NextSpotOrZone()
    local zone = Mission.zones[Mission.zoneIndex]
    if not zone then
        -- no zone -> go warehouse
        GoToWarehouse()
        return
    end

    if zone.type == "multi" then
        -- try move to next spot
        Mission.spotIndex = Mission.spotIndex + 1
        if zone.locations[Mission.spotIndex] then
            -- set boxesRemaining for next spot (zone.amount applies per spot)
            Mission.boxesRemaining = zone.amount or 1
            QBCore.Functions.Notify("Zone: Prochain spot - continuez.", "primary")
            CreateZoneForCurrentSpot()
            return
        end
    end

    -- else: finished this zone => go to next zone
    Mission.zoneIndex = Mission.zoneIndex + 1
    if Mission.zones[Mission.zoneIndex] then
        Mission.spotIndex = 1
        local nextZone = Mission.zones[Mission.zoneIndex]
        Mission.boxesRemaining = nextZone.amount or 1
        QBCore.Functions.Notify("Direction vers la zone suivante : " .. (nextZone.name or "Zone"), "primary")
        CreateZoneForCurrentSpot()
    else
        -- no more zones -> return
        GoToWarehouse()
    end
end

-- When mission is finished, create return blip to warehouse and wait for unload
function GoToWarehouse()
    ClearActiveMarkers()
    Mission.blip = CreateBlip(Config.Warehouse.location, "Retour au dépôt")
    QBCore.Functions.Notify("Mission terminée: rentrez au dépôt et déchargez le camion.", "success")

    -- create a zone at warehouse for unload
    local wcoords = Config.Warehouse.location
    local unloadZone = BoxZone:Create(wcoords, 4.0, 4.0, {
        name = "aiko_delivery_unload",
        debugPoly = Config.Debug or false,
        heading = wcoords.w or 0.0
    })

    unloadZone:onPlayerInOut(function(isInside)
        if isInside then
            exports['qb-core']:DrawText('[E] Décharger le camion', 'left')
            CreateThread(function()
                while unloadZone and unloadZone:isPointInside(GetEntityCoords(PlayerPedId())) do
                    if IsControlJustReleased(0, 38) then
                        -- unload (pay)
                        RemoveCarriedBox()
                        local paid = Mission.totalDelivered * Config.PricePerBox
                        -- fire server event to give money and xp later
                        TriggerServerEvent("aiko_delivery:server:pay", Mission.totalDelivered, paid)
                        QBCore.Functions.Notify("Vous avez reçu $" .. paid .. " pour " ..
                            Mission.totalDelivered .. " colis.", "success")
                        -- cleanup mission
                        Mission.active = false
                        Mission.zones = {}
                        Mission.zoneIndex = 1
                        Mission.spotIndex = 1
                        Mission.boxesRemaining = 0
                        Mission.totalDelivered = 0
                        ClearActiveMarkers()
                        break
                    end
                    Wait(40)
                end
                exports['qb-core']:HideText()
            end)
        else
            exports['qb-core']:HideText()
        end
    end)
end

-- PUBLIC: Start a mission (can be triggered from your menu command)
function StartMission()
    if Mission.active then
        QBCore.Functions.Notify("Mission déjà en cours.", "error")
        return
    end

    -- Select ZonesPerMission unique zones
    local n = Config.ZonesPerMission or 3
    Mission.zones = GetRandomZones(n)
    if #Mission.zones == 0 then
        QBCore.Functions.Notify("Aucune zone configurée.", "error")
        return
    end

    Mission.active = true
    Mission.zoneIndex = 1
    Mission.spotIndex = 1
    Mission.totalDelivered = 0
    local z = Mission.zones[1]
    Mission.boxesRemaining = z.amount or 1

    QBCore.Functions.Notify("Mission démarrée. Dirigez-vous vers la première zone.", "success")
    CreateZoneForCurrentSpot()
end

-- PUBLIC: Cancel mission (clean)
function CancelMission()
    Mission.active = false
    Mission.zones = {}
    Mission.zoneIndex = 1
    Mission.spotIndex = 1
    Mission.boxesRemaining = 0
    Mission.totalDelivered = 0
    RemoveCarriedBox()
    ClearActiveMarkers()
    QBCore.Functions.Notify("Mission annulée.", "primary")
end

-- Expose events to start/stop missions from your menu (already used in cl_main)
RegisterNetEvent('aiko_delivery:client:startMission', function()
    StartMission()
end)
RegisterNetEvent('aiko_delivery:client:stopMission', function()
    CancelMission()
end)

-- Debug commands (dev only)
RegisterCommand("aiko_debug_start", function()
    StartMission()
end, false)

RegisterCommand("aiko_debug_cancel", function()
    CancelMission()
end, false)
