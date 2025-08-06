local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
func = Tunnel.getInterface("nation_skinshop")
fclient = {}
Tunnel.bindInterface("nation_skinshop", fclient)

---------------------------------------------------------------------------
------------------------------ANIMAÇÃO DE PARADO---------------------------
---------------------------------------------------------------------------
function LoadAnim(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(10)
    end
end

function freezeAnim(dict, anim, flag, keep)
    if not keep then
        ClearPedTasks(PlayerPedId())
    end
    LoadAnim(dict)
    TaskPlayAnim(PlayerPedId(), dict, anim, 2.0, 2.0, -1, flag or 1, 0, false, false, false)
    RemoveAnimDict(dict)
end

handsUp = false
handsup = function()
    handsUp = not handsUp
    if handsUp then
        freezeAnim("random@mugging3", "handsup_standing_base", 49)
    else
        freezeAnim("move_f@multiplayer", "idle")
    end
end

---------------------------------------------------------------------------
----------------------------CÂMERAS----------------------------------------
---------------------------------------------------------------------------
local cameras = {
    ["body"] = { coords = vec3(0.4, 2.1, 0.9), point = vec3(0.5, -0.1, -0.1) }, 
    ["head"] = { coords = vec3(0.0, 0.7, 0.8), point = vec3(0.2, 0.0, 0.6) },
    ["chest"] = { coords = vec3(0.0, 1.4, 0.7), point = vec3(0.4, 0.0, 0.2) },
    ["legs"] = { coords = vec3(0.0, 1.3, 0.2), point = vec3(0.4, 0.0, -0.5) },
    ["feet"] = { coords = vec3(0.0, 0.8, -0.5), point = vec3(0.25, 0.0, -1.0) }
}

componentCams = {
    ["masks"] = "head",
    ["torsos"] = "chest",
    ["legs"] = "legs",
    ["bags"] = "chest",
    ["shoes"] = "feet",
    ["accessories"] = "body",
    ["undershirts"] = "chest",
    ["bodyArmors"] = "chest",
    ["decals"] = "body",
    ["tops"] = "chest",
    ["hats"] = "head",
    ["glasses"] = "head",
    ["ears"] = "head",
    ["watches"] = "legs",
    ["bracelets"] = "legs",
}

local activeCam

function interpCamera(cameraName)
    if cameras[cameraName] then
        if cameraName == activeCam then return end
        activeCam = cameraName
        local ped = PlayerPedId()
        local cam = cameras[cameraName]
        local coord = GetOffsetFromEntityInWorldCoords(ped,cam.coords)
        local tempCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coord, 0,0,0, 50.0)
        local pointCoords = GetOffsetFromEntityInWorldCoords(ped,cam.point)
        SetCamActive(tempCam, true)
        SetCamActiveWithInterp(tempCam, fixedCam, 600, true, true)
        PointCamAtCoord(tempCam, pointCoords)
        CreateThread(function()
            Wait(600)
            DestroyCam(fixedCam)
            fixedCam = tempCam
        end)
    end
end

function createCamera()
    local ped = PlayerPedId()
    local groundCam = CreateCam("DEFAULT_SCRIPTED_CAMERA")
    if store and store.coords then
        SetEntityCoords(ped, store.coords.x, store.coords.y, store.coords.z-0.97)
        if store.h then
            SetEntityHeading(ped, store.h)
        end
    end
    AttachCamToEntity(groundCam, ped, 0.5, -1.6, 0.0)
    SetCamRot(groundCam, 0, 0.0, 0.0)
    SetCamActive(groundCam, true)
    RenderScriptCams(true, false, 1, true, true)
    activeCam = "body"
    local cam = cameras[activeCam]
    local coord = GetOffsetFromEntityInWorldCoords(ped,cam.coords)
    fixedCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coord, 0,0,0, 50.0)
    local pointCoords = GetOffsetFromEntityInWorldCoords(ped,cam.point)
    PointCamAtCoord(fixedCam, pointCoords)
    SetCamActive(fixedCam, true)
    SetCamActiveWithInterp(fixedCam, groundCam, 1000, true, true)
    CreateThread(function()
        Wait(1000)
        DestroyCam(groundCam)
    end)
end

