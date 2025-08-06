local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
fclient = Tunnel.getInterface("nation_creator")
func = {}
Tunnel.bindInterface("nation_creator", func)
vHUD = Tunnel.getInterface("hud")
REQUEST = Tunnel.getInterface("request")

multiCharacter = true

---------------------------------------------------------------------------
-----------------------VERIFICAÇÃO DE PERMISSÃO--------------------------
---------------------------------------------------------------------------

if multiCharacter then
    vRP._Prepare("nation_creator/createAgeColumn","ALTER TABLE characters ADD IF NOT EXISTS age INT(11) NOT NULL DEFAULT 20")
    vRP._Prepare("nation_creator/update_user_first_spawn","UPDATE characters SET Lastname = @firstName, Name = @Name, age = @age, sex = @sex WHERE id = @user_id")
    vRP._Prepare("nation_creator/create_characters","INSERT INTO characters(license,Name,Lastname,phone,blood) VALUES(@steam,@Name,@Lastname,@phone,@blood)")
    vRP._Prepare("nation_creator/remove_characters","UPDATE characters SET deleted = 1 WHERE id = @id")
    vRP._Prepare("nation_creator/get_characters","SELECT * FROM characters WHERE license = @steam and deleted = 0")
    vRP._Prepare("nation_creator/get_character","SELECT * FROM characters WHERE license = @steam and deleted = 0 and id = @user_id")
    vRP._Prepare("nation_creator/get_bank","SELECT * FROM characters WHERE id = @user_id")
    CreateThread(function() vRP.Query("nation_creator/createAgeColumn") end) -- criar coluna idade na db
else
    vRP._Prepare("nation_creator/update_user_first_spawn","UPDATE vrp_user_identities SET firstName = @firstName, Name = @Name, age = @age WHERE user_id = @user_id")
end


function func.checkPermission(permission, src)
    local source = src or source
    local user_id = vRP.getUserId(source)
    if type(permission) == "table" then
        for i, perm in pairs(permission) do
            if vRP.HasGroup(user_id, perm, 3) then
                return true
            end
        end
        return false
    end

    return vRP.HasGroup(user_id, permission, 3)
end


function func.saveChar(Name, lastName, age, char, id)
    -- Validação básica dos nomes
    if not Name or Name == "" then
        return false, "Nome inválido"
    end
    
    -- O sobrenome agora é opcional, mas vamos garantir que não seja nil
    if not lastName then
       lastName = ""
    end
    
    -- Garante que o char tenha dados mínimos
    char = char or {}
    char.gender = char.gender or (GetEntityModel(GetPlayerPed(source)) == GetHashKey("mp_f_freemode_01") and "female" or "male")

    -- Persistência dos dados
    local user_id = vRP.getUserId(source)
    vRP.setUData(user_id, "nation_char", json.encode(char))
    
    local sex = char.gender == "female" and "F" or "M"
    
    vRP.Query("nation_creator/update_user_first_spawn", {
        user_id = user_id,
        firstName = lastName or "", -- Envia uma string vazia se não houver sobrenome
        Name = Name,
        age = age,
        sex = sex
    })

    -- Atualizações complementares
    TriggerClientEvent("nation_barbershop:init", source, char)
    vRP.SkinCharacter(user_id, sex == "F" and "mp_f_freemode_01" or "mp_m_freemode_01")
    
    return true
end


function getUserChar(user_id, source, nation)
    local char
    local data = vRP.getUData(user_id, "nation_char")
    if data and data.hair then
        char = data
        char.gender = getGender(user_id) or char.gender
    end
    
    return char
end


local userlogin = {}
function playerSpawn(user_id, source, first_spawn)
    if first_spawn then
        Wait(1000)
		processSpawnController(source,getUserChar(user_id, source),user_id)
	end
end

AddEventHandler("vRP:playerSpawn",playerSpawn)

