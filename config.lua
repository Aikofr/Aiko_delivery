Config = {}

Config.Debug = true
-- Config.Framework = 'qbcore' -- 'standalone', 'qbcore', 'esx', 'ox'
Config.Target = false -- 'qb-target', false

Config.Vehicle = {
    name = 'boxville4',
    location = vector4(-151.04, -1355.74, 29.76, 0.04)
}

Config.BossNPC = {
    model = "a_m_m_farmer_01",
    coords = vector4(-155.76, -1349.81, 29.9, 272.38),
    scenario = "WORLD_HUMAN_CLIPBOARD"
}

Config.Blips = {
    boss = {
        sprite = 478,
        color = 5,
        scale = 0.8,
        label = "Livraison - Emploi"
    }
}

Config.ZonesPerMission = 3
Config.BoxGroups = {
    {
        name = "Stadium",
        type = 'single',
        amount = math.random(3, 6),
        locations = vector4(-398.29, -1879.06, 20.53, 322.39),
    },
    {
        name = "Beach",
        type = 'multi',
        amount = math.random(1, 2),
        locations = {
            vector4(-1514.83, -922.26, 10.17, 145.53),
            vector4(-1274.33, -1414.22, 4.32, 134.27)
        }
    }
}