---------------------------------------------------------------------------
-----------------------DEIXAR OUTROS PLAYERS INVISÍVEIS--------------------
---------------------------------------------------------------------------
function setPlayersVisible(bool)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, not bool)
    SetEntityInvincible(ped, false)--mqcu
    if bool then
        for _, player in ipairs(GetActivePlayers()) do
            local otherPlayer = GetPlayerPed(player)
            if ped ~= otherPlayer then
                SetEntityVisible(otherPlayer, bool)
            end
        end
    else
        CreateThread(function()
            while inMenu do
                for _, player in ipairs(GetActivePlayers()) do
                    local otherPlayer = GetPlayerPed(player)
                    if ped ~= otherPlayer then
                        SetEntityVisible(otherPlayer, bool)
                    end
                end
                InvalidateIdleCam()
                Wait(1)
            end
        end)
    end
end

---------------------------------------------------------------------------
-----------------------LOJAS DE ROUPAS--------------------------
---------------------------------------------------------------------------
defaultPrices = {
    ["masks"] = 50,
    ["torsos"] = 20,
    ["legs"] = 200,
    ["bags"] = 150,
    ["shoes"] = 200,
    ["accessories"] = 90,
    ["undershirts"] = 100,
    ["bodyArmors"] = 300,
    ["decals"] = 50,
    ["tops"] = 300,
    ["hats"] = 120,
    ["glasses"] = 180,
    ["ears"] = 40,
    ["watches"] = 40,
    ["bracelets"] = 35,
}

customClothes = {
    ["test"] = {
        ['tops'] = {
            male = {
                defaultPrice = 500,
                type = "insert",
                [0] = true,
                [1] = true,
                [2] = 1000,
                [3] = true,
            }
        },

        ['glasses'] = {
            male = {
                defaultPrice = 500,
                type = "insert",
                [1] = { price = 250,
                    textures = {
                        [0] = { blocked = true }
                    }
                },
            }
        },

        ['legs'] = {
            male = {
                type = "remove",
                [0] = 5000,
                [1] = true,
                [2] = true,
                [3] = true,
            }
        },
    },
}