function processSpawnController(source,char,user_id)
    getUserLastPosition(source, user_id)
    local source = source
    if char then
        if not userlogin[user_id] then
            userlogin[user_id] = true
            fclient._spawnPlayer(source,false)
        else
            fclient._spawnPlayer(source,true)
        end
        fclient.setPlayerChar(source, char, true)
        TriggerClientEvent("nation_barbershop:init", source, char)
        setPlayerTattoos(source, user_id)
        fclient._setClothing(source, getUserClothes(user_id))
    else
        userlogin[user_id] = true
        local data = vRP.getUData(user_id, "Barbershop")
        if data then 
            local gender = getGender(user_id)
            fclient._spawnPlayer(source,false)
            fclient._setOldChar(source, data, getUserClothes(user_id), gender, user_id)
        else
            fclient._startCreator(source)
        end
    end
end




function setPlayerTattoos(source, user_id)
    TriggerClientEvent("tattoos:Apply", source, getUserTattoos(user_id))
    TriggerClientEvent("reloadtattos", source)
    TriggerEvent('dpn_tattoo:setPedServer', source)
    TriggerClientEvent("nyoModule:tattooUpdate", source, false)
end


function func.setPlayerTattoos(id)
    local source = source
    local user_id = id or vRP.getUserId(source)
    if user_id then
        setPlayerTattoos(source, user_id)
    end
end

function getUserLastPosition(source, user_id)
    local coords = {-1198.02,-146.04,40.12}
    local datatable = vRP.getUserDataTable(user_id)
    if datatable and datatable.Pos then
        local p = datatable.Pos
        coords = { p.x, p.y, p.z }
    else
        local data = vRP.getUData(user_id, "Datatable")
        if data and data.Pos then
            local p = data.Pos
            coords = { p.x, p.y, p.z }
        end
    end
    fclient._setPlayerLastCoords(source, coords)
    return coords
end


function func.getUserLastPosition()
    local source = source
    local user_id = vRP.getUserId(source)
    getUserLastPosition(source, user_id)
end



function Dotted(Value)
	local Value = parseInt(Value)
	local Left,Number,Right = string.match(Value,"^([^%d]*%d)(%d*)(.-)$")
	return Left..(Number:reverse():gsub("(%d%d%d)","%1."):reverse())..Right
end


function func.changeSession(session)
    local source = source
    SetPlayerRoutingBucket(source, session)
end

function func.updateLogin()
    local source = source
    local user_id = vRP.getUserId(source)
    if user_id then
        userlogin[user_id] = true
        local char = getUserChar(user_id, source)
        if char then 
            TriggerClientEvent("nation_barbershop:init", source, char)
            setPlayerTattoos(source, user_id)
        end
    end
end


function vRP.Identity(user_id)
    local rows = vRP.Query("nation_creator/get_bank", { user_id = user_id })
    if rows and rows[1] then
        return rows[1]
    end
end


function FullName(Passport)
    local Passport = parseInt(Passport)
    if not Passport then return "Individuo Indigente" end
    
    local Identity = vRP.Identity(Passport)
    if not Identity then return "Individuo Indigente" end
    
    local firstName = Identity.Name or ""
    local lastName = Identity.Lastname or ""
    
    local fullName = (firstName.." "..lastName):gsub("%s+"," "):trim()  
    return fullName ~= "" and fullName or "Individuo Indigente"
end

-- A validação do nome foi flexibilizada
function isValidName(name)
    if not name or type(name) ~= "string" then return false end
    return true -- Qualquer nome válido (não nulo ou vazio) será aceito
end





function func.getCharsInfo()
    local source = source
    local steam = getPlayerSteam(source)
    local data = vRP.Query("nation_creator/get_characters", { steam = steam })
    local info = { chars = {} }

    for k, v in ipairs(data) do
        -- Corrige nome vazio ou inválido
        local displayName = "Indivíduo Indigente"
        if v.Name and v.Lastname and v.Name ~= "" and v.Lastname ~= "" then
            displayName = v.Name.." "..v.Lastname
        elseif v.Name and v.Name ~= "" then
            displayName = v.Name
        end

        -- Corrige gênero
        local gender = "masculino"
        if v.sex == "F" then
            gender = "feminino"
        elseif v.sex ~= "M" then
            gender = "outros"
        end

        -- Corrige telefone
        local phone = v.phone or "Não definido"

        -- Corrige banco
        local Identity = vRP.Identity(v.id)
        local bank = Identity and Identity["Bank"] or 0

        info.chars[k] = {
            Name = displayName,
            age = (v.age or 20).." anos",
            bank = "$ "..Dotted(bank),
            clothes = getUserClothes(v.id) or {},
            registration = Sanguine(v.blood) or "A+",
            phone = phone,
            user_id = v.id,
            id = "#"..v.id,
            gender = gender,
            char = getUserChar(v.id, source) or {}
        }
    end

    info.maxChars = getUserMaxChars(source)
    return info
