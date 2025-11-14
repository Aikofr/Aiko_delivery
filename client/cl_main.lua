local QBCore     = exports['qb-core']:GetCoreObject()

local bossZone   = nil
local listenZone = false
local isWorking  = false
local vehSpawn   = nil
local bossPed    = nil


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

local function Interaction()
    if bossZone then return end

    bossZone = BoxZone:Create(Config.BossNPC.coords, 3.0, 3.0, {
        name = "boss_npc",
        debugPoly = Config.Debug
    })

    if bossZone == nil then return end

    bossZone:onPlayerInOut(function(inside)
        listenZone = inside

        if inside then
            exports['qb-core']:DrawText('[E] Parler avec le patron', 'right')
            CreateThread(function()
                while listenZone do
                    if IsControlJustReleased(0, 38) then
                        exports['qb-core']:HideText()
                        TriggerEvent('aiko_delivery:client:mainMenu')
                    end
                    Wait(10)
                end
            end)
        else
            exports['qb-core']:HideText()
        end
    end)
end

local function SpawnBossPed()
    if bossPed and DoesEntityExist(bossPed) then return end
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
        TaskStartScenarioInPlace(ped, Config.BossNPC.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
    bossPed = ped
    Interaction()
end

local function spawnVehicle()
    local vehModel = GetHashKey(Config.Vehicle.name)
    RequestModel(vehModel)
    while not HasModelLoaded(vehModel) do
        Wait(10)
    end

    local loc = Config.Vehicle.location
    local vehicle = CreateVehicle(vehModel, loc.x, loc.y, loc.z, loc.w, true, false)
    print(QBCore.Functions.GetPlate(vehicle))
    exports['LegacyFuel']:SetFuel(vehicle, 100.0)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleOnGroundProperly(vehicle)
    TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(vehicle))

    vehSpawn = vehicle

    SetModelAsNoLongerNeeded(vehModel)
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
    TriggerEvent('aiko_delivery:client:startMission')
end)

RegisterNetEvent('aiko_delivery:client:endJob',
    function() --A changer ici, j'ai l'impression qu'on a beaucoup de répétition avec 'aiko_delivery:client:stopMission' qui font la meme chose
        TriggerEvent('QBCore:Notify', 'end job')
        isWorking = false
        print(vehSpawn)
        DeleteVehicle(vehSpawn)
        vehSpawn = nil
        TriggerEvent('aiko_delivery:client:stopMission')
    end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        TriggerEvent('aiko_delivery:client:stopMission')
    end
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