function format(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

function isCloth(index, value)
    return type(index) == "number" and type(value) == "table" -- verificar se está acessando o indice de uma roupa
end

isComponentBlocked = function(id, component)
    -- if component == "bags" then return true end
    return customClothes[id] and customClothes[id][component] and customClothes[id][component].blocked
end

isClothBlocked = function(id, component, index, gender)
    if customClothes[id] and customClothes[id][component] and customClothes[id][component][gender] then
        local c = customClothes[id][component][gender]
        return (c.type == "insert" and (not c[index] or (type(c[index]) == "table" and c[index].blocked))) or (c.type == "remove" and c[index] and (type(c[index]) == "boolean" or (type(c[index]) == "table" and c[index].blocked)))
    end
    return false
end

getBlockedComponentTextures = function(cloth, id, component, index, gender)
    for i = 0, cloth.textures do
        if not cloth[i] then
            cloth[i] = { blocked = false }
        else
            cloth[i].blocked = false
        end
        if customClothes[id] and customClothes[id][component] and customClothes[id][component][gender] and customClothes[id][component][gender][index] then
            local c = customClothes[id][component][gender][index]
            if type(c) == "table" and c.textures and c.textures[i] then
                cloth[i].blocked =  c.textures[i].blocked
            end
        end
    end
    return cloth
end

getClothPrice = function(id, component, index, gender)
    if id == "nation_creator" then return 0 end
    if customClothes[id] and customClothes[id][component] and customClothes[id][component][gender] then
        local c = customClothes[id][component][gender]
        if c[index] then
            local price = c[index]
            if type(price) == "table" then
                price = price.price or c.defaultPrice or defaultPrices[component]
            elseif type(price) == "boolean" then
                price = c.defaultPrice
            end
            return price
        else 
            return c.defaultPrice or defaultPrices[component]
        end
    end
    return defaultPrices[component]
end

getClothes = function(id)
    local clothes = getAllClothes()
    local gender = getGender()
    for component, v in pairs(clothes) do
        v.blocked = isComponentBlocked(id, component)
        for index, j in pairs(v) do
            if isCloth(index, j) then 
                j.price = getClothPrice(id, component, index, gender)
                j.blocked = isClothBlocked(id, component, index, gender)
                j = getBlockedComponentTextures(j, id, component, index, gender)
            end
        end
    end
    return clothes
end

getCartTotal = function(cart, initialClothes, storeId)
    local total = 0
    local gender = getGender()
    for component, index in pairs(cart) do
        if initialClothes[component] then
            local i = initialClothes[component][1]
            if index >= 0 and index ~= i then
                total = total + getClothPrice(storeId, component, index, gender)
            end
        end
    end
    return math.floor(total)
end

getPopupText = function(total) -- TEXTO QUE VAI APARECER NO POPUP NA HORA DE COMPRAR
    return "você deseja pagar o valor de R$ <b>"..format(total or 0).."</b> ?"
end

skinshops = {
    [1] = {
        clothes = getClothes, permission = nil, coords = vec3(80.46,-1400.11,29.38),
    },

    [2] = {
        clothes = getClothes, permission = nil, coords = vec3(77.71,-1399.61,29.38),
    },

    [3] = {
        clothes = getClothes, permission = nil, coords = vec3(75.05,-1400.15,29.38),
    },

    [4] = {
        clothes = getClothes, permission = nil, coords = vec3(72.93, -1390.08, 29.37),
    },

    [5] = {
        clothes = getClothes, permission = nil, coords = vec3(-711.99, -149.01, 37.42),
    },

    [6] = {
        clothes = getClothes, permission = nil, coords = vec3(-708.56, -154.73, 37.42),
    },

    [7] = {
        clothes = getClothes, permission = nil, coords = vec3(-707.56, -146.37, 37.41),
    },
    
    [8] = {
        clothes = getClothes, permission = nil, coords = vec3(-165.08, -307.2, 39.73),
    },
    
    [9] = {
        clothes = getClothes, permission = nil, coords = vec3(-162.84, -300.76, 39.73),
    },

    [10] = {
        clothes = getClothes, permission = nil, coords = vec3(-821.3, -1070.04, 11.32),
    },

    [11] = {
        clothes = getClothes, permission = nil, coords = vec3(-826.14, -1081.52, 11.32),
    },
    
    [12] = {
        clothes = getClothes, permission = nil, coords = vec3(-827.02, -1078.87, 11.32),
    },
    
    [13] = {
        clothes = getClothes, permission = nil, coords = vec3(-828.92, -1076.78, 11.32),
    },

    [14] = {
        clothes = getClothes, permission = nil, coords = vec3(-1201.46, -772.74, 17.3),
    },

    [15] = {
        clothes = getClothes, permission = nil, coords = vec3(-1192.77, -768.35, 17.32),
    },

    [16] = {
        clothes = getClothes, permission = nil, coords = vec3(-1192.48, -775.55, 17.32),
    },

    [17] = {
        clothes = getClothes, permission = nil, coords = vec3(-1447.18, -234.17, 49.81),
    },

    [18] = {
        clothes = getClothes, permission = nil, coords = vec3(-1451.63, -239.3, 49.81),
    },

    [19] = {
        clothes = getClothes, permission = nil, coords = vec3(4.36, 6508.95, 31.88),
    },

    [20] = {
        clothes = getClothes, permission = nil, coords = vec3(6.7, 6521.17, 31.88),
    },
    [21] = {
        clothes = getClothes, permission = nil, coords = vec3(8.18, 6518.71, 31.88),
    },

    [22] = {
        clothes = getClothes, permission = nil, coords = vec3(10.3, 6517.01, 31.88),
    },
    
    [23] = {
        clothes = getClothes, permission = nil, coords = vec3(1696.73, 4820.63, 42.06),
    },
    
    [24] = {
        clothes = getClothes, permission = nil, coords = vec3(1687.89, 4829.41, 42.06),
    },
    
    [25] = {
        clothes = getClothes, permission = nil, coords = vec3(1690.77, 4829.23, 42.06),
    },
    
    [26] = {
        clothes = getClothes, permission = nil, coords = vec3(1693.35, 4829.98, 42.06),
    },
        
    [27] = {
        clothes = getClothes, permission = nil, coords = vec3(129.91, -215.06, 54.56),
    },
    
    [28] = {
        clothes = getClothes, permission = nil, coords = vec3(125.41, -222.93, 54.56),
    },
        
    [29] = {
        clothes = getClothes, permission = nil, coords = vec3(121.15, -217.76, 54.56),
    },

    [30] = {
        clothes = getClothes, permission = nil, coords = vec3(614.1, 2753.2, 42.09),
    },
    
    [31] = {
        clothes = getClothes, permission = nil, coords = vec3(614.93, 2762.19, 42.09),
    },
        
    [32] = {
        clothes = getClothes, permission = nil, coords = vec3(621.08, 2759.46, 42.09),
    },
            
    [33] = {
        clothes = getClothes, permission = nil, coords = vec3(1199.35, 2712.53, 38.22),
    },

    [34] = {
        clothes = getClothes, permission = nil, coords = vec3(1189.53, 2705.1, 38.22),
    },
    
    [35] = {
        clothes = getClothes, permission = nil, coords = vec3(1189.96, 2707.96, 38.22),
    },
        
    [36] = {
        clothes = getClothes, permission = nil, coords = vec3(1189.38, 2710.63, 38.22),
    },

    [37] = {
        clothes = getClothes, permission = nil, coords = vec3(-3165.89, 1051.94, 20.86),
    },
    
    [38] = {
        clothes = getClothes, permission = nil, coords = vec3(-3170.9, 1044.47, 20.86),
    },
        
    [39] = {
        clothes = getClothes, permission = nil, coords = vec3(-3174.9, 1049.91, 20.86),
    },
    
    [40] = {
        clothes = getClothes, permission = nil, coords = vec3(-1101.13, 2714.08, 19.11),
    },

    [41] = {
        clothes = getClothes, permission = nil, coords = vec3(-1103.32, 2702.05, 19.11),
    },
    
    [42] = {
        clothes = getClothes, permission = nil, coords = vec3(-1104.84, 2704.42, 19.11),
    },
        
    [43] = {
        clothes = getClothes, permission = nil, coords = vec3(-1106.98, 2705.98, 19.11),
    },

    [44] = {
        clothes = getClothes, permission = nil, coords = vec3(428.09, -808.9, 29.49),
    },

    [45] = {
        clothes = getClothes, permission = nil, coords = vec3(420.56, -799.04, 29.49),
    },
    
    [46] = {
        clothes = getClothes, permission = nil, coords = vec3(423.3, -799.52, 29.49),
    },
        
    [47] = {
        clothes = getClothes, permission = nil, coords = vec3(425.89, -799.23, 29.49),
    },

    [48] = { -- CIVIL
        clothes = getClothes, permission = nil, coords = vec3(1790.58,3604.4,36.5),
    },

    [49] = { -- HOSPITAL
        clothes = getClothes, permission = nil, coords = vec3(1139.83,-1538.59,35.03),
    },

    [50] = { -- MECÂNICA
        clothes = getClothes, permission = nil, coords = vec3(826.42,-953.77,22.09),
    },

    [51] = { -- 
        clothes = getClothes, permission = nil, coords = vec3(-2150.83,-509.43,12.25),
    },

    [52] = { -- 
        clothes = getClothes, permission = nil, coords = vec3(2622.31,5341.4,45.63),
    },

    [53] = { -- 
        clothes = getClothes, permission = nil, coords = vec3(1380.18,-747.71,65.85),
    },

    [54] = { -- 
        clothes = getClothes, permission = nil, coords = vec3(-2304.92,352.88,174.6),
    },

    [55] = { -- 
        clothes = getClothes, permission = nil, coords = vec3(-1136.22,368.73,74.96),
    },

    [56] = { -- 
        clothes = getClothes, permission = nil, coords = vec3(883.13,-2100.79,30.46),
    },

    [57] = { -- 
        clothes = getClothes, permission = nil, coords = vec3(-1420.4,5128.08,66.05),
    },

    [58] = { -- 
        clothes = getClothes, permission = nil, coords = vec3(841.72,1825.31,138.74),
    },
    [59] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(617.17,2551.23,63.41),
    },
    [60] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(1935.82,71.32,188.62),
    },
    [61] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-1298.46,-293.14,40.73),
    },
    [62] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(1568.27,1449.09,111.17),
    },
    [63] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(2550.44,2411.24,53.8),
    },
    [64] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(960.8,-3141.96,9.71),
    },
    [65] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(955.68,-3208.62,6.2),
    },
    [66] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-2185.39,-510.71,12.96),
    },
    [67] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-245.39,1560.68,349.82),
    },
    [68] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-1820.37,34.49,94.59),
    },
    [69] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-559.38,-2409.45,19.12),
    },
    [70] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-316.98,6097.55,33.62),
    },
    [71] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-1421.1,5128.34,66.05),
    },
    [72] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(1140.2,-1539.59,35.03),
    },
    [73] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(11209.08,-107.88,65.33),
    },
    [74] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(1424.7,-232.16,177.83),
    },
    [75] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(1211.91,-104.84,65.33),
    },
    [76] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(2394.72,412.77,175.17),
    },
    [77] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(1480.73,-817.93,116.23),
    },
    [78] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(702.57,3801.55,36.11),
    },
    [79] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(1911.04,6404.67,76.36),
    },
    [80] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(381.22,-742.74,29.96),
    },
    [81] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(1784.44,-2322.93,151.88),
    },
    [82] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(2544.35,3437.13,74.29),
    },
    [83] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(458.43,-1146.63,30.75), 
    },
    [84] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(2272.3,2639.11,68.39), 
    },
    [85] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(598.5,889.15,233.82), 
    },
    [86] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(709.5,3835.14,46.71), 
    },
    [87] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-2357.82,3254.38,32.81), 
    },
    [88] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-336.77,-166.37,44.58), 
    },
    [89] = { -- 
    clothes = getClothes, permission = nil, coords = vec3(-2185.18,-192.5,61.33), 
    },

    ["admin"] = {
        clothes = getClothes
    },

    ["nation_creator"] = {
        clothes = getClothes
    },
}

