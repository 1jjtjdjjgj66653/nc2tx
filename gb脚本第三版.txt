local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
	Title = "静默甩飞",
	Footer = "nex制作 群1079540447",
	Icon = 95816097006870,
	NotifySide = "Right",
	ShowCustomCursor = true,
	AutoShow = true,
})

local Tabs = {
	Main = Window:AddTab("主页", "user"),
	Kill = Window:AddTab("杀戮", "sword"),
	ESP = Window:AddTab("ESP", "eye"),
}

-- ================= 静默甩飞核心代码 =================
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")

local flyConnections = {}
local FlyForce = 5000
local originalCollisions = {}

local function SafeGetCharacter(player)
    if not player then return nil end
    local char = player.Character
    if not char or not char.Parent then return nil end
    return char
end

local function SafeGetHumanoid(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function SafeGetHRP(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function DisableCollisions()
    originalCollisions = {}
    for _, player in pairs(Players:GetPlayers()) do
        local char = SafeGetCharacter(player)
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    originalCollisions[part] = part.CanCollide
                    pcall(function() part.CanCollide = false end)
                end
            end
        end
    end
end

local function RestoreCollisions()
    for part, originalValue in pairs(originalCollisions) do
        if part and part.Parent then
            pcall(function() part.CanCollide = originalValue end)
        end
    end
    originalCollisions = {}
end

local function ToggleSilentFly(state)
    for _, conn in pairs(flyConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    flyConnections = {}
    
    if state then
        DisableCollisions()
        
        local stepConn = RunService.Stepped:Connect(function()
            local char = SafeGetCharacter(Player)
            local hum = SafeGetHumanoid(char)
            local hrp = SafeGetHRP(char)
            if hum and hrp then
                pcall(function()
                    hum.PlatformStand = false
                    hum.Sit = false
                    hum.AutoRotate = true
                    local humanoidState = hum:GetState()
                    if humanoidState == Enum.HumanoidStateType.Physics or humanoidState == Enum.HumanoidStateType.FallingDown or humanoidState == Enum.HumanoidStateType.Ragdoll then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                end)
            end
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= Player then
                    local otherChar = SafeGetCharacter(otherPlayer)
                    if otherChar then
                        for _, part in pairs(otherChar:GetDescendants()) do
                            if part:IsA("BasePart") then
                                pcall(function() part.CanCollide = false end)
                            end
                        end
                    end
                end
            end
        end)
        table.insert(flyConnections, stepConn)
        
        local heartbeatConn = RunService.Heartbeat:Connect(function()
            local char = SafeGetCharacter(Player)
            local hrp = SafeGetHRP(char)
            local hum = SafeGetHumanoid(char)
            if hum and hrp then
                pcall(function()
                    local currentVel = hrp.AssemblyLinearVelocity
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    local safeY = currentVel.Y
                    if safeY > 40 then safeY = 40 end
                    if safeY < -40 then safeY = -40 end
                    
                    hrp.AssemblyAngularVelocity = Vector3.new(FlyForce, FlyForce, FlyForce)
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        currentVel.X * 1.1,
                        safeY,
                        currentVel.Z * 1.1
                    )
                    RunService.RenderStepped:Wait()
                    if hrp and hrp.Parent then
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end)
            end
        end)
        table.insert(flyConnections, heartbeatConn)
    else
        RestoreCollisions()
    end
end

-- ==================== 速度修改 ====================
local lp = Player
local speedEnabled = false
local speedValue = 16
local speedConnection = nil

local function SetSpeed(value)
    pcall(function()
        local char = lp.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = value
                hum.JumpPower = value * 3
            end
        end
    end)
end

local function ToggleSpeed(state)
    speedEnabled = state
    
    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end
    
    if state then
        speedConnection = RunService.RenderStepped:Connect(function()
            SetSpeed(speedValue)
        end)
    else
        SetSpeed(16)
    end
end

Player.CharacterAdded:Connect(function()
    task.wait(0.5)
    if speedEnabled then
        SetSpeed(speedValue)
    end
end)

-- ==================== 攻击动画播放 ====================
local MeleeAnimation = {
    "12591947127",
    "12591940500", 
    "12591938344",
    "12591948314",  
    "13728297869",
    "13728286238",
    "13728291683",
    "18341213062",
    "17406596097",
    "17406564344",
    "17406571129",
    "17406577733",
    "14284643711",
    "14284634554"
}

local animPlaying = false
local animConnection = nil
local currentTrack = nil

local function PlayAttackAnimation(animationId)
    local char = lp.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local animator = hum:FindFirstChild("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. animationId
    animation.Parent = animator
    
    local track = animator:LoadAnimation(animation)
    track:Play()
    currentTrack = track
    
    track.Stopped:Connect(function()
        if currentTrack == track then
            currentTrack = nil
        end
    end)
    
    return track
end

local function ToggleAttackAnim(state)
    animPlaying = state
    
    if currentTrack then
        currentTrack:Stop()
        currentTrack = nil
    end
    
    if animConnection then
        animConnection:Disconnect()
        animConnection = nil
    end
    
    if state then
        animConnection = RunService.RenderStepped:Connect(function()
            local char = lp.Character
            if not char then return end
            
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            
            local animator = hum:FindFirstChild("Animator")
            if not animator then
                animator = Instance.new("Animator")
                animator.Parent = hum
            end
            
            local isPlaying = false
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local animId = tostring(track.Animation.AnimationId)
                for _, attackId in ipairs(MeleeAnimation) do
                    if animId:find(attackId) then
                        isPlaying = true
                        break
                    end
                end
                if isPlaying then break end
            end
            
            if not isPlaying then
                local randomAnim = MeleeAnimation[math.random(1, #MeleeAnimation)]
                PlayAttackAnimation(randomAnim)
            end
        end)
    end
end

-- ==================== BGK 普通杀戮 ====================
local running = false
local lastZombieScan = 0
local cachedZombies = {}
local explosiveCache = {}
local headshotEnabled = false

local config = {
    meleePVEEnabled = false,
    barrelDistance = 15,
    heightCheck = false,
    attackDistance = 30,
    attackQuantity = 3,
    attackInterval = 0.15,
    autoTurn = true,
    noBarrel = false,
}

function getCachedZombies()
    local now = tick()
    if now - lastZombieScan < 1.5 then return cachedZombies end
    lastZombieScan = now
    cachedZombies = {}
    local addedZombies = {}
    local function s(p, d)
        if d > 5 then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("Model") and (c.Name == "m_Zombie" or c.Name == "Agent") then
                if not addedZombies[c] then
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        addedZombies[c] = true
                        cachedZombies[#cachedZombies + 1] = c
                    end
                end
            elseif not c:IsA("BasePart") then
                s(c, d + 1)
            end
        end
    end
    s(Workspace, 0)
    return cachedZombies
end

function findExplosivePart(z)
    if not z then return nil end
    if explosiveCache[z] ~= nil then return explosiveCache[z] end
    if z.Name ~= "m_Zombie" then
        explosiveCache[z] = nil
        return nil
    end
    for _, c in ipairs(z:GetDescendants()) do
        if c:IsA("BasePart") then
            local n = string.lower(c.Name)
            if n == "barrel" or n == "bomb" or n == "explosive" or n == "grenade" or n == "tnt" or n == "powderkeg" then
                explosiveCache[z] = c
                return c
            end
        end
    end
    explosiveCache[z] = nil
    return nil
end

function isBarrelZombie(z)
    if z:GetAttribute("Type") == "Barrel" then return true end
    if z:GetAttribute("Type") == "Explosive" then return true end
    if findExplosivePart(z) then return true end
    return false
end

function getMeleeWeapon()
    local char = lp.Character
    if not char then return nil, nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool:FindFirstChild("RemoteEvent") then return tool, tool.Name end
    return nil, nil
end

function meleeAttackZombie(zombie, weapon, myPos)
    local remote = weapon:FindFirstChild("RemoteEvent")
    if not remote then return end
    
    local targetPart = zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("Torso") or zombie:FindFirstChild("HumanoidRootPart")
    
    -- 刀刀爆头：直接瞄准头部
    if headshotEnabled then
        local head = zombie:FindFirstChild("Head") or zombie:FindFirstChild("head")
        if head then
            targetPart = head
        end
    end
    
    if not targetPart then return end
    
    local hitPos = targetPart.Position
    local attackDir = (hitPos - myPos).Unit
    pcall(function() remote:FireServer("Swing", "Side") end)
    for i = 1, 2 do
        local offset = Vector3.new((math.random() - 0.5) * 0.5, 0, (math.random() - 0.5) * 0.5)
        pcall(function() remote:FireServer("HitZombieM", zombie, hitPos + offset, false, Vector3.new(0, -1, 0), targetPart.Name, attackDir) end)
    end
end

function loop()
    while running do
        task.wait(config.attackInterval)
        local char = lp.Character
        if char then
            local myRoot = char:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local myPos = myRoot.Position
                
                if config.meleePVEEnabled then
                    local weapon = getMeleeWeapon()
                    if weapon then
                        local zombies = getCachedZombies()
                        local attacked = 0
                        for i = 1, #zombies do
                            if attacked >= config.attackQuantity then
                                break
                            end
                            local z = zombies[i]
                            if z and z.Parent then
                                local shouldSkip = false
                                if config.noBarrel then
                                    if isBarrelZombie(z) then
                                        shouldSkip = true
                                    end
                                end
                                
                                if not shouldSkip then
                                    local hum = z:FindFirstChildOfClass("Humanoid")
                                    if hum and hum.Health > 0 then
                                        local zr = z:FindFirstChild("HumanoidRootPart")
                                        if zr and (zr.Position - myPos).Magnitude <= config.attackDistance then
                                            if config.autoTurn then
                                                local ld = Vector3.new(zr.Position.X - myPos.X, 0, zr.Position.Z - myPos.Z)
                                                if ld.Magnitude > 0.01 then
                                                    pcall(function() myRoot.CFrame = CFrame.new(myPos, myPos + ld.Unit) end)
                                                end
                                            end
                                            meleeAttackZombie(z, weapon, myPos)
                                            attacked = attacked + 1
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function ToggleMeleePVE(state)
    config.meleePVEEnabled = state
    if state and not running then
        running = true
        task.spawn(loop)
    elseif not state then
        running = false
    end
end

local function ToggleHeadshot(state)
    headshotEnabled = state
end

-- ==================== BGK 普通黑枪 ====================
local cachedZombiesBG, lastZombieScanBG = {}, 0
local blackGunRunning = false

function getZombiesBG()
    local now = tick()
    if now - lastZombieScanBG > 3 then
        cachedZombiesBG = {}
        local char = lp.Character
        if not char then return cachedZombiesBG end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return cachedZombiesBG end
        local myPos = hrp.Position
        local function s(p, d)
            if d > 4 then return end
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("Model") and c.Name == "m_Zombie" then
                    local zhrp = c:FindFirstChild("HumanoidRootPart")
                    if zhrp and (zhrp.Position - myPos).Magnitude <= 300 then
                        table.insert(cachedZombiesBG, c)
                    end
                elseif not c:IsA("BasePart") then
                    s(c, d + 1)
                end
            end
        end
        s(Workspace, 0)
        lastZombieScanBG = now
    end
    return cachedZombiesBG
end

function getNearbyPlayers(z, range)
    local zr = z:FindFirstChild("HumanoidRootPart")
    if not zr then return {} end
    local nb = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local hr = p.Character:FindFirstChild("HumanoidRootPart")
            if hr then
                local d = (hr.Position - zr.Position).Magnitude
                if d <= range then
                    if config.heightCheck then
                        if math.abs(hr.Position.Y - zr.Position.Y) < 5 then
                            nb[#nb + 1] = {name = p.Name, dist = d, player = p, hrp = hr}
                        end
                    else
                        nb[#nb + 1] = {name = p.Name, dist = d, player = p, hrp = hr}
                    end
                end
            end
        end
    end
    return nb
end

function getBestTarget(zs, origin)
    local bz, bp, bn = nil, nil, {}
    local bs = 9999
    for _, z in ipairs(zs) do
        if z.Parent then
            local explosivePart = findExplosivePart(z)
            if explosivePart then
                local nb = getNearbyPlayers(z, config.barrelDistance + 2)
                if #nb > 0 then
                    local cp = explosivePart.Position
                    local myDist = (origin - cp).Magnitude
                    if myDist < bs then
                        bs = myDist
                        bz = z
                        bp = explosivePart
                        bn = nb
                    end
                end
            end
        end
    end
    return bz, bp, bn
end

function getRemote(tool)
    if not tool then return nil end
    local remote = tool:FindFirstChild("RemoteEvent")
    if remote then return remote end
    for _, child in ipairs(tool:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            return child
        end
    end
    return nil
end

function getGun()
    local char = lp.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and getRemote(tool) then return tool end
    return nil
end

function fireBG(tool, tp, nb)
    local remote = getRemote(tool)
    if not remote then return false end
    local char = lp.Character
    if not char then return false end
    remote:FireServer("Fire", char:FindFirstChild("Model") or char, tp, Workspace:GetServerTimeNow())
    return true
end

function blackGunLoop()
    while blackGunRunning do
        task.wait(0.1)
        local char = lp.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local tool = getGun()
                if tool then
                    local zombies = getZombiesBG()
                    local bz, bp, bn = getBestTarget(zombies, hrp.Position)
                    
                    if bz and bp then
                        fireBG(tool, bp.Position, bn)
                    end
                end
            end
        end
    end
end

local function ToggleBlackGun(state)
    blackGunRunning = state
    if state then
        task.spawn(blackGunLoop)
    end
end

-- ==================== 僵尸 ESP ====================
local espEnabled = false
local espBoxes = {}
local espConnections = {}
local espFolder = Instance.new("Folder")
espFolder.Name = "ZombieESP"
espFolder.Parent = game.CoreGui

local function getZombieType(z)
    if isBarrelZombie(z) then
        return "自爆僵尸"
    end
    
    local n = string.lower(z.Name)
    if n:find("agent") then
        return "特感"
    end
    
    return "普通僵尸"
end

local function getZombieColor(zombieType)
    if zombieType == "自爆僵尸" then
        return Color3.new(1, 0.5, 0)
    elseif zombieType == "特感" then
        return Color3.new(1, 0, 1)
    else
        return Color3.new(1, 0, 0)
    end
end

local function createGlowPart(targetPart, color, size)
    local glow = Instance.new("Part")
    glow.Name = "ESP_Glow"
    glow.Parent = espFolder
    glow.Anchored = true
    glow.CanCollide = false
    glow.CanQuery = false
    glow.CanTouch = false
    glow.Massless = true
    glow.Size = size
    glow.CFrame = targetPart.CFrame
    glow.Material = Enum.Material.Neon
    glow.Color = color
    glow.Transparency = 0.3