end















function getUserMaxChars(source)
    local steam = getPlayerSteam(source)
    local Account = vRP.Account(steam)
    local amountCharacters = parseInt(Account and Account["Characters"] or 1)
    if vRP.steamPremium(steam) then
        amountCharacters = amountCharacters + 2
    end
    return amountCharacters 
end


function getUserClothes(user_id)
    local data = vRP.getUData(user_id, "Clothings")
    if data and not isEmpty(data) then
        return data
    end
    return {}
end

function getUserTattoos(user_id)
    local data = vRP.getUData(user_id,"Tatuagens")
    if data and not isEmpty(data) then
       local custom = data
       return custom or {}
    end
    data = vRP.getUData(user_id,"Tattoos")
    if data and not isEmpty(data) then
       local custom = data  
       return custom or {}
    end
    return {}
end

function isEmpty(t)
    if type(t) == "string" and t ~= "" then
        return false
    end
    for k,v in pairs(t) do
        if v then
            return false
        end
    end
    return true
end

function getGender(user_id)
    local datatable = vRP.getUserDataTable(user_id) or vRP.getUData(user_id, "Datatable") or {}
    if type(datatable) == "table" then
        local model = datatable.Skin or datatable.customization
        if model then
            if type(model) == "table" then
                model = model.modelhash or model.model
            end
            if model == GetHashKey("mp_m_freemode_01") or model == "mp_m_freemode_01" then
                return "male"
            elseif model == GetHashKey("mp_f_freemode_01") or model == "mp_f_freemode_01" then
                return "female"
            else
                return model
            end
        end
    end
end

function func.getOverlay()
    local source = source
    local user_id = vRP.getUserId(source)
    if user_id then
        local char = getUserChar(user_id, source, true)
        if char and char.overlay then
            return char.overlay
        end
    end
    return 0
end




function func.playChar(info)
    local source = source
    if not info or not info.user_id then return false, "ID de usuário inválido." end
    local steam = getPlayerSteam(source)
    local data = vRP.Query("nation_creator/get_character",{ steam = steam, user_id = info.user_id })
    if #data > 0 then
        -- TriggerEvent("baseModule:idLoaded",source,info.user_id,nil)
        vRP.CharacterChosen(source,info.user_id,nil)
        --print(vRP.getUserId(source), vRP.Passport(source))
        local user_id = vRP.Passport(source)
        local ip = GetPlayerEP(source) or '0.0.0.0'
      --  vRP.sendLog('joins', '[ID]: '..user_id..' \n[IP]: '..ip..' \n[======ENTROU NO SERVIDOR======]'..os.date("\n[Data]: %d/%m/%Y [Hora]: %H:%M:%S"), true)
        playerSpawn(user_id, source, true)
    end
end


function func.tryDeleteChar(info)
    local source = source
    local steam = getPlayerSteam(source)
    local data = vRP.Query("nation_creator/get_character",{ steam = steam, user_id = info.user_id })
    --[[if #data > 0 then
        vRP.Query("nation_creator/remove_characters",{ id = info.user_id })
        return true, ""
    end]]
    return false, "Não permitido"
end

