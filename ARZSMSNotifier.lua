local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local effil = require("effil")
local imgui = require 'imgui'
local ffi = require('ffi')
local sampev = require 'samp.events'
local requests = require 'requests'

local UPDATE_URL = "https://raw.githubusercontent.com/nikanikoo/ARZSMSNotifier/main/ARZSMSNotifier.lua"
local VERSION_CHECK_URL = "https://raw.githubusercontent.com/nikanikoo/ARZSMSNotifier/refs/heads/main/version"

local script_version = "1.1"
local show_main_window = imgui.ImBool(false)

local color = "0x337EA9"
local color_main = imgui.ImVec4(0.2, 0.494, 0.663, 1.0)    -- #337EA9
local color_hover = imgui.ImVec4(0.25, 0.58, 0.78, 1.0)    -- #4094C7 
local color_active = imgui.ImVec4(0.16, 0.39, 0.53, 1.0)   -- #296387
local color_title = imgui.ImVec4(0.15, 0.37, 0.5, 1.0)     -- #265E80

local config = {
    bot_token = "",
    chat_id = "",
    is_bound = false,
    enabled = true
}

local input = {
    bot_token = imgui.ImBuffer(256),
    manual_chat_id = imgui.ImBuffer(64)
}

-- ������� ��� �������� ����������
function checkForUpdates()
    local current_version = script_version
    
    -- �������� ��������� ������ � GitHub
    local success, response = pcall(function()
        return requests.get(VERSION_CHECK_URL)
    end)
    
    if success and response and response.status_code == 200 then
        -- ������� ��� ���������� �������, ����� ����� � ����
        local latest_version = response.text:match("[%d.]+")
        
        if latest_version then
            -- ����������� ������ ��� ���������
            local function version_to_number(ver)
                local parts = {}
                for part in ver:gmatch("%d+") do
                    table.insert(parts, tonumber(part))
                end
                return parts
            end
            
            local current_parts = version_to_number(current_version)
            local latest_parts = version_to_number(latest_version)
            
            -- ���������� �� ������
            for i = 1, math.max(#current_parts, #latest_parts) do
                local current = current_parts[i] or 0
                local latest = latest_parts[i] or 0
                
                if latest > current then
                    return true, latest_version
                elseif latest < current then
                    return false, current_version
                end
            end
        end
    else
        print("[ARZSMSNotifier] ������ ��� �������� ����������: " .. (response and response.text or "unknown"))
    end
    return false, current_version
end

-- ������� ��� �������� ����������
function downloadUpdate()
    local success, response = pcall(function()
        return requests.get(UPDATE_URL)
    end)
    
    if success and response and response.status_code == 200 then
        local path = thisScript().path
        local file = io.open(path, "wb")
        if file then
            file:write(response.text)
            file:close()
            return true
        end
    end
    return false
end

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
        print("[ARZSMSNotifier] ������ ��������: " .. (err or res.text or "unknown"))
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

-- Render UI
function imgui.OnDrawFrame()
    if not show_main_window.v then return end

    local style = imgui.GetStyle()

    -- ��������� ������ ������
    style.Colors[imgui.Col.Button] = color_main
    style.Colors[imgui.Col.ButtonHovered] = color_hover
    style.Colors[imgui.Col.ButtonActive] = color_active
    
    -- ��������� ������ ��������� ����
    style.Colors[imgui.Col.TitleBg] = color_title               -- ���������� ���������
    style.Colors[imgui.Col.TitleBgActive] = color_main          -- �������� ���������
    style.Colors[imgui.Col.TitleBgCollapsed] = color_title      -- ��������� ���������

    -- �������� ������� �������
    local io = imgui.GetIO()
    local screenWidth = io.DisplaySize.x
    local screenHeight = io.DisplaySize.y

    imgui.SetNextWindowPos(imgui.ImVec2(
        (screenWidth - 650) / 2,
        (screenHeight - 250) / 2
    ), imgui.Cond.Always)

    imgui.SetNextWindowSize(imgui.ImVec2(650, 250), imgui.Cond.FirstUseEver)
    imgui.Begin("ARZSMSNotifier (" .. script_version .. ") by nikanikoo", show_main_window)

    imgui.Text(u8"��������� Telegram:")
    imgui.InputText(u8"Bot Token", input.bot_token)
    
    imgui.InputText(u8"Chat ID (UserID, ���� � ��)", input.manual_chat_id)
    if imgui.Button(u8"��������� ���������") then
        if input.manual_chat_id.v ~= "" then
            config.chat_id = input.manual_chat_id.v
            config.is_bound = true
            saveConfig()
            sampAddChatMessage("[ARZSMSNotifier] {ffffff}��������� ���������.", color)
        end
    end
    imgui.Text(u8"��� ��������� UserID ������ /start ���� @getmyid_bot")
    imgui.Text(u8"��� ��������� ChatID (���� ������, ����� ����������� ��������� � ������) ������� � ������\n����� �������, ��������� � ������ � �� ������ ������ ID ���� (#123456789), � ������ \n���������� -100 � ��� ���������� ��� ���� (�� �������� ���������� ���� � ���!)")
    imgui.Text(u8"��� ��������� Bot Token �������� ���� ����� @BotFather (/newbot, ����� ��� ������� ����� ����.\n����� ����, ��� �������� ����� ��������� � �� � ����� ����� � ��������� /start)")
    imgui.End()
end

function sampev.onServerMessage(_, text)
    if text:match("^��� ������ ���������! (.+)") then
        sendTg(text)
    end

    -- if text:find("����������� ������� 'Y' ��� ����, (.+)") then
    --     prev = true
    --     return false
    -- end
    -- if string.find(string.lower(text), "������ ��������� ��������������� �����:") and prev == true then
    --     if prev_text ~= "" then
    --         sendTg("�� ��� ������� ��������� �������� ������!")
    --         prev = false
    --         return false
    --     end
    -- end
end

function main()
    while not isSampAvailable() do wait(100) end

    -- �������� ���������� ��� �������
    local update_available, latest_version = checkForUpdates()
    if update_available then
        sampAddChatMessage("[ARZSMSNotifier] {ffffff}�������� ���������� {337EA9}v"..latest_version.."{ffffff}! �����������...", color)
        if downloadUpdate() then
            sampAddChatMessage("[ARZSMSNotifier] {ffffff}���������� ������� ���������!", color)
            return
        else
            sampAddChatMessage("[ARZSMSNotifier] {ffffff}������ �������� ����������.", color)
        end
    else
        sampAddChatMessage("[ARZSMSNotifier] {ffffff}������ ({337EA9}v" .. script_version .. "{ffffff}) ��������! ������� ��� ������ ��������: {337EA9}/smstg.", color)
        sampAddChatMessage("[ARZSMSNotifier] {ffffff}by {337EA9}nikanikoo{ffffff} (Nika_Pearcy); TG: @{337EA9}seni4e4ka{ffffff}", color)
    end

    loadConfig()

    -- ��������� ������� ��� ������ �������� ����������
    sampRegisterChatCommand("smstgupdate", function()
        local update_available, latest_version = checkForUpdates()
        if update_available then
            sampAddChatMessage("[ARZSMSNotifier] {ffffff}�������� ���������� {337EA9}v"..latest_version.."{ffffff}! ���������...", color)
            if downloadUpdate() then
                sampAddChatMessage("[ARZSMSNotifier] {ffffff}���������� ������� ���������!", color)
                return
            else
                sampAddChatMessage('[ARZSMSNotifier] {ffffff}������ �������� ����������.', color)
            end
        else
            sampAddChatMessage("[ARZSMSNotifier] {ffffff}� ��� ����������� ��������� ������ {337EA9}v" .. latest_version .. "{ffffff}.", color)
        end
    end)
    sampRegisterChatCommand("smstg", function()
        show_main_window.v = not show_main_window.v
    end)

    while true do
        wait(0)
        imgui.Process = show_main_window.v
    end
end
