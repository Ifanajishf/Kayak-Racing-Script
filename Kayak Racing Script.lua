-- Kayak Racing – Farming Hub (Ifan Aji build)
-- Fitur: AutoWin, AutoTrain, AutoRebirth, AutoHatch, AntiAFK, FPSBoost, ServerHop
-- Risiko TOS: gunakan di akun alternatif.

-- ==== PREP / LIB ====
local HttpGet = (syn and syn.request) and game.HttpGet or function(...) return game:HttpGet(...) end
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()  -- UI
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ==== STATE ====
getgenv().KR_CFG = getgenv().KR_CFG or {
    autoWin = false,
    legitMode = true,           -- pakai jeda acak biar lebih aman
    tweenSpeed = 250,           -- studs/sec (disesuaikan)
    autoTrain = false,
    trainRadius = 80,           -- radius deteksi titik latihan
    autoRebirth = false,
    minWinsForRebirth = 100,    -- ambang rebirth
    autoHatch = false,
    eggName = "BasicEgg",       -- sesuaikan nama egg
    fpsBoost = true,
    serverHop = false,
    maxPlayers = 10,            -- hop kalau pemain > N
}

-- ==== ANTI-AFK & FPS BOOST ====
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
end)

local function applyFPSBoost(on)
    if on then
        pcall(function() setfpscap(60) end)
        for _,v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
            if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then v.Enabled = false end
            if v:IsA("BasePart") then v.Material = Enum.Material.Plastic end
        end
    end
end
applyFPSBoost(getgenv().KR_CFG.fpsBoost)

-- ==== HELPER: FIND REMOTES / OBJECTS ====
local function findRemote(partial)
    for _,v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.ClassName:find("Remote") and v.Name:lower():find(partial:lower()) then
            return v
        end
    end
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v.ClassName:find("Remote") and v.Name:lower():find(partial:lower()) then
            return v
        end
    end
    return nil
end

local function getFinishPart()
    -- Coba cari “Finish”, “End”, “Goal” di Workspace
    local candidates = {}
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if n:find("finish") or n:find("goal") or n:find("end") then
                table.insert(candidates, v)
            end
        end
    end
    -- pilih yang paling dekat ke pemain untuk jaga-jaga
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if #candidates > 0 and root then
        table.sort(candidates, function(a,b)
            return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
        end)
        return candidates[1]
    end
    return nil
end

local function getTrainTargets(radius)
    local res = {}
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return res end
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") or (v:IsA("BasePart") and v.Name:lower():find("train")) then
            local part = v:IsA("ProximityPrompt") and v.Parent or v
            if part and part:IsA("BasePart") and (part.Position - root.Position).Magnitude <= radius then
                table.insert(res, part)
            end
        end
    end
    return res
end

-- ==== CORE: TWEEN TO FINISH ====
local function tweenTo(part, studsPerSec)
    local char = LocalPlayer.Character
    if not (char and part and part:IsA("BasePart")) then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dist = (hrp.Position - part.Position).Magnitude
    local t = math.clamp(dist / math.max(1, studsPerSec), 0.3, 6) -- batas durasi biar ga terlalu cepat
    local tween = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = part.CFrame + Vector3.new(0,5,0)})
    tween:Play()
    tween.Completed:Wait()
end

-- ==== AUTO WIN LOOP ====
task.spawn(function()
    while task.wait(0.2) do
        if not getgenv().KR_CFG.autoWin then continue end

        -- Mode “legit”: tunggu 1–3 detik sebelum bergerak, dan pecah gerakan jadi 2-3 segmen
        if getgenv().KR_CFG.legitMode then
            task.wait(math.random(8,18)/10)
        end

        local finish = getFinishPart()
        if finish then
            if getgenv().KR_CFG.legitMode then
                -- dua segmen acak sebelum garis finish
                local offset = Vector3.new(math.random(-10,10), 0, math.random(-10,10))
                local ghost = Instance.new("Part")
                ghost.Anchored = true
                ghost.CanCollide = false
                ghost.Transparency = 1
                ghost.Position = finish.Position + offset + Vector3.new(0,0, -12)
                ghost.Parent = Workspace
                tweenTo(ghost, getgenv().KR_CFG.tweenSpeed)
                ghost:Destroy()
            end
            tweenTo(finish, getgenv().KR_CFG.tweenSpeed)
        end
    end
end)

-- ==== AUTO TRAIN LOOP ====
task.spawn(function()
    while task.wait(0.3) do
        if not getgenv().KR_CFG.autoTrain then continue end
        for _,target in ipairs(getTrainTargets(getgenv().KR_CFG.trainRadius)) do
            -- Coba ProximityPrompt
            local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                pcall(function()
                    fireproximityprompt(prompt, 3) -- hold
                end)
            else
                -- sentuh part (beberapa game pakai touch interest)
                pcall(function()
                    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, target, 0)
                    task.wait(0.1)
                    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, target, 1)
                end)
            end
            if getgenv().KR_CFG.legitMode then task.wait(math.random(6,14)/10) end
        end
    end