RegisterNetEvent("skinshop:openShop")
AddEventHandler("skinshop:openShop", function()
    toggleMenu("admin")
end)  

nearestSkinshops = {}
mainThread = function()
    local getNearestSkinshops = function()
        while true do
            if not inMenu then
                local myCoords = GetEntityCoords(PlayerPedId())
                for k,v in pairs(skinshops) do
                    if v and v.coords then
                        local distance = #(myCoords - v.coords)
                        if nearestSkinshops[k] then
                            if distance > 10 then
                                nearestSkinshops[k] = nil
                            end
                        else
                            if distance <= 10 then
                                nearestSkinshops[k] = v
                            end
                        end
                    end
                end
            end
            Wait(500)
        end
    end

--    addBlips()
    CreateThread(getNearestSkinshops)

    while true do
        local idle = 500
        local ped = PlayerPedId()
        local myCoords = GetEntityCoords(ped)
        if not inMenu then
            for skinShopId, v in pairs(nearestSkinshops) do
                if v and v.coords and GetEntityHealth(ped) > 101 then 
                    idle = 0 
                    local coords = v.coords
                    local distance = #(myCoords - v.coords)
                    if IsDisabledControlJustPressed(0,38) and distance < 1.6 then
                        if v.permission then
                            if func.checkPermission(v.permission) then
                                SetEntityHeading(ped,(GetEntityHeading(ped) + 180.0) % 360.0)
                                toggleMenu(skinShopId)
                  
                            end
                        else
                            SetEntityHeading(ped,(GetEntityHeading(ped) + 180.0) % 360.0)
                            toggleMenu(skinShopId)
                        end
                    end
                end
            end
        end
        Wait(idle)
    end
