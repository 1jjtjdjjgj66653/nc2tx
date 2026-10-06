-- ==================== 服务 ====================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ==================== 踢出标语 ====================
local KICK_MESSAGE = "管理员来了快跑路呀😱😱😱"

-- ==================== 开发者名单 ====================
local DEVELOPER_LIST = {
    "CoderQwerty",
    "ImperialBlood",
}

-- ==================== 管理员名单 ====================
local ADMIN_LIST = {
    "67Sgt123", "AsbestosFree", "bisutoron", "CutePikachu72007",
    "d0ubletap", "goldhunter197A", "Kogusama", "lastquest",
    "lronWraith", "mrderp40", "plaidbubble1437", "realqwerty64",
    "SirRoboAllegiant", "Vashkill", "Areiva", "daainee7",
    "deaboy2001", "Errurly", "flamfyre", "giantsquad",
    "Nathan55770", "NikeAssainCreed", "TheDestoryear",
}

local DevSet = {}
for _, name in ipairs(DEVELOPER_LIST) do
    DevSet[string.lower(name)] = name
end

local AdminSet = {}
for _, name in ipairs(ADMIN_LIST) do
    AdminSet[string.lower(name)] = name
end

-- ==================== 配置 ====================
local CONFIG = {
    EscapeOnAdmin = true,
    EscapeOnDeveloper = true,
    CheckInterval = 1,
    AdminPanicCooldown = 5,
}

local State = {
    AdminsInGame = {},
    DevelopersInGame = {},
    LastPanic = 0,
    Minimized = false,
    Escaped = false,
}

-- ==================== 通知 ====================
local function Notify(t, x)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = t, Text = x, Duration = 3 })
    end)
end

-- ==================== 检测 ====================
local function IsDeveloperName(name)
    return DevSet[string.lower(name)] ~= nil
end

local function IsAdminName(name)
    return AdminSet[string.lower(name)] ~= nil
end

local function ScanDevs()
    local found = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsDeveloperName(p.Name) then
            found[p] = true
        end
    end
    return found
end

local function ScanAdmins()
    local found = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsAdminName(p.Name) and not IsDeveloperName(p.Name) then
            found[p] = true
        end
    end
    return found
end

-- ==================== 跑路（踢出）====================
local function PanicEscape(reason, isDeveloper)
    if State.Escaped then return end
    if isDeveloper and not CONFIG.EscapeOnDeveloper then return end
    if not isDeveloper and not CONFIG.EscapeOnAdmin then return end

    local now = tick()
    if isDeveloper then
        State.LastPanic = now
    else
        if now - State.LastPanic < CONFIG.AdminPanicCooldown then return end
        State.LastPanic = now
    end

    State.Escaped = true

    if isDeveloper and getgenv().AutoEscape and getgenv().AutoEscape.OnDevPanic then
        pcall(getgenv().AutoEscape.OnDevPanic)
    end

    if getgenv().AutoEscape and getgenv().AutoEscape.OnPanic then
        pcall(getgenv().AutoEscape.OnPanic)
    end

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = isDeveloper and "⚠ 开发者进场" or "⚠ 跑路",
            Text = reason,
            Duration = 1
        })
    end)

    pcall(function()
        for _, gui in ipairs(CoreGui:GetChildren()) do
            if gui.Name == "AutoEscapeUI" or gui.Name == "AutoEscapeFloat" then
                gui:Destroy()
            end
        end
    end)

    task.wait(isDeveloper and 0 or 0.1)
    LocalPlayer:Kick(KICK_MESSAGE)
end

getgenv().AutoEscape = getgenv().AutoEscape or {}
getgenv().AutoEscape.Trigger = PanicEscape

-- ==================== UI ====================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "AutoEscapeUI"
ScreenGui.ResetOnSpawn = false

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 400, 0, 175)
Main.Position = UDim2.new(0.016, 0, 0.12, 0)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextButton", Main)
Title.Size = UDim2.new(1, 0, 0, 28)
Title.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
Title.Text = "自动跑路"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.BorderSizePixel = 0
Title.AutoButtonColor = false
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton", Title)
CloseBtn.Size = UDim2.new(0, 20, 0, 20)
CloseBtn.Position = UDim2.new(1, -24, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.BorderSizePixel = 0
CloseBtn.AutoButtonColor = false
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)

local MinBtn = Instance.new("TextButton", Title)
MinBtn.Size = UDim2.new(0, 20, 0, 20)
MinBtn.Position = UDim2.new(1, -48, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 13
MinBtn.BorderSizePixel = 0
MinBtn.AutoButtonColor = false
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

-- 拖动
local mDrag = false
local mSM, mSP, mC1, mC2
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        mDrag = true
        mSM = input.Position
        mSP = Main.Position
        mC1 = UserInputService.InputChanged:Connect(function(i)
            if mDrag and (i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - mSM
                Main.Position = UDim2.new(
                    mSP.X.Scale, mSP.X.Offset + d.X,
                    mSP.Y.Scale, mSP.Y.Offset + d.Y
                )
            end
        end)
        mC2 = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                mDrag = false
                if mC1 then mC1:Disconnect() end
                if mC2 then mC2:Disconnect() end
            end
        end)
    end
end)

