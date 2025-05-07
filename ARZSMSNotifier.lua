local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local effil = require("effil")
local imgui = require 'imgui'
local ffi = require('ffi')
local sampev = require 'samp.events'
local requests = require 'requests'

local script_version = "1.0"
local show_main_window = imgui.ImBool(false)

local config = {
    bot_token = "",
    chat_id = "",
    is_bound = false,
    bind_in_progress = false,
    enabled = true
}

local input = {
    bot_token = imgui.ImBuffer(256),
    bind_code_input = imgui.ImBuffer(6),
    notification_word = imgui.ImBuffer(64),
    manual_chat_id = imgui.ImBuffer(64)
}


-- Load config from file
function loadConfig()
    local path = getWorkingDirectory() .. "/ARZSMSNotifier-config.json"
    local f = io.open(path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local success, result = pcall(function() return decodeJson(content) end)
        if success then
            config = result
            input.bot_token.v = config.bot_token
            input.manual_chat_id.v = config.chat_id
        end
    end
end

-- Save config to file
function saveConfig()
    config.bot_token = input.bot_token.v
    config.notification_word = input.notification_word.v
    if input.manual_chat_id.v ~= "" then
        config.chat_id = input.manual_chat_id.v
        config.is_bound = true
    end
    local path = getWorkingDirectory() .. "/ARZSMSNotifier-config.json"
    local f = io.open(path, "w")
    if f then
        f:write(encodeJson(config))
        f:close()
    end
end

-- Send Telegram message
function sendTelegramMessage(text)
    if config.bot_token == "" or config.chat_id == "" then return false end
    local url = string.format("https://api.telegram.org/bot%s/sendMessage", config.bot_token)
    print(text)
    local body = {
        chat_id = config.chat_id,
        text = text
    }
    local headers = {
        'Content-Type: application/json'
    }
    local res, err = requests.post(url, { json = body, headers = headers })
    if not res or res.status_code ~= 200 then
        print("[TG] Ошибка отправки: " .. (err or res.text or "unknown"))
        return false
    end
    return true
end

function sendTg(text)
    asyncHttpRequest("GET", "https://api.telegram.org/bot" .. config.bot_token .. "/sendMessage?chat_id=" .. config.chat_id .. "&text=" .. u8:encode(text:gsub(" ", "%+"):gsub("\n", "%%0A"), "CP1251"))
end

function asyncHttpRequest(method, url)
    local request_thread = effil.thread(function(method, url)
        local requests = require("requests")
        local result, response = pcall(requests.request, method, url)
        if result then
            response.json, response.xml = nil, nil
            return true, response
        else
            return false, response
        end
    end)(method, url)
end

function imgui.OnInitialize()
    local font_path = getWorkingDirectory() .. "\\resource\\fonts\\fa-solid-900.ttf" 
    imgui.GetIO().Fonts:AddFontFromFileTTF(font_path, 14.0, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
end

-- Render UI
function imgui.OnDrawFrame()
    if not show_main_window.v then return end

    imgui.SetNextWindowSize(imgui.ImVec2(650, 250), imgui.Cond.FirstUseEver)
    imgui.Begin("ARZSMSNotifier" .. script_version, show_main_window)

    imgui.Text(u8"Настройки Telegram:")
    imgui.InputText(u8"Bot Token", input.bot_token)
    
    imgui.InputText(u8"Chat ID (UserID, если в ЛС)", input.manual_chat_id)
    if imgui.Button(u8"Сохранить настройки") then
        if input.manual_chat_id.v ~= "" then
            config.chat_id = input.manual_chat_id.v
            config.is_bound = true
            saveConfig()
            sampAddChatMessage("{00FF00}[ARZSMSNotifier-TG] Настройки сохранены.", -1)
        end
    end
    imgui.Text(u8"Для получения UserID пишите /start боту @getmyid_bot")
    imgui.Text(u8"Для получения ChatID (если хотите, чтобы уведомления приходили в группу) зайдите в телегу\nчерез браузер, перейдите в группу и из ссылки берите ID чата (#123456789), в начале \nдобавляйте -100 и уже вставляете сам айди (не забудьте инвайтнуть бота в чат!)")
    imgui.Text(u8"Для получения Bot Token создайте бота через @BotFather (/newbot, затем вам выдадут токен бота.\nПосле того, как вставили токен перейдите в ЛС с вашим ботом и отправьте /start)")
    imgui.End()
end

function sampev.onServerMessage(_, text)
    if text:find("Вам пришло сообщение! (.+)") then
        sendTg(text)
    end

    -- if text:find("Используйте клавишу 'Y' для того, (.+)") then
    --     prev = true
    --     return false
    -- end
    -- if string.find(string.lower(text), "Номера телефонов государственных служб:") and prev == true then
    --     if prev_text ~= "" then
    --         sendTg("На ваш телефон поступают входящие вызовы!")
    --         prev = false
    --         return false
    --     end
    -- end
end

function main()
    while not isSampAvailable() do wait(100) end
    loadConfig()

    sampRegisterChatCommand("smstg", function()
        show_main_window.v = not show_main_window.v
    end)

    sampAddChatMessage("{00FF00}[ARZSMSNotifier-TG] Скрипт загружен! Команда для вызова настроек: /smstg.", -1)
    sampAddChatMessage("{00FF00}[ARZSMSNotifier-TG] by nikanikoo (Nika_Pearcy); TG: @seni4e4ka", -1)

    while true do
        wait(0)
        imgui.Process = show_main_window.v
    end
end