end

CreateThread(function()
	local Tables = {}
	for Number = 1,#skinshops do
		Tables[#Tables + 1] = { skinshops[Number]["coords"]["x"],skinshops[Number]["coords"]["y"],skinshops[Number]["coords"]["z"],2.0,"E","Loja de Roupas","Pressione para abrir" }
	end
	TriggerEvent("hoverfy:Insert",Tables)
end)

function addBlips()
    for _, v in pairs(skinshops) do
        local coords = v.coords
        if coords and v.blip ~= false then
            local blip = AddBlipForCoord(coords)
            SetBlipSprite(blip, v.id or 73)
            SetBlipColour(blip, v.color or 13)
            SetBlipScale(blip, 0.4)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(v.Name or "Loja de Roupas")
            EndTextCommandSetBlipName(blip)
        end
    end
end

function DrawText3D(x,y,z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    SetTextScale(0.45, 0.45)
    SetTextFont(6)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
end

RegisterNetEvent("nation_skinshop:toggleMenu")
AddEventHandler("nation_skinshop:toggleMenu", function(menu)
    toggleMenu(menu)
end)

--------- CREATIVE V3 ------------
mySkinData = {}

local skinData = {
	["pants"] = "legs",
	["arms"] = "torsos",
	["tshirt"] = "undershirts",
	["torso"] = "tops",
	["vest"] = "bodyArmors",
	["backpack"] = "bags",
	["shoes"] = "shoes",
	["mask"] = "masks",
	["hat"] = "hats",
	["glass"] = "glasses",
	["ear"] = "ears",
	["watch"] = "watches",
	["bracelet"] = "bracelets",
	["accessory"] = "accessories",
	["decals"] = "decals"
}

function fclient.getCloths()
    local myCloths = getMyClothes()
    local cloths = {}
    for cloth, comp in pairs(skinData) do
        local item = myCloths[comp][1]
        local texture = myCloths[comp][2]
        cloths[cloth] = { item = item, texture = texture }
    end
    mySkinData = cloths
    return cloths
end

RegisterNetEvent("updateRoupas")
AddEventHandler("updateRoupas",function(custom)
	mySkinData = custom
	func.updateClothes()
end)

RegisterCommand('skinshop',function()
    if func.checkPermission({"Admin"}) or func.checkPermission({"Owner"}) then
        toggleMenu("admin")
    end
end)