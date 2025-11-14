local QBCore         = exports['qb-core']:GetCoreObject()
local listenZone     = false
local isWorking      = false
local boxesCollected = 0
local vehSpawn       = nil

local function MainBlip()
    local bossBlip = AddBlipForCoord(Config.BossNPC.coords.x, Config.BossNPC.coords.y, Config.BossNPC.coords.z)
    SetBlipSprite(bossBlip, Config.Blips.boss.sprite)
    SetBlipDisplay(bossBlip, 4)
    SetBlipScale(bossBlip, Config.Blips.boss.scale)
    SetBlipColour(bossBlip, Config.Blips.boss.color)
    SetBlipAsShortRange(bossBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Blips.boss.label)
    EndTextCommandSetBlipName(bossBlip)
end

local function listerInteract()
    listenZone = true
    CreateThread(function()
        while listenZone do
            if IsControlJustReleased(0, 38) then
                TriggerEvent('aiko_delivery:client:mainMenu')
                listenZone = false
            end
            Wait(50)
        end
    end)
end

local function Interaction()
    local method = Config.Target

    if method == false then
        local bossZones = BoxZone:Create(Config.BossNPC.coords, 3.0, 3.0, {
            name = "boss_npc",
            debugPoly = Config.Debug
        })
        bossZones:onPlayerInOut(function(inside)
            if inside then
                exports['qb-core']:DrawText('[E] Parler avec le patron', 'right')
                listerInteract()
            else
                exports['qb-core']:HideText()
                listenZone = false
            end
        end)
    end
end

local function SpawnBossPed()
    local model = Config.BossNPC.model

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(100)
    end

    local ped = CreatePed(0, model, Config.BossNPC.coords.x, Config.BossNPC.coords.y, Config.BossNPC.coords.z - 1.0,
        Config.BossNPC.coords.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityAsMissionEntity(ped, true, true)

    if Config.BossNPC.scenario then
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)
    end

    SetModelAsNoLongerNeeded(model)
    Interaction()
end

local function spawnVehicle()
    local vehModel = GetHashKey(Config.Vehicle.name)
    RequestModel(vehModel)
    while not HasModelLoaded(vehModel) do
        Wait(10)
    end

    local vehicle = CreateVehicle(vehModel, Config.Vehicle.location, true, false)
    print(QBCore.Functions.GetPlate(vehicle))
    exports['LegacyFuel']:SetFuel(vehicle, 100.0)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleDoorsLocked(vehicle, 1)
    TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(vehicle))

    vehSpawn = vehicle

    SetModelAsNoLongerNeeded(vehModel)
end

local function CreateDeliveryPoints()
    print('coucou')
    print(json.encode(Config.BoxGroups))
end

RegisterNetEvent('aiko_delivery:client:mainMenu', function()
    exports["qb-menu"]:openMenu({
        {
            header = "< Go Back",
        },
        {
            header = "Démarrer la mission",
            params = {
                event = "aiko_delivery:client:startJob",

            }
        },
        {
            header = "Terminer la mission",
            params = {
                event = "aiko_delivery:client:endJob",

            }
        },
    })
end)

RegisterNetEvent('aiko_delivery:client:startJob', function()
    if isWorking then
        QBCore.Functions.Notify("Tu travailles déjà !", "error")
        return
    end
    isWorking = true
    if vehSpawn then
        QBCore.Functions.Notify("Un véhicule est deja dehors !", "error")
    else
        spawnVehicle()
    end

    QBCore.Functions.Notify("🚚 Mission démarrée!", "success")
    CreateDeliveryPoints()
end)

RegisterNetEvent('aiko_delivery:client:endJob', function()
    TriggerEvent('QBCore:Notify', 'end job')
    isWorking = false
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        MainBlip()
        SpawnBossPed()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    MainBlip()
    SpawnBossPed()
end)
