local QBCore = exports['qb-core']:GetCoreObject()

local function MainBlip()
    bossBlip = AddBlipForCoord(Config.BossNPC.coords.x, Config.BossNPC.coords.y, Config.BossNPC.coords.z)
    SetBlipSprite(bossBlip, Config.Blips.boss.sprite)
    SetBlipDisplay(bossBlip, 4)
    SetBlipScale(bossBlip, Config.Blips.boss.scale)
    SetBlipColour(bossBlip, Config.Blips.boss.color)
    SetBlipAsShortRange(bossBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Blips.boss.label)
    EndTextCommandSetBlipName(bossBlip)
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
end

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local bossCoords = vector3(Config.BossNPC.coords.x, Config.BossNPC.coords.y, Config.BossNPC.coords.z)
        local distance = #(playerCoords - bossCoords)

        if distance <= 20 then
            sleep = 0
            DrawMarker(2, bossCoords.x, bossCoords.y, bossCoords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15,
                255, 255, 255, 200, false, false, false, true, false, false, false)

            if distance <= 5 then
                QBCore.Functions.DrawText3D(bossCoords.x, bossCoords.y, bossCoords.z + 1.0, "[E] Commencer le travail")
                if IsControlJustReleased(0, 38) then -- E
                    print('test01')
                end
            end
        end
        Wait(sleep)
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
