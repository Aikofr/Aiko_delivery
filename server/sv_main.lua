print('Hello server')

RegisterServerEvent('Delivery:SpawnPed')
AddEventHandler('Delivery:SpawnPed', function()
    print('heyhey')
end)
