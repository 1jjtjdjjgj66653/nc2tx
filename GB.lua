local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local P = game:GetService("Players")
local R = game:GetService("RunService")
local U = game:GetService("UserInputService")
local W = game:GetService("Workspace")
local L = P.LocalPlayer
local lp = L

local C = W.CurrentCamera or W:FindFirstChildWhichIsA("Camera")
W:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    C = W.CurrentCamera or W:FindFirstChildWhichIsA("Camera")
end)

-- ================= 基础变量 =================
local flyConnections = {}
local FlyForce = 5000
local originalCollisions = {}
local speedEnabled = false
local speedValue = 16
local speedConnection = nil
local running = false
local lastZombieScan = 0
local cachedZombies = {}
local explosiveCache = {}
local headshotEnabled = false
local espEnabled = false
local espBoxes = {}
local espConnections = {}
local espFolder = Instance.new("Folder")
espFolder.Name = "ZombieESP"
espFolder.Parent = game.CoreGui
local brightnessEnabled = false
local brightnessValue = 2
local animTracks = {}

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

-- ================= Drawing 函数 =================
local function nd(t)
    local o, p = pcall(function()
        return Drawing.new(t)
    end)
    return o and p or nil
end

-- ================= 自瞄配置 =================
local CP = {
    ["白色"] = Color3.fromRGB(255, 255, 255),
    ["红色"] = Color3.fromRGB(255, 60, 60),
    ["绿色"] = Color3.fromRGB(60, 255, 100),
    ["蓝色"] = Color3.fromRGB(60, 150, 255),
    ["黄色"] = Color3.fromRGB(255, 230, 0),
    ["紫色"] = Color3.fromRGB(180, 60, 255),
    ["青色"] = Color3.fromRGB(0, 255, 230),
    ["粉色"] = Color3.fromRGB(255, 100, 200),
    ["橙色"] = Color3.fromRGB(255, 150, 0),
    ["灰色"] = Color3.fromRGB(150, 150, 150)
}

local K = {
    Aim = {En = false, FOV = 150, Dist = 500, TP = "Head", WC = false, TC = true, Tgt = "Player", FF = true, FY = 200, Sm = false, Sp = 0.15, Pd = false, PS = 0.2},
    FC = {En = false, Cl = Color3.fromRGB(255, 255, 255), Tr = 50, Fl = false, Th = 1},
    ESP = {En = false, Bx = true, HB = true, Nm = true, Ds = true, Tr = false, Sk = false, VC = false, TC = true, MD = 1000, Cl = Color3.fromRGB(60, 255, 100), TCe = false, EVC = Color3.fromRGB(255, 60, 60), ENC = Color3.fromRGB(150, 150, 150), MVC = Color3.fromRGB(60, 150, 255), MNC = Color3.fromRGB(150, 150, 150), NPC = false, NC = Color3.fromRGB(255, 150, 0)}
}

-- ================= 自瞄函数 =================
local Bn = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}

local B6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local function isAlive(c)
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

local function getRoot(c)
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("LowerTorso")
end

local function getHead(c)
    return c and c:FindFirstChild("Head")
end

local function getChest(c)
    if not c then return nil end
    return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
end

local function isTeammateAim(p)
    if not K.Aim.TC then return false end
    if not L.Team or not p.Team then return false end
    return p.Team == L.Team
end

local function isTeammateESP(p)
    if not K.ESP.TC then return false end
    if not L.Team or not p.Team then return false end
    return p.Team == L.Team
end

local function isVisible(t, c)
    if not t then return false end
    local o = C.CFrame.Position
    local d = t.Position - o
    local r = RaycastParams.new()
    r.FilterDescendantsInstances = {L.Character, c}
    r.FilterType = Enum.RaycastFilterType.Exclude
    r.RespectCanCollide = true
    local h = W:Raycast(o, d, r)
    return not h or h.Instance:IsDescendantOf(c)
end

local function getAimPoint()
    if K.Aim.FF then
        local v = C.ViewportSize
        return Vector2.new(v.X / 2, K.Aim.FY)
    else
        return U:GetMouseLocation()
    end
end

local npcCache = {}
local npcTimer = 0