-- 悬浮球
local FloatGui = Instance.new("ScreenGui", CoreGui)
FloatGui.Name = "AutoEscapeFloat"
FloatGui.ResetOnSpawn = false
local FloatBtn = Instance.new("TextButton", FloatGui)
FloatBtn.Size = UDim2.new(0, 50, 0, 40)
FloatBtn.Position = UDim2.new(0.01, 0, 0.06, 0)
FloatBtn.BackgroundColor3 = Color3.fromRGB(55, 54, 59)
FloatBtn.Text = "跑路"
FloatBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextSize = 11
FloatBtn.AutoButtonColor = false
FloatBtn.Visible = false
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 10)

local bDrag = false
local bSM, bSP, bC1, bC2
FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        bDrag = true
        bSM = input.Position
        bSP = FloatBtn.Position
        bC1 = UserInputService.InputChanged:Connect(function(i)
            if bDrag and (i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - bSM
                FloatBtn.Position = UDim2.new(
                    bSP.X.Scale, bSP.X.Offset + d.X,
                    bSP.Y.Scale, bSP.Y.Offset + d.Y
                )
            end
        end)
        bC2 = UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                bDrag = false
                if bC1 then bC1:Disconnect() end
                if bC2 then bC2:Disconnect() end
            end
        end)
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    State.Minimized = true
    Main.Visible = false
    FloatBtn.Visible = true
end)

FloatBtn.MouseButton1Click:Connect(function()
    State.Minimized = false
    Main.Visible = true
    FloatBtn.Visible = false
end)

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    FloatGui:Destroy()
end)

-- ============ 左栏 ============
local LeftW = 100

-- 状态
local StatusLabel = Instance.new("TextLabel", Main)
StatusLabel.Size = UDim2.new(0, LeftW, 0, 26)
StatusLabel.Position = UDim2.new(0, 10, 0, 36)
StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
StatusLabel.Text = "安全"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 12
StatusLabel.BorderSizePixel = 0
Instance.new("UICorner", StatusLabel).CornerRadius = UDim.new(0, 5)

-- 管理员开关
local AdminToggle = Instance.new("TextButton", Main)
AdminToggle.Size = UDim2.new(0, LeftW, 0, 26)
AdminToggle.Position = UDim2.new(0, 10, 0, 66)
AdminToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
AdminToggle.Text = "管理员跑路"
AdminToggle.TextColor3 = Color3.fromRGB(0, 255, 0)
AdminToggle.Font = Enum.Font.Gotham
AdminToggle.TextSize = 11
AdminToggle.BorderSizePixel = 0
AdminToggle.AutoButtonColor = false
Instance.new("UICorner", AdminToggle).CornerRadius = UDim.new(0, 5)

AdminToggle.MouseButton1Down:Connect(function()
    CONFIG.EscapeOnAdmin = not CONFIG.EscapeOnAdmin
    AdminToggle.TextColor3 = CONFIG.EscapeOnAdmin and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 80, 80)
end)

-- 开发者开关
local DevToggle = Instance.new("TextButton", Main)
DevToggle.Size = UDim2.new(0, LeftW, 0, 26)
DevToggle.Position = UDim2.new(0, 10, 0, 96)
DevToggle.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
DevToggle.Text = "开发者跑路"
DevToggle.TextColor3 = Color3.fromRGB(0, 255, 0)
DevToggle.Font = Enum.Font.Gotham
DevToggle.TextSize = 11
DevToggle.BorderSizePixel = 0
DevToggle.AutoButtonColor = false
Instance.new("UICorner", DevToggle).CornerRadius = UDim.new(0, 5)

DevToggle.MouseButton1Down:Connect(function()
    CONFIG.EscapeOnDeveloper = not CONFIG.EscapeOnDeveloper
    DevToggle.TextColor3 = CONFIG.EscapeOnDeveloper and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 80, 80)
end)

-- ============ 中栏：开发者列表 ============
local MidX = 118
local MidW = 125

local DevTitle = Instance.new("TextLabel", Main)
DevTitle.Size = UDim2.new(0, MidW, 0, 18)
DevTitle.Position = UDim2.new(0, MidX, 0, 36)
DevTitle.BackgroundTransparency = 1
DevTitle.Text = "在线开发者"
DevTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
DevTitle.Font = Enum.Font.GothamBold
DevTitle.TextSize = 11
DevTitle.TextXAlignment = Enum.TextXAlignment.Left

local DevScroll = Instance.new("ScrollingFrame", Main)
DevScroll.Size = UDim2.new(0, MidW, 0, 110)
DevScroll.Position = UDim2.new(0, MidX, 0, 56)
DevScroll.BackgroundColor3 = Color3.fromRGB(35, 10, 10)
DevScroll.BorderSizePixel = 0
DevScroll.ScrollBarThickness = 3
DevScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", DevScroll).CornerRadius = UDim.new(0, 4)

local DevLayout = Instance.new("UIListLayout", DevScroll)
DevLayout.Padding = UDim.new(0, 2)
DevLayout.SortOrder = Enum.SortOrder.LayoutOrder

DevLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    DevScroll.CanvasSize = UDim2.new(0, 0, 0, DevLayout.AbsoluteContentSize.Y + 4)
end)

local DevRows = {}

local function UpdateDevDisplay()
    local current = {}
    for p, _ in pairs(State.DevelopersInGame) do current[p] = true end
    for p, row in pairs(DevRows) do
        if not current[p] then
            row:Destroy()
            DevRows[p] = nil
        end
    end
    local order = 0
    for p, _ in pairs(State.DevelopersInGame) do
        order = order + 1
        local row = DevRows[p]
        if not row then
            row = Instance.new("Frame", DevScroll)
            row.Size = UDim2.new(1, 0, 0, 22)
            row.BackgroundColor3 = Color3.fromRGB(100, 20, 20)
            row.BorderSizePixel = 0
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

            local lbl = Instance.new("TextLabel", row)
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "☠ " .. p.Name
            lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 10
            lbl.TextScaled = true

            DevRows[p] = row
        end
        row.LayoutOrder = order
    end
end

-- ============ 右栏：管理员列表 ============
local RightX = 253
local RightW = 135

local ListTitle = Instance.new("TextLabel", Main)
ListTitle.Size = UDim2.new(0, RightW, 0, 18)
ListTitle.Position = UDim2.new(0, RightX, 0, 36)
ListTitle.BackgroundTransparency = 1
ListTitle.Text = "在线管理员"
ListTitle.TextColor3 = Color3.fromRGB(255, 150, 150)
ListTitle.Font = Enum.Font.GothamBold
ListTitle.TextSize = 11
ListTitle.TextXAlignment = Enum.TextXAlignment.Left

local AdminScroll = Instance.new("ScrollingFrame", Main)
AdminScroll.Size = UDim2.new(0, RightW, 0, 110)
AdminScroll.Position = UDim2.new(0, RightX, 0, 56)
AdminScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
AdminScroll.BorderSizePixel = 0
AdminScroll.ScrollBarThickness = 3
AdminScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", AdminScroll).CornerRadius = UDim.new(0, 4)

local AdminLayout = Instance.new("UIListLayout", AdminScroll)
AdminLayout.Padding = UDim.new(0, 2)
AdminLayout.SortOrder = Enum.SortOrder.LayoutOrder

AdminLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    AdminScroll.CanvasSize = UDim2.new(0, 0, 0, AdminLayout.AbsoluteContentSize.Y + 4)
end)

local AdminRows = {}

local function UpdateAdminDisplay()
    local current = {}
    for p, _ in pairs(State.AdminsInGame) do current[p] = true end
    for p, row in pairs(AdminRows) do
        if not current[p] then
            row:Destroy()
            AdminRows[p] = nil
        end
    end
    local order = 0
    for p, _ in pairs(State.AdminsInGame) do
        order = order + 1
        local row = AdminRows[p]
        if not row then
            row = Instance.new("Frame", AdminScroll)
            row.Size = UDim2.new(1, 0, 0, 22)
            row.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
            row.BorderSizePixel = 0
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

            local lbl = Instance.new("TextLabel", row)
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "⚠ " .. p.Name
            lbl.TextColor3 = Color3.fromRGB(255, 120, 120)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 10
            lbl.TextScaled = true

            AdminRows[p] = row
        end
        row.LayoutOrder = order
    end
end

local function UpdateStatus()
    if next(State.DevelopersInGame) then
        StatusLabel.Text = "☠ 危险"
        StatusLabel.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    elseif next(State.AdminsInGame) then
        StatusLabel.Text = "危险"
        StatusLabel.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        StatusLabel.Text = "安全"
        StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end

-- ==================== 检测循环 ====================
task.spawn(function()
    while true do
        local devs = ScanDevs()
        local admins = ScanAdmins()
        State.DevelopersInGame = devs
        State.AdminsInGame = admins

        pcall(UpdateDevDisplay)
        pcall(UpdateAdminDisplay)
        pcall(UpdateStatus)

        if CONFIG.EscapeOnDeveloper and next(devs) then
            for dev, _ in pairs(devs) do
                PanicEscape("开发者: " .. dev.Name, true)
                break
            end
        elseif CONFIG.EscapeOnAdmin and next(admins) then
            for admin, _ in pairs(admins) do
                PanicEscape("管理员: " .. admin.Name, false)
                break
            end
        end

        task.wait(CONFIG.CheckInterval)
    end
end)

Players.PlayerAdded:Connect(function(p)
    if p == LocalPlayer then return end

    if IsDeveloperName(p.Name) then
        State.DevelopersInGame[p] = true
        pcall(UpdateDevDisplay)
        pcall(UpdateStatus)
        if CONFIG.EscapeOnDeveloper then
            PanicEscape("开发者加入: " .. p.Name, true)
        end
    elseif IsAdminName(p.Name) then
        State.AdminsInGame[p] = true
        pcall(UpdateAdminDisplay)
        pcall(UpdateStatus)
        if CONFIG.EscapeOnAdmin then
            PanicEscape("管理员加入: " .. p.Name, false)
        end
    end
end)

Notify("自动跑路", "已加载")