end)

-- ==== AUTO REBIRTH LOOP ====
local RebirthRemote = findRemote("rebirth") or findRemote("Rebirth")
task.spawn(function()
    while task.wait(2) do
        if not getgenv().KR_CFG.autoRebirth then continue end

        -- Ganti cara cek resource di bawah ini sesuai GUI/leaderstats game
        local wins = 0
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild("Wins") then
            wins = tonumber(ls.Wins.Value) or 0
        end

        if wins >= getgenv().KR_CFG.minWinsForRebirth and RebirthRemote then
            pcall(function()
                if RebirthRemote:IsA("findRemote") then RebirthRemote:FireServer()
                elseif RebirthRemote:IsA("findRemote") then RebirthRemote:InvokeServer()
                end
            end)
            if getgenv().KR_CFG.legitMode then task.wait(math.random(12,20)/10) end
        end
    end
end)

-- ==== AUTO HATCH (opsional) ====
local HatchRemote = findRemote("Hatch") or findRemote("Egg")
task.spawn(function()
    while task.wait(1.2) do
        if not (getgenv().KR_CFG.autoHatch and HatchRemote) then continue end
        pcall(function()
            if HatchRemote:IsA("findRemote") then
                HatchRemote:FireServer(getgenv().KR_CFG.eggName, 1)
            elseif HatchRemote:IsA("findRemote") then
                HatchRemote:InvokeServer(getgenv().KR_CFG.eggName, 1)
            end
        end)
    end
end)

-- ==== SERVER HOP ====
local PLACE_ID = game.PlaceId
local function hopIfCrowded()
    if not getgenv().KR_CFG.serverHop then return end
    local count = #Players:GetPlayers()
    if count > getgenv().KR_CFG.maxPlayers then
        local success, err = pcall(function()
            TeleportService:Teleport(PLACE_ID)
        end)
        if not success then warn("ServerHop gagal:", err) end
    end
end
task.spawn(function()
    while task.wait(15) do hopIfCrowded() end
end)

-- ==== UI ====
local Window = OrionLib:MakeWindow({Name = "Kayak Racing – Farming Hub", HidePremium = true, SaveConfig = true, ConfigFolder = "KR_FarmHub"})
local tMain = Window:MakeTab({Name = "Main", Icon = "rbxassetid://4483345998", PremiumOnly = false})

tMain:AddToggle({Name="Auto Win", Default=false, Callback=function(v) getgenv().KR_CFG.autoWin=v end})
tMain:AddToggle({Name="Legit Mode (acak)", Default=true, Callback=function(v) getgenv().KR_CFG.legitMode=v end})
tMain:AddSlider({Name="Tween Speed", Min=80, Max=500, Default=getgenv().KR_CFG.tweenSpeed, Increment=5, Callback=function(v) getgenv().KR_CFG.tweenSpeed=v end})

tMain:AddToggle({Name="Auto Train", Default=false, Callback=function(v) getgenv().KR_CFG.autoTrain=v end})
tMain:AddSlider({Name="Radius Train", Min=30, Max=350, Default=getgenv().KR_CFG.trainRadius, Callback=function(v) getgenv().KR_CFG.trainRadius=v end})

tMain:AddToggle({Name="Auto Rebirth", Default=false, Callback=function(v) getgenv().KR_CFG.autoRebirth=v end})
tMain:AddTextbox({Name="Min Wins Rebirth", Default=tostring(getgenv().KR_CFG.minWinsForRebirth), TextDisappear=false, Callback=function(txt)
    local n = tonumber(txt); if n then getgenv().KR_CFG.minWinsForRebirth = n end
end})

local tEgg = Window:MakeTab({Name = "Eggs", Icon = "rbxassetid://4483345998"})
tEgg:AddToggle({Name="Auto Hatch", Default=false, Callback=function(v) getgenv().KR_CFG.autoHatch=v end})
tEgg:AddTextbox({Name="Egg Name", Default=getgenv().KR_CFG.eggName, TextDisappear=false, Callback=function(txt) getgenv().KR_CFG.eggName = txt end})

local tSys = Window:MakeTab({Name="System", Icon="rbxassetid://4483345998"})
tSys:AddToggle({Name="FPS Boost", Default=getgenv().KR_CFG.fpsBoost, Callback=function(v) getgenv().KR_CFG.fpsBoost=v; applyFPSBoost(v) end})
tSys:AddToggle({Name="Server Hop otomatis", Default=false, Callback=function(v) getgenv().KR_CFG.serverHop=v end})
tSys:AddTextbox({Name="Max Players sebelum hop", Default=tostring(getgenv().KR_CFG.maxPlayers), TextDisappear=false, Callback=function(txt)
    local n = tonumber(txt); if n then getgenv().KR_CFG.maxPlayers = n end
end})

OrionLib:Init()