local function refreshNpcs()
    npcCache = {}
    for _, m in ipairs(W:GetDescendants()) do
        if m:IsA("Model") and not P:GetPlayerFromCharacter(m) then
            local h = m:FindFirstChildOfClass("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
            if h and r and h.Health > 0 then
                npcCache[m] = true
            end
        end
    end
end

local velCache = {}
local velTimer = 0

local function refreshVel()
    for _, p in ipairs(P:GetPlayers()) do
        if p ~= L and p.Character then
            local r = getRoot(p.Character)
            if r then
                if velCache[p] then
                    local dt = tick() - velCache[p].t
                    if dt > 0 then velCache[p].vel = (r.Position - velCache[p].pos) / dt end
                    velCache[p].pos = r.Position
                    velCache[p].t = tick()
                else
                    velCache[p] = {pos = r.Position, vel = Vector3.zero, t = tick()}
                end
            end
        end
    end
    for m in pairs(npcCache) do
        local r = getRoot(m)
        if r then
            if velCache[m] then
                local dt = tick() - velCache[m].t
                if dt > 0 then velCache[m].vel = (r.Position - velCache[m].pos) / dt end
                velCache[m].pos = r.Position
                velCache[m].t = tick()
            else
                velCache[m] = {pos = r.Position, vel = Vector3.zero, t = tick()}
            end
        end
    end
end

local function getTarget()
    local cp, cd, cv = nil, math.huge, Vector3.zero
    local a = getAimPoint()
    local co = C.CFrame.Position

    if K.Aim.Tgt == "Player" or K.Aim.Tgt == "Both" then
        for _, p in ipairs(P:GetPlayers()) do
            if p ~= L and isAlive(p.Character) and not isTeammateAim(p) then
                local c = p.Character
                local r = getRoot(c)
                local h = getHead(c)
                if r and h then
                    local d3 = (r.Position - co).Magnitude
                    if d3 <= K.Aim.Dist then
                        local ck = r
                        if K.Aim.TP == "Head" then ck = h elseif K.Aim.TP == "Chest" then ck = getChest(c) or r end
                        local sp, os2 = C:WorldToViewportPoint(ck.Position)
                        if os2 then
                            local sd = (Vector2.new(sp.X, sp.Y) - a).Magnitude
                            if sd <= K.Aim.FOV and sd < cd then
                                local canSee = not K.Aim.WC or isVisible(ck, c)
                                if canSee then
                                    cp = ck cd = sd cv = (velCache[p] and velCache[p].vel) or Vector3.zero
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if K.Aim.Tgt == "NPC" or K.Aim.Tgt == "Both" then
        for m in pairs(npcCache) do
            if m.Parent and isAlive(m) then
                local r = getRoot(m)
                local h = getHead(m)
                if r and h then
                    local d3 = (r.Position - co).Magnitude
                    if d3 <= K.Aim.Dist then
                        local ck = r
                        if K.Aim.TP == "Head" then ck = h elseif K.Aim.TP == "Chest" then ck = getChest(m) or r end
                        local sp, os2 = C:WorldToViewportPoint(ck.Position)
                        if os2 then
                            local sd = (Vector2.new(sp.X, sp.Y) - a).Magnitude
                            if sd <= K.Aim.FOV and sd < cd then
                                local canSee = not K.Aim.WC or isVisible(ck, m)
                                if canSee then
                                    cp = ck cd = sd cv = (velCache[m] and velCache[m].vel) or Vector3.zero
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return cp, cv
end

-- ================= FOV圈 =================
local FG = Instance.new("ScreenGui")
FG.Name = "FOVGui"
FG.IgnoreGuiInset = true
FG.ResetOnSpawn = false
FG.Parent = L:WaitForChild("PlayerGui")

local FF = Instance.new("Frame", FG)
FF.AnchorPoint = Vector2.new(0.5, 0.5)
FF.Position = UDim2.new(0.5, 0, 0, K.Aim.FY)
FF.Size = UDim2.fromOffset(K.Aim.FOV * 2, K.Aim.FOV * 2)
FF.BackgroundTransparency = 1
FF.Visible = false
Instance.new("UICorner", FF).CornerRadius = UDim.new(1, 0)

local FS = Instance.new("UIStroke", FF)
FS.Thickness = 1
FS.Color = K.FC.Cl
FS.Transparency = K.FC.Tr / 100

-- ================= 玩家ESP =================
local vCache = {}
local vTimer = 0

local function refreshVis()
    local cnt = 0
    for _, p in ipairs(P:GetPlayers()) do
        if p ~= L and p.Character then
            cnt = cnt + 1
            if cnt > 20 then
                vCache[p] = false
            else
                local char = p.Character
                local o = C.CFrame.Position
                local pts = {"Head", "UpperTorso", "Torso", "HumanoidRootPart"}
                local rp2 = RaycastParams.new()
                rp2.FilterType = Enum.RaycastFilterType.Exclude
                rp2.FilterDescendantsInstances = {L.Character, char}
                local v = false
                for _, pn in ipairs(pts) do
                    local pt = char:FindFirstChild(pn)
                    if pt then
                        local d = pt.Position - o
                        local h = W:Raycast(o, d, rp2)
                        if not h or (h.Position - pt.Position).Magnitude < 5 then
                            v = true break
                        end
                    end
                end
                vCache[p] = v
            end
        end
    end
end

local EO = {}

local function ce()
    local e = {}
    e.BO = {nd("Line"), nd("Line"), nd("Line"), nd("Line")}
    for _, l in ipairs(e.BO) do if l then l.Thickness = 3 l.Color = Color3.fromRGB(0, 0, 0) l.Visible = false end end
    e.B = {nd("Line"), nd("Line"), nd("Line"), nd("Line")}
    for _, l in ipairs(e.B) do if l then l.Thickness = 1 l.Visible = false end end
    e.HO = nd("Line") if e.HO then e.HO.Thickness = 4 e.HO.Color = Color3.fromRGB(0, 0, 0) e.HO.Visible = false end
    e.HB = nd("Line") if e.HB then e.HB.Thickness = 2 e.HB.Visible = false end
    e.N = nd("Text") if e.N then e.N.Size = 14 e.N.Center = true e.N.Outline = true e.N.Color = Color3.fromRGB(255, 255, 255) e.N.Visible = false end
    e.D = nd("Text") if e.D then e.D.Size = 13 e.D.Center = true e.D.Outline = true e.D.Color = Color3.fromRGB(200, 200, 200) e.D.Visible = false end
    e.T = nd("Line") if e.T then e.T.Thickness = 1 e.T.Visible = false end
    e.S = {}
    for i = 1, 14 do e.S[i] = nd("Line") if e.S[i] then e.S[i].Thickness = 1 e.S[i].Visible = false end end
    return e
end

local function re(e)
    if not e then return end
    for _, l in ipairs(e.BO) do pcall(function() l:Remove() end) end
    for _, l in ipairs(e.B) do pcall(function() l:Remove() end) end
    for _, l in ipairs(e.S) do pcall(function() l:Remove() end) end
    for _, o in pairs({e.HO, e.HB, e.N, e.D, e.T}) do pcall(function() o:Remove() end) end
end

local function he(e)
    if not e then return end
    for _, l in ipairs(e.BO) do l.Visible = false end
    for _, l in ipairs(e.B) do l.Visible = false end
    for _, l in ipairs(e.S) do l.Visible = false end
    for _, o in pairs({e.HO, e.HB, e.N, e.D, e.T}) do o.Visible = false end
end

for _, p in ipairs(P:GetPlayers()) do if p ~= L then EO[p] = ce() end end
P.PlayerAdded:Connect(function(p) if p ~= L then EO[p] = ce() end end)
P.PlayerRemoving:Connect(function(p) if EO[p] then re(EO[p]) EO[p] = nil end end)

local NPC_ESP = {}
local NPC_POOL = 30
for i = 1, NPC_POOL do NPC_ESP[i] = {obj = ce(), model = nil} end

-- ================= 自瞄+玩家ESP渲染 =================
R:BindToRenderStep("AimUniversal", Enum.RenderPriority.Camera.Value + 1, function()
    local sf = K.FC.En
    FF.Visible = sf
    FF.Size = UDim2.fromOffset(K.Aim.FOV * 2, K.Aim.FOV * 2)
    local fpos = K.Aim.FF and UDim2.new(0.5, 0, 0, K.Aim.FY) or UDim2.new(0.5, 0, 0.5, 0)
    FF.Position = fpos
    FF.BackgroundColor3 = K.FC.Cl
    FF.BackgroundTransparency = (K.FC.Fl and K.FC.Tr / 100) or 1
    FS.Color = K.FC.Cl
    FS.Thickness = K.FC.Th
    FS.Transparency = K.FC.Tr / 100

    if K.Aim.En then
        local tgt, vel = getTarget()
        if tgt then
            local camPos = C.CFrame.Position
            local aimPos = tgt.Position
            if K.Aim.Pd then aimPos = aimPos + vel * K.Aim.PS end
            if K.Aim.Sm and K.Aim.Sp < 1 then
                C.CFrame = C.CFrame:Lerp(CFrame.new(camPos, aimPos), K.Aim.Sp)
            else
                C.CFrame = CFrame.new(camPos, aimPos)
            end
        end
    end

    if not K.ESP.En then
        for _, e in pairs(EO) do he(e) end
        for i = 1, NPC_POOL do he(NPC_ESP[i].obj) end
        return
    end

    local vp = {}
    for _, p in ipairs(P:GetPlayers()) do vp[p] = true end
    for p, e in pairs(EO) do if not vp[p] then re(e) EO[p] = nil end end

    local now = tick()
    if now - vTimer > 0.15 then vTimer = now refreshVis() end
    if now - npcTimer > 2 then npcTimer = now refreshNpcs() end
    if now - velTimer > 0.05 then velTimer = now refreshVel() end

    local myChar = L.Character
    local myRoot = myChar and getRoot(myChar)

    local function ue(p, e)
        if p == L or not p.Parent then he(e) return end
        local c = p.Character
        if not c or not isAlive(c) then he(e) return end
        if K.ESP.TC and isTeammateESP(p) then he(e) return end
        local r = getRoot(c) local h = getHead(c) local hu = c:FindFirstChildOfClass("Humanoid")
        if not r or not h or not hu then he(e) return end
        local dist3D = myRoot and (r.Position - myRoot.Position).Magnitude or (r.Position - C.CFrame.Position).Magnitude
        if dist3D > K.ESP.MD then he(e) return end
        local headPos = h.Position
        local feetPos = r.Position - Vector3.new(0, 3, 0)
        local topPos = headPos + Vector3.new(0, 0.5, 0)
        local rs, ron = C:WorldToViewportPoint(r.Position)
        local hs = C:WorldToViewportPoint(topPos)
        local fs = C:WorldToViewportPoint(feetPos)
        if not ron or rs.Z <= 0 then he(e) return end

        local vis = vCache[p] or false
        local col = K.ESP.Cl
        local isEnemy = L.Team and p.Team and p.Team ~= L.Team
        if K.ESP.TCe then
            if isEnemy then col = vis and K.ESP.EVC or K.ESP.ENC
            else col = vis and K.ESP.MVC or K.ESP.MNC end
        elseif K.ESP.VC then
            col = vis and K.ESP.Cl or Color3.fromRGB(255, 60, 60)
        end

        local boxTop, boxBottom = hs.Y, fs.Y
        local boxH = math.abs(boxBottom - boxTop)
        local boxW = boxH * 0.6
        local cx = rs.X
        if K.ESP.Bx then
            e.B[1].From = Vector2.new(cx - boxW / 2, boxTop) e.B[1].To = Vector2.new(cx + boxW / 2, boxTop)
            e.B[2].From = Vector2.new(cx + boxW / 2, boxTop) e.B[2].To = Vector2.new(cx + boxW / 2, boxBottom)
            e.B[3].From = Vector2.new(cx + boxW / 2, boxBottom) e.B[3].To = Vector2.new(cx - boxW / 2, boxBottom)
            e.B[4].From = Vector2.new(cx - boxW / 2, boxBottom) e.B[4].To = Vector2.new(cx - boxW / 2, boxTop)
            e.BO[1].From = e.B[1].From e.BO[1].To = e.B[1].To
            e.BO[2].From = e.B[2].From e.BO[2].To = e.B[2].To
            e.BO[3].From = e.B[3].From e.BO[3].To = e.B[3].To
            e.BO[4].From = e.B[4].From e.BO[4].To = e.B[4].To
            for i = 1, 4 do e.B[i].Color = col e.B[i].Visible = true e.BO[i].Visible = true end
        else
            for i = 1, 4 do e.B[i].Visible = false e.BO[i].Visible = false end
        end

        if K.ESP.HB then
            local hp = math.clamp(hu.Health / hu.MaxHealth, 0, 1)
            local hH = boxH * hp
            e.HB.Visible = true e.HB.Color = Color3.fromHSV(hp / 2.5, 0.89, 0.75)
            e.HB.From = Vector2.new(cx - boxW / 2 - 6, boxBottom) e.HB.To = Vector2.new(cx - boxW / 2 - 6, boxBottom - hH)
            e.HO.Visible = true e.HO.From = Vector2.new(cx - boxW / 2 - 6, boxTop) e.HO.To = Vector2.new(cx - boxW / 2 - 6, boxBottom)
        else e.HB.Visible = false e.HO.Visible = false end

        if K.ESP.Nm then e.N.Visible = true e.N.Text = p.DisplayName e.N.Position = Vector2.new(cx, boxTop - 18) e.N.Color = col else e.N.Visible = false end
        if K.ESP.Ds then e.D.Visible = true e.D.Text = string.format("%.0f", dist3D) .. "m" e.D.Position = Vector2.new(cx, boxBottom + 2) else e.D.Visible = false end
        if K.ESP.Tr then
            local v = C.ViewportSize
            e.T.Visible = true e.T.From = Vector2.new(v.X / 2, v.Y) e.T.To = Vector2.new(cx, boxBottom) e.T.Color = col
        else e.T.Visible = false end
        if K.ESP.Sk then
            local bones = c:FindFirstChild("Torso") and B6 or Bn
            for i, b in ipairs(bones) do
                if e.S[i] then
                    local p1 = c:FindFirstChild(b[1]) local p2 = c:FindFirstChild(b[2])
                    if p1 and p2 then
                        local s1, o1 = C:WorldToViewportPoint(p1.Position)
                        local s2, o2 = C:WorldToViewportPoint(p2.Position)
                        if o1 and o2 and s1.Z > 0 and s2.Z > 0 then
                            e.S[i].From = Vector2.new(s1.X, s1.Y) e.S[i].To = Vector2.new(s2.X, s2.Y) e.S[i].Color = col e.S[i].Visible = true
                        else e.S[i].Visible = false end
                    else e.S[i].Visible = false end
                end
            end
            for i = #bones + 1, 14 do if e.S[i] then e.S[i].Visible = false end end
        else
            for i = 1, 14 do if e.S[i] then e.S[i].Visible = false end end
        end
    end

    for p, e in pairs(EO) do ue(p, e) end

    local npcIdx = 1
    if K.ESP.NPC then
        for m in pairs(npcCache) do
            if npcIdx > NPC_POOL then break end
            if m.Parent and isAlive(m) then
                local e = NPC_ESP[npcIdx].obj
                local r = getRoot(m) local h = getHead(m) local hu = m:FindFirstChildOfClass("Humanoid")
                if r and h and hu then
                    local dist3D = myRoot and (r.Position - myRoot.Position).Magnitude or (r.Position - C.CFrame.Position).Magnitude
                    if dist3D <= K.ESP.MD then
                        local headPos = h.Position
                        local feetPos = r.Position - Vector3.new(0, 3, 0)
                        local topPos = headPos + Vector3.new(0, 0.5, 0)
                        local rs, ron = C:WorldToViewportPoint(r.Position)
                        local hs = C:WorldToViewportPoint(topPos)
                        local fs = C:WorldToViewportPoint(feetPos)
                        if ron and rs.Z > 0 then
                            local col = K.ESP.NC
                            if K.ESP.VC then
                                local visNpc = isVisible(h, m)
                                col = visNpc and K.ESP.NC or Color3.fromRGB(255, 60, 60)
                            end
                            local boxTop, boxBottom = hs.Y, fs.Y
                            local boxH = math.abs(boxBottom - boxTop)
                            local boxW = boxH * 0.6
                            local cx = rs.X
                            if K.ESP.Bx then
                                e.B[1].From = Vector2.new(cx - boxW / 2, boxTop) e.B[1].To = Vector2.new(cx + boxW / 2, boxTop)
                                e.B[2].From = Vector2.new(cx + boxW / 2, boxTop) e.B[2].To = Vector2.new(cx + boxW / 2, boxBottom)
                                e.B[3].From = Vector2.new(cx + boxW / 2, boxBottom) e.B[3].To = Vector2.new(cx - boxW / 2, boxBottom)
                                e.B[4].From = Vector2.new(cx - boxW / 2, boxBottom) e.B[4].To = Vector2.new(cx - boxW / 2, boxTop)
                                e.BO[1].From = e.B[1].From e.BO[1].To = e.B[1].To
                                e.BO[2].From = e.B[2].From e.BO[2].To = e.B[2].To
                                e.BO[3].From = e.B[3].From e.BO[3].To = e.B[3].To
                                e.BO[4].From = e.B[4].From e.BO[4].To = e.B[4].To
                                for i = 1, 4 do e.B[i].Color = col e.B[i].Visible = true e.BO[i].Visible = true end
                            else
                                for i = 1, 4 do e.B[i].Visible = false e.BO[i].Visible = false end
                            end
                            if K.ESP.HB then
                                local hp = math.clamp(hu.Health / hu.MaxHealth, 0, 1)
                                local hH = boxH * hp
                                e.HB.Visible = true e.HB.Color = Color3.fromHSV(hp / 2.5, 0.89, 0.75)
                                e.HB.From = Vector2.new(cx - boxW / 2 - 6, boxBottom) e.HB.To = Vector2.new(cx - boxW / 2 - 6, boxBottom - hH)
                                e.HO.Visible = true e.HO.From = Vector2.new(cx - boxW / 2 - 6, boxTop) e.HO.To = Vector2.new(cx - boxW / 2 - 6, boxBottom)
                            else e.HB.Visible = false e.HO.Visible = false end
                            if K.ESP.Nm then e.N.Visible = true e.N.Text = m.Name e.N.Position = Vector2.new(cx, boxTop - 18) e.N.Color = col else e.N.Visible = false end
                            if K.ESP.Ds then e.D.Visible = true e.D.Text = string.format("%.0f", dist3D) .. "m" e.D.Position = Vector2.new(cx, boxBottom + 2) else e.D.Visible = false end
                            if K.ESP.Tr then
                                local v = C.ViewportSize
                                e.T.Visible = true e.T.From = Vector2.new(v.X / 2, v.Y) e.T.To = Vector2.new(cx, boxBottom) e.T.Color = col
                            else e.T.Visible = false end
                            npcIdx = npcIdx + 1
                        else he(e) end
                    else he(e) end
                else he(e) end
            else he(e) end
        end
    end
    for i = npcIdx, NPC_POOL do he(NPC_ESP[i].obj) end
end)

refreshNpcs()

-- ================= 甩飞函数 =================
local function SafeGetCharacter(player)
    if not player then return nil end
    local char = player.Character
    if not char or not char.Parent then return nil end
    return char
end

local function DisableCollisions()
    originalCollisions = {}
    for _, player in pairs(P:GetPlayers()) do
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
        if part and part.Parent then pcall(function() part.CanCollide = originalValue end) end
    end
    originalCollisions = {}
end

local function ToggleSilentFly(state)
    for _, conn in pairs(flyConnections) do if conn then pcall(function() conn:Disconnect() end) end end
    flyConnections = {}
    if state then
        DisableCollisions()
        local heartbeatConn = R.Heartbeat:Connect(function()
            local char = SafeGetCharacter(L)
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hrp then
                pcall(function()
                    local currentVel = hrp.AssemblyLinearVelocity
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    local safeY = currentVel.Y
                    if safeY > 40 then safeY = 40 end
                    if safeY < -40 then safeY = -40 end
                    hrp.AssemblyAngularVelocity = Vector3.new(FlyForce, FlyForce, FlyForce)
                    hrp.AssemblyLinearVelocity = Vector3.new(currentVel.X * 1.1, safeY, currentVel.Z * 1.1)
                    R.RenderStepped:Wait()
                    if hrp and hrp.Parent then hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end
                end)
            end
            for _, otherPlayer in pairs(P:GetPlayers()) do
                if otherPlayer ~= L then
                    local otherChar = SafeGetCharacter(otherPlayer)
                    if otherChar then
                        for _, part in pairs(otherChar:GetDescendants()) do
                            if part:IsA("BasePart") then pcall(function() part.CanCollide = false end) end
                        end
                    end
                end
            end
        end)
        table.insert(flyConnections, heartbeatConn)
    else
        RestoreCollisions()
    end
end

-- ================= 速度 =================
local function SetSpeed(value)
    pcall(function()
        local char = L.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = value hum.JumpPower = value * 3 end
        end
    end)
end

local function ToggleSpeed(state)
    speedEnabled = state
    if speedConnection then speedConnection:Disconnect() speedConnection = nil end
    if state then
        speedConnection = R.RenderStepped:Connect(function() SetSpeed(speedValue) end)
    else
        SetSpeed(16)
    end
end

L.CharacterAdded:Connect(function() task.wait(0.5) if speedEnabled then SetSpeed(speedValue) end end)

-- ================= 杀戮 =================
function getCachedZombies()
    local now = tick()
    if now - lastZombieScan < 1.5 then return cachedZombies end
    lastZombieScan = now
    cachedZombies = {}
    local addedZombies = {}
    local function s(p, d)
        if d > 5 then return end
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("Model") then
                local hum = c:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and not addedZombies[c] then
                    local isPlayerChar = false
                    for _, plr in ipairs(P:GetPlayers()) do if plr.Character == c then isPlayerChar = true break end end
                    if not isPlayerChar then addedZombies[c] = true cachedZombies[#cachedZombies + 1] = c end
                end
            elseif not c:IsA("BasePart") then s(c, d + 1) end
        end
    end
    s(W, 0)
    return cachedZombies
end

function findExplosivePart(z)
    if not z then return nil end
    if explosiveCache[z] ~= nil then return explosiveCache[z] end
    if z.Name ~= "m_Zombie" then explosiveCache[z] = nil return nil end
    for _, c in ipairs(z:GetDescendants()) do
        if c:IsA("BasePart") then
            local n = string.lower(c.Name)
            if n == "barrel" or n == "bomb" or n == "explosive" or n == "grenade" or n == "tnt" or n == "powderkeg" then
                explosiveCache[z] = c return c
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
    local char = L.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool:FindFirstChild("RemoteEvent") then return tool end
    return nil
end

function meleeAttackZombie(zombie, weapon, myPos)
    local remote = weapon:FindFirstChild("RemoteEvent")
    if not remote then return end
    local targetPart = zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("Torso") or zombie:FindFirstChild("HumanoidRootPart")
    if headshotEnabled then
        local head = zombie:FindFirstChild("Head") or zombie:FindFirstChild("head")
        if head then targetPart = head end
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

function killLoop()
    while running do
        task.wait(config.attackInterval)
        local char = L.Character
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
                            if attacked >= config.attackQuantity then break end
                            local z = zombies[i]
                            if z and z.Parent then
                                local shouldSkip = false
                                if config.noBarrel and isBarrelZombie(z) then shouldSkip = true end
                                if not shouldSkip then
                                    local hum = z:FindFirstChildOfClass("Humanoid")
                                    if hum and hum.Health > 0 then
                                        local zr = z:FindFirstChild("HumanoidRootPart")
                                        if zr and (zr.Position - myPos).Magnitude <= config.attackDistance then
                                            if config.autoTurn then
                                                local ld = Vector3.new(zr.Position.X - myPos.X, 0, zr.Position.Z - myPos.Z)
                                                if ld.Magnitude > 0.01 then pcall(function() myRoot.CFrame = CFrame.new(myPos, myPos + ld.Unit) end) end
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
    if state and not running then running = true task.spawn(killLoop)
    elseif not state then running = false end
end

-- ================= 僵尸ESP =================
local function getZombieType(z)
    if isBarrelZombie(z) then return "自爆僵尸" end
    local n = string.lower(z.Name)
    if n:find("agent") then return "特感" end
    return "普通僵尸"
end

local function getZombieColor(zombieType)
    if zombieType == "自爆僵尸" then return Color3.new(1, 0.5, 0) end
    if zombieType == "特感" then return Color3.new(1, 0, 1) end
    return Color3.new(1, 0, 0)
end

local function createGlowPart(targetPart, color, size)
    local glow = Instance.new("Part")
    glow.Name = "ESP_Glow"
    glow.Parent = espFolder
    glow.Anchored = true glow.CanCollide = false glow.CanQuery = false glow.CanTouch = false glow.Massless = true
    glow.Size = size glow.CFrame = targetPart.CFrame glow.Material = Enum.Material.Neon glow.Color = color glow.Transparency = 0.3
    return glow
end

local function createESP(zombie)
    if espBoxes[zombie] then return end
    local hrp = zombie:FindFirstChild("HumanoidRootPart")
    local head = zombie:FindFirstChild("Head") or zombie:FindFirstChild("head")
    local hum = zombie:FindFirstChildOfClass("Humanoid")
    if not hrp or not head or not hum then return end
    local zombieType = getZombieType(zombie)
    local color = getZombieColor(zombieType)
    local glowParts = {}
    local headGlow = createGlowPart(head, color, Vector3.new(1.5, 1.5, 1.5)) table.insert(glowParts, headGlow)
    local bodyGlow = createGlowPart(hrp, color, Vector3.new(3, 3, 1.5)) table.insert(glowParts, bodyGlow)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Label" billboard.Parent = espFolder billboard.Adornee = zombie
    billboard.Size = UDim2.new(0, 100, 0, 25) billboard.StudsOffset = Vector3.new(0, 2.5, 0) billboard.AlwaysOnTop = true billboard.LightInfluence = 0
    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = billboard textLabel.Size = UDim2.new(1, 0, 1, 0) textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = color textLabel.TextSize = 14 textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Text = zombieType textLabel.TextStrokeTransparency = 0 textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    espBoxes[zombie] = {billboard = billboard, textLabel = textLabel, hum = hum, zombieType = zombieType, glowParts = glowParts}
    local updateConn = R.RenderStepped:Connect(function()
        if not zombie.Parent or not hum or hum.Health <= 0 then return end
        local currentHRP = zombie:FindFirstChild("HumanoidRootPart")
        local currentHead = zombie:FindFirstChild("Head") or zombie:FindFirstChild("head")
        if currentHRP and glowParts[2] and glowParts[2].Parent then glowParts[2].CFrame = currentHRP.CFrame end
        if currentHead and glowParts[1] and glowParts[1].Parent then glowParts[1].CFrame = currentHead.CFrame end
    end)
    local diedConn = hum.Died:Connect(function()
        if espBoxes[zombie] then
            local data = espBoxes[zombie]
            if data.billboard then data.billboard:Destroy() end
            for _, gp in ipairs(data.glowParts) do if gp and gp.Parent then gp:Destroy() end end
            if updateConn then updateConn:Disconnect() end
            espBoxes[zombie] = nil
        end
    end)
    table.insert(espConnections, updateConn) table.insert(espConnections, diedConn)
end

local function cleanupESP()
    for zombie, data in pairs(espBoxes) do
        if data.billboard then data.billboard:Destroy() end
        for _, gp in ipairs(data.glowParts) do if gp and gp.Parent then gp:Destroy() end end
    end
    espBoxes = {}
    for _, conn in pairs(espConnections) do if conn then pcall(function() conn:Disconnect() end) end end
    espConnections = {}
end

local function updateESP()
    task.spawn(function()
        while espEnabled do
            task.wait(0.5)
            local zombies = getCachedZombies()
            for _, z in ipairs(zombies) do if z and z.Parent then createESP(z) end end
            for zombie, data in pairs(espBoxes) do
                local hum = zombie:FindFirstChildOfClass("Humanoid")
                if not zombie.Parent or not hum or hum.Health <= 0 then
                    if data.billboard then data.billboard:Destroy() end
                    for _, gp in ipairs(data.glowParts) do if gp and gp.Parent then gp:Destroy() end end
                    espBoxes[zombie] = nil
                end
            end
        end
    end)
end

local function ToggleESP(state)
    espEnabled = state
    if state then updateESP() else cleanupESP() end
end

-- ================= 亮度 =================
local function SetBrightness(value)
    pcall(function()
        game:GetService("Lighting").Brightness = value
        game:GetService("Lighting").ClockTime = 14
        game:GetService("Lighting").Ambient = Color3.new(1, 1, 1)
        game:GetService("Lighting").OutdoorAmbient = Color3.new(1, 1, 1)
        game:GetService("Lighting").FogEnd = 10000
        game:GetService("Lighting").FogStart = 0
        game:GetService("Lighting").ExposureCompensation = value - 1
    end)
end

local function ToggleBrightness(state)
    brightnessEnabled = state
    if state then SetBrightness(brightnessValue) else SetBrightness(1) end
end

-- ================= 动画库 =================
local ZombieAnimations = {
    Normal = {
        {"待机 Idle", "rbxassetid://12333488814"},
        {"走路 Walk", "rbxassetid://14463697470"},
        {"攻击 Kill", "rbxassetid://12333489847"},
        {"挥砍 Slash", "rbxassetid://12333490032"},
        {"抓人 Grab", "rbxassetid://12333490554"},
        {"吃人 Eat", "rbxassetid://12333491636"},
        {"爬起 Getup", "rbxassetid://12333488405"},
        {"爪击1 Claw1", "rbxassetid://14206199247"},
        {"爪击2 Claw2", "rbxassetid://14206201358"},
        {"眩晕 Stunned", "rbxassetid://15468176618"},
        {"攀爬 Climb", "rbxassetid://17716544582"},
    },
    Barrel = {
        {"待机 Idle", "rbxassetid://135525775061296"},
        {"走路 Walk", "rbxassetid://71047314929823"},
        {"点燃引线 Fuse", "rbxassetid://109845688104360"},
    },
    Fast = {
        {"待机 Idle", "rbxassetid://12581784105"},
        {"跑步1 Run1", "rbxassetid://12581786940"},
        {"攻击 Attack", "rbxassetid://12333488138"},
        {"冲刺 Charge", "rbxassetid://12333488124"},
        {"扑倒 Tackle", "rbxassetid://12333489510"},
    },
    Crawler = {
        {"攻击 Attack", "rbxassetid://13726628401"},
        {"待机 Idle", "rbxassetid://13726632691"},
        {"爬行 Crawl", "rbxassetid://13726634549"},
    },
    Vampire = {
        {"待机 Idle", "rbxassetid://118640534277641"},
        {"走路 Walk", "rbxassetid://94092172040576"},
    },
    Boxer = {
        {"待机 Idle", "rbxassetid://124381258015151"},
        {"走路 Walk", "rbxassetid://127477273497271"},
        {"出拳1 Box1", "rbxassetid://137400696654354"},
        {"出拳2 Box2", "rbxassetid://100609705099226"},
    },
    Sleep = {
        {"躺1 Lay1", "rbxassetid://89846743695819"},
        {"躺2 Lay2", "rbxassetid://124520029071726"},
        {"躺3 Lay3", "rbxassetid://134734616918551"},
    },
}

local function PlayZombieAnimationById(animId)
    local char = L.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChild("Animator")
    if not animator then animator = Instance.new("Animator") animator.Parent = hum end
    local animation = Instance.new("Animation")
    animation.AnimationId = animId animation.Parent = animator
    local track = animator:LoadAnimation(animation)
    track:Play()
    return track
end

-- ================= 窗口 =================
local Window = Library:CreateWindow({
    Title = "多功能脚本",
    Footer = "脚本由大肉帮帮主制作",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
    AutoShow = true,
})

local Tabs = {
    Main = Window:AddTab("主页", "user"),
    Kill = Window:AddTab("杀戮", "sword"),
    ZombieESP = Window:AddTab("僵尸ESP", "eye"),
    Anim = Window:AddTab("动画", "play"),
    AimTab = Window:AddTab("自瞄", "crosshair"),
    EspTab = Window:AddTab("玩家ESP", "eye"),
}

-- ================= 主页UI =================
local MainGroup = Tabs.Main:AddLeftGroupbox("主页功能", "boxes")
MainGroup:AddSlider("FlyForce", {Text = "甩飞力度", Default = 5000, Min = 100, Max = 50000, Rounding = 0, Compact = false, Callback = function(v) FlyForce = v end})
MainGroup:AddButton({Text = "启动甩飞", Func = function() ToggleSilentFly(true) end})
MainGroup:AddButton({Text = "停止甩飞", Func = function() ToggleSilentFly(false) end})
MainGroup:AddToggle("SpeedBoost", {Text = "速度修改", Default = false, Callback = ToggleSpeed})
MainGroup:AddSlider("SpeedValue", {Text = "移动速度", Default = 16, Min = 16, Max = 50, Rounding = 0, Compact = false, Callback = function(v) speedValue = v if speedEnabled then SetSpeed(v) end end})
MainGroup:AddLabel("甩飞由nex制作(侵权即删) 群1079540447", true)

-- ================= 杀戮UI =================
local KillGroup = Tabs.Kill:AddLeftGroupbox("杀戮功能", "sword")
KillGroup:AddToggle("MeleePVE", {Text = "普通杀戮", Default = false, Callback = ToggleMeleePVE})
KillGroup:AddToggle("AutoTurn", {Text = "自动转向", Default = true, Callback = function(v) config.autoTurn = v end})
KillGroup:AddToggle("Headshot", {Text = "刀刀爆头", Default = false, Callback = function(v) headshotEnabled = v end})
KillGroup:AddToggle("NoBarrel", {Text = "攻击自爆", Default = true, Callback = function(v) config.noBarrel = not v end})
KillGroup:AddSlider("AttackDistance", {Text = "攻击距离", Default = 30, Min = 5, Max = 50, Rounding = 0, Compact = false, Callback = function(v) config.attackDistance = v end})
KillGroup:AddSlider("AttackQuantity", {Text = "攻击数量", Default = 3, Min = 1, Max = 10, Rounding = 0, Compact = false, Callback = function(v) config.attackQuantity = v end})
KillGroup:AddSlider("AttackInterval", {Text = "攻击间隔", Default = 0.15, Min = 0.05, Max = 1, Rounding = 2, Compact = false, Callback = function(v) config.attackInterval = v end})

-- ================= 僵尸ESP UI =================
local ZESPGroup = Tabs.ZombieESP:AddLeftGroupbox("僵尸ESP", "eye")
ZESPGroup:AddToggle("ZombieESP", {Text = "敌人ESP", Default = false, Callback = ToggleESP})
ZESPGroup:AddToggle("Brightness", {Text = "地图增亮", Default = false, Callback = ToggleBrightness})
ZESPGroup:AddSlider("BrightnessValue", {Text = "亮度数值", Default = 2, Min = 1, Max = 5, Rounding = 1, Compact = false, Callback = function(v) brightnessValue = v if brightnessEnabled then SetBrightness(v) end end})

-- ================= 动画UI =================
for categoryName, animations in pairs(ZombieAnimations) do
    local group = Tabs.Anim:AddLeftGroupbox(categoryName, "play")
    for _, anim in ipairs(animations) do
        local toggleName = "Anim_" .. categoryName .. "_" .. anim[1]
        group:AddToggle(toggleName, {
            Text = anim[1], Default = false,
            Callback = function(Value)
                if Value then
                    local track = PlayZombieAnimationById(anim[2])
                    if track then track.Looped = true animTracks[toggleName] = track end
                else
                    if animTracks[toggleName] then animTracks[toggleName]:Stop() animTracks[toggleName] = nil end
                end
            end,
        })
    end
end

-- ================= 自瞄UI =================
local AimBox = Tabs.AimTab:AddLeftGroupbox("自瞄设置", "crosshair")
AimBox:AddToggle("AimEnabled", {Text = "开启自瞄", Default = false, Callback = function(v) K.Aim.En = v end})
AimBox:AddDropdown("AimTarget", {Text = "目标类型", Default = "Player", Values = {"Player", "NPC", "Both"}, Callback = function(v) K.Aim.Tgt = v end})
AimBox:AddDropdown("AimPart", {Text = "瞄准部位", Default = "Head", Values = {"Head", "Chest"}, Callback = function(v) K.Aim.TP = v end})
AimBox:AddSlider("AimFOV", {Text = "FOV范围", Default = 150, Min = 50, Max = 1000, Rounding = 0, Callback = function(v) K.Aim.FOV = v end})
AimBox:AddSlider("AimDist", {Text = "最大距离", Default = 500, Min = 50, Max = 5000, Rounding = 0, Callback = function(v) K.Aim.Dist = v end})
AimBox:AddToggle("AimWall", {Text = "穿墙自瞄", Default = false, Callback = function(v) K.Aim.WC = v end})
AimBox:AddToggle("AimTeam", {Text = "队伍检测", Default = true, Callback = function(v) K.Aim.TC = v end})

local AimBox2 = Tabs.AimTab:AddRightGroupbox("自瞄辅助", "crosshair")
AimBox2:AddToggle("AimSmooth", {Text = "平滑自瞄", Default = false, Callback = function(v) K.Aim.Sm = v end})
AimBox2:AddSlider("AimSpeed", {Text = "平滑速度", Default = 15, Min = 1, Max = 100, Rounding = 0, Callback = function(v) K.Aim.Sp = v / 100 end})
AimBox2:AddToggle("AimPred", {Text = "预判自瞄", Default = false, Callback = function(v) K.Aim.Pd = v end})
AimBox2:AddSlider("AimPredStr", {Text = "预判强度", Default = 20, Min = 1, Max = 100, Rounding = 0, Callback = function(v) K.Aim.PS = v / 100 end})

-- ================= 玩家ESP UI =================
local ESPBox = Tabs.EspTab:AddLeftGroupbox("ESP设置", "eye")
ESPBox:AddToggle("ESPEn", {Text = "开启ESP", Default = false, Callback = function(v) K.ESP.En = v end})
ESPBox:AddSlider("ESPMD", {Text = "最大显示距离", Default = 1000, Min = 50, Max = 20000, Rounding = 0, Callback = function(v) K.ESP.MD = v end})
ESPBox:AddToggle("ESPBoxToggle", {Text = "显示方框", Default = true, Callback = function(v) K.ESP.Bx = v end})
ESPBox:AddToggle("ESPHealthToggle", {Text = "显示血条", Default = true, Callback = function(v) K.ESP.HB = v end})
ESPBox:AddToggle("ESPNameToggle", {Text = "显示名字", Default = true, Callback = function(v) K.ESP.Nm = v end})
ESPBox:AddToggle("ESPDisToggle", {Text = "显示距离", Default = true, Callback = function(v) K.ESP.Ds = v end})
ESPBox:AddToggle("ESPTracerToggle", {Text = "显示射线", Default = false, Callback = function(v) K.ESP.Tr = v end})
ESPBox:AddToggle("ESPSkeletonToggle", {Text = "显示骨骼", Default = false, Callback = function(v) K.ESP.Sk = v end})
ESPBox:AddToggle("ESPNPCToggle", {Text = "显示NPC", Default = false, Callback = function(v) K.ESP.NPC = v end})
ESPBox:AddToggle("ESPTeamCheck", {Text = "队伍检测", Default = true, Callback = function(v) K.ESP.TC = v end})

local ESPCol = Tabs.EspTab:AddRightGroupbox("颜色设置", "palette")
ESPCol:AddLabel("颜色"):AddColorPicker("ESPColor", {Default = Color3.fromRGB(60, 255, 100), Title = "ESP颜色", Callback = function(v) K.ESP.Cl = v end})
ESPCol:AddToggle("ESPTeamColor", {Text = "队伍颜色区分", Default = false, Callback = function(v) K.ESP.TCe = v end})
ESPCol:AddToggle("ESPVisCheck", {Text = "可见性检查变色", Default = false, Callback = function(v) K.ESP.VC = v end})

Window:Show()
print("脚本融合完成")