function func.tryCreateChar()
    local source = source
    local steam = getPlayerSteam(source)
    
    -- Verificação de limites
    local maxChars = vRP.steamPremium(steam) and 3 or 1
    local currentChars = #vRP.Query("nation_creator/get_characters", {steam = steam})
    
    if currentChars >= maxChars then
        return false, "Limite de personagens atingido"
    end

    -- Cria registro inicial com um nome e sobrenome padrão
    local newChar = {
        steam = steam,
        Name = "Individuo", -- Adicionado nome padrão para evitar o erro de NULL
        Lastname = "Indigente", -- Adicionado sobrenome padrão
        phone = vRP.GeneratePhone(),
        blood = math.random(4)
    }
    
    vRP.Query("nation_creator/create_characters", newChar)
    
    -- Recupera ID do novo personagem
    local chars = vRP.Query("nation_creator/get_characters", {steam = steam})
    local newId = chars[#chars].id
    
    -- Prepara dados básicos
    vRP.setUData(newId, "nation_char", json.encode({
        gender = "male",
        model = "mp_m_freemode_01"
    }))
    
    return true, newId
end


function getPlayerSteam(source)
    --[[ local identifiers = GetPlayerIdentifiers(source)
	for k,v in ipairs(identifiers) do
		if string.sub(v,1,5) == "steam" then
			return splitString(v,":")[2]
		end
	end ]]
    return vRP.Identities(source)
end


--[[RegisterCommand("char", function(source) -- setar as customizações dnv (tipo bvida)
    local user_id = vRP.getUserId(source)
    local char = getUserChar(user_id, source)
    if char then
        fclient._setPlayerChar(source, char, true)
        TriggerClientEvent("nation_barbershop:init", source, char)
        setPlayerTattoos(source, user_id)
        fclient._setClothing(source, getUserClothes(user_id))
    end
end)]]

RegisterCommand('resetchar',function(source, args) -- COMANDO DE ADMIN PARA RESETAR PERSONAGEM
    if func.checkPermission({"admin.permissao", "mod.permissao", "Admin"}, source) then
        local Passport = vRP.Passport(source)
        if args[1] then 
            local id = tonumber(args[1])
            if id then
                local src = vRP.getUserSource(id)
                if src and vHUD.Request(source, "Deseja resetar o id "..id.." ?",'Sim','Não') then
                    fclient._startCreator(src)
                    vRP.sendLog('resetchar', '[ID]: '..Passport..'\n[RESETOU O PERSONAGEM DE]: '..args[1]..' '..os.date("\n[Data]: %d/%m/%Y [Hora]: %H:%M:%S"), true)
                end
            end
        elseif vHUD.Request(source, "Deseja resetar seu personagem ?",'Sim','Não') then
            fclient._startCreator(source)
            vRP.sendLog('resetchar', '[ID]: '..Passport..'\n[RESETOU O PERSONAGEM]: PERONSAGEM PRÓPRIO '..os.date("\n[Data]: %d/%m/%Y [Hora]: %H:%M:%S"), true)
        end
    end
end)

RegisterCommand('reset',function(source, args) -- COMANDO DE ADMIN PARA RESETAR PERSONAGEM
    if vRP.HasGroup(Passport,"Admin", 2) or not vRP.getUserId(source) then
        if args[1] then 
            local id = tonumber(args[1])
            if id then
                local src = vRP.Source(id)
                if src and vRP.Request(source, "Deseja resetar o id "..id.." ?", "Sim", "Não") then
                    fclient._startCreator(src)
                end
            end
        elseif 
            vRP.Request(source, "Deseja resetar seu personagem ?", "Sim", "Não") then
            fclient._startCreator(source)
        end
    end
end)

RegisterCommand('spawn',function(source) -- COMANDO DE ADMIN PARA SIMULAR O SPAWN
    local Passport = vRP.Passport(source)
    if vRP.HasGroup(Passport,"Admin", 2) or not vRP.getUserId(source) then
        if multiCharacter then
            vRP.playerDropped(source,"Trocando Personagem.")
            Wait(1000)
            TriggerClientEvent("spawn:setupChars", source)
        else
            playerSpawn(vRP.getUserId(source), source, true)
        end
     end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- REesetandoplayer
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("nation:resetplayer")
AddEventHandler("nation:resetplayer",function(source,user_id)
    if source ~= nil then
        fclient._startCreator(source)
    end
end)