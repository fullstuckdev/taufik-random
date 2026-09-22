-- ============================================================
--  VD REMOTE SPY  (standalone, touch-friendly)
--  Nangkap FireServer/InvokeServer, tampil di UI sentuh (tanpa
--  virtual cursor). Copy per-item, Copy All, Exclude, Clear.
--
--  PAKAI SENDIRI (rejoin, jangan barengan script VD utama ->
--  biar tidak dobel hook __namecall).
--
--  Cara: paste ke Delta -> Execute -> main sebagai Cure ->
--  revive zombie -> tap remote di list -> Copy / Copy All ->
--  paste hasilnya.
-- ============================================================

if not (hookmetamethod and getnamecallmethod and newcclosure) then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Remote Spy",
            Text = "Executor tidak mendukung hookmetamethod.",
            Duration = 10,
        })
    end)
    return
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

-- ---------- state ----------
local IGNORE = {
    UpdateCharacterLook = true,
    ReplicateMovement = true,
    UpdatePosition = true,
    Heartbeat = true,
    Ping = true,
    Chatted = true,
}
local detections = {} -- { {name, full, method, argsText, code} }
local seen = {}
local capturing = true
local viewMode = "detected" -- "detected" | "excluded"
local minimized = false
local dirty = false

-- ---------- helpers ----------
local function toast(t)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Remote Spy",
            Text = tostring(t),
            Duration = 4,
        })
    end)
end

local function serialize(v)
    local t = typeof(v)
    if t == "Instance" then
        return v:GetFullName()
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "Vector3" then
        return ("Vector3.new(%s, %s, %s)"):format(v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        return "CFrame.new(--[[" .. tostring(v) .. "]])"
    elseif t == "table" then
        return "{ --[[table]] }"
    else
        return "--[[" .. t .. "]] nil"
    end
end

local function buildCode(remote, method, argList, n)
    local parts = {}
    for idx = 1, n do
        parts[idx] = serialize(argList[idx])
    end
    local joined = table.concat(parts, ", ")
    local full = remote.Name
    pcall(function()
        full = remote:GetFullName()
    end)
    return ("local remote = game.%s\nremote:%s(%s)"):format(full, method, joined), full, joined
end

-- ---------- UI (touch native, no virtual cursor) ----------
local gui = Instance.new("ScreenGui")
gui.Name = "VD_RemoteSpy"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
do
    local ok = pcall(function()
        gui.Parent = gethui()
    end)
    if not ok then
        ok = pcall(function()
            gui.Parent = game:GetService("CoreGui")
        end)
    end
    if not ok then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end

local BG = Color3.fromRGB(24, 25, 32)
local CARD = Color3.fromRGB(34, 36, 46)
local ACCENT = Color3.fromRGB(90, 130, 255)
local RED = Color3.fromRGB(230, 70, 70)
local GREEN = Color3.fromRGB(60, 200, 120)
local TXT = Color3.fromRGB(235, 237, 245)
local GREY = Color3.fromRGB(70, 74, 90)

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 420, 0, 360)
main.Position = UDim2.new(0.5, -210, 0.5, -180)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(60, 64, 80)
stroke.Thickness = 1

local function mkBtn(parent, text, color, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w or 64, 0, 26)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = TXT
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.AutoButtonColor = true
    b.BorderSizePixel = 0
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

-- title bar (draggable)
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 36)
bar.BackgroundColor3 = CARD
bar.BorderSizePixel = 0
bar.Parent = main
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -186, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "VD Remote Spy"
title.TextColor3 = TXT
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local pauseBtn = mkBtn(bar, "Pause", ACCENT, 56)
pauseBtn.Position = UDim2.new(1, -176, 0.5, -13)
local minBtn = mkBtn(bar, "Min", GREY, 44)
minBtn.Position = UDim2.new(1, -114, 0.5, -13)
local closeBtn = mkBtn(bar, "Close", RED, 56)
closeBtn.Position = UDim2.new(1, -64, 0.5, -13)

-- action row
local actions = Instance.new("Frame")
actions.Size = UDim2.new(1, -20, 0, 30)
actions.Position = UDim2.new(0, 10, 0, 42)
actions.BackgroundTransparency = 1
actions.Parent = main
local aLayout = Instance.new("UIListLayout", actions)
aLayout.FillDirection = Enum.FillDirection.Horizontal
aLayout.Padding = UDim.new(0, 6)
aLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local copyAllBtn = mkBtn(actions, "Copy All", GREEN, 84)
local clearBtn = mkBtn(actions, "Clear", RED, 60)
local viewBtn = mkBtn(actions, "Excluded", GREY, 84)
local countLbl = Instance.new("TextLabel")
countLbl.Size = UDim2.new(0, 160, 0, 26)
countLbl.BackgroundTransparency = 1
countLbl.Text = "0 remotes"
countLbl.TextColor3 = Color3.fromRGB(160, 165, 180)
countLbl.Font = Enum.Font.Gotham
countLbl.TextSize = 12
countLbl.TextXAlignment = Enum.TextXAlignment.Left
countLbl.Parent = actions

-- list
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -170)
list.Position = UDim2.new(0, 10, 0, 78)
list.BackgroundColor3 = Color3.fromRGB(18, 19, 25)
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = main
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)
local lLayout = Instance.new("UIListLayout", list)
lLayout.SortOrder = Enum.SortOrder.LayoutOrder
lLayout.Padding = UDim.new(0, 4)
local lPad = Instance.new("UIPadding", list)
lPad.PaddingTop = UDim.new(0, 6)
lPad.PaddingLeft = UDim.new(0, 6)
lPad.PaddingRight = UDim.new(0, 6)

-- preview
local preview = Instance.new("TextBox")
preview.Size = UDim2.new(1, -20, 0, 80)
preview.Position = UDim2.new(0, 10, 1, -88)
preview.BackgroundColor3 = Color3.fromRGB(18, 19, 25)
preview.BorderSizePixel = 0
preview.TextColor3 = TXT
preview.Font = Enum.Font.Code
preview.TextSize = 12
preview.TextXAlignment = Enum.TextXAlignment.Left
preview.TextYAlignment = Enum.TextYAlignment.Top
preview.TextWrapped = true
preview.ClearTextOnFocus = false
preview.MultiLine = true
preview.Text = "-- tap a remote to view & copy its code"
preview.Parent = main
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 8)
local pPad = Instance.new("UIPadding", preview)
pPad.PaddingTop = UDim.new(0, 6)
pPad.PaddingLeft = UDim.new(0, 8)
pPad.PaddingRight = UDim.new(0, 8)

-- ---------- dragging (touch + mouse) ----------
local dragging, dragStart, startPos
bar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- ---------- list rendering ----------
local function copyText(txt)
    preview.Text = txt
    if setclipboard then
        pcall(setclipboard, txt)
    end
    toast("Copied to clipboard")
end

local function makeRowFrame(order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = CARD
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = list
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    return row
end

local function makeSideButton(row, text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 44, 0, 22)
    b.Position = UDim2.new(1, -50, 0.5, -11)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = TXT
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.BorderSizePixel = 0
    b.Parent = row
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end

local function refresh()
    for _, ch in ipairs(list:GetChildren()) do
        if ch:IsA("Frame") then
            ch:Destroy()
        end
    end
    if viewMode == "detected" then
        for i, e in ipairs(detections) do
            local row = makeRowFrame(i)
            local nameBtn = Instance.new("TextButton")
            nameBtn.Size = UDim2.new(1, -60, 1, 0)
            nameBtn.Position = UDim2.new(0, 8, 0, 0)
            nameBtn.BackgroundTransparency = 1
            nameBtn.Text = e.method .. "  " .. e.name
            nameBtn.TextColor3 = TXT
            nameBtn.Font = Enum.Font.Gotham
            nameBtn.TextSize = 12
            nameBtn.TextXAlignment = Enum.TextXAlignment.Left
            nameBtn.TextTruncate = Enum.TextTruncate.AtEnd
            nameBtn.Parent = row
            nameBtn.Activated:Connect(function()
                copyText(e.code)
            end)
            local ex = makeSideButton(row, "Excl", RED)
            ex.Activated:Connect(function()
                IGNORE[e.name] = true
                for idx = #detections, 1, -1 do
                    if detections[idx].name == e.name then
                        table.remove(detections, idx)
                    end
                end
                refresh()
            end)
        end
        countLbl.Text = #detections .. " remotes"
    else
        local names = {}
        for name in pairs(IGNORE) do
            names[#names + 1] = name
        end
        table.sort(names)
        for i, name in ipairs(names) do
            local row = makeRowFrame(i)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -60, 1, 0)
            lbl.Position = UDim2.new(0, 8, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = name
            lbl.TextColor3 = Color3.fromRGB(180, 185, 200)
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 12
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.Parent = row
            local inc = makeSideButton(row, "Incl", GREEN)
            inc.Activated:Connect(function()
                IGNORE[name] = nil
                refresh()
            end)
        end
        countLbl.Text = #names .. " excluded"
    end
end

copyAllBtn.Activated:Connect(function()
    local all = {}
    for i, e in ipairs(detections) do
        all[i] = e.code
    end
    local text = #all > 0 and table.concat(all, "\n\n") or "-- (kosong)"
    copyText(text)
end)

clearBtn.Activated:Connect(function()
    table.clear(detections)
    table.clear(seen)
    refresh()
end)

pauseBtn.Activated:Connect(function()
    capturing = not capturing
    pauseBtn.Text = capturing and "Pause" or "Resume"
    pauseBtn.BackgroundColor3 = capturing and ACCENT or GREEN
end)

closeBtn.Activated:Connect(function()
    capturing = false
    gui:Destroy()
end)

viewBtn.Activated:Connect(function()
    viewMode = (viewMode == "detected") and "excluded" or "detected"
    viewBtn.Text = (viewMode == "detected") and "Excluded" or "Detected"
    refresh()
end)

-- minimize -> draggable floating icon (tap to reopen)
local floatIcon = Instance.new("TextButton")
floatIcon.Name = "VD_SpyFloat"
floatIcon.Size = UDim2.new(0, 46, 0, 46)
floatIcon.Position = UDim2.new(0, 20, 0.4, 0)
floatIcon.BackgroundColor3 = ACCENT
floatIcon.Text = "SPY"
floatIcon.TextColor3 = TXT
floatIcon.Font = Enum.Font.GothamBold
floatIcon.TextSize = 13
floatIcon.Visible = false
floatIcon.ZIndex = 10
floatIcon.Active = true
floatIcon.Parent = gui
Instance.new("UICorner", floatIcon).CornerRadius = UDim.new(0.5, 0)
do
    local st = Instance.new("UIStroke", floatIcon)
    st.Color = Color3.fromRGB(150, 175, 255)
    st.Thickness = 1.4
end

minBtn.Activated:Connect(function()
    main.Visible = false
    floatIcon.Visible = true
    minimized = true
end)

do
    local fDrag, fStart, fPos, moved
    floatIcon.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            fDrag = true
            moved = false
            fStart = input.Position
            fPos = floatIcon.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    fDrag = false
                    if not moved then
                        main.Visible = true
                        floatIcon.Visible = false
                        minimized = false
                    end
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if fDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - fStart
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
                moved = true
            end
            floatIcon.Position = UDim2.new(
                fPos.X.Scale,
                fPos.X.Offset + delta.X,
                fPos.Y.Scale,
                fPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- throttled UI refresh (decoupled from the hook so the game thread never
-- blocks on UI rebuilds, and a UI error can't corrupt the __namecall hook)
task.spawn(function()
    while gui.Parent do
        task.wait(0.35)
        if dirty then
            dirty = false
            pcall(refresh)
        end
    end
end)

-- ---------- the hook ----------
local old
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    -- Keep this path as light as possible: capture the essentials, then defer
    -- ALL heavy work (GetFullName/serialize/UI) off the namecall so the game's
    -- own remote calls (attacks, etc.) return instantly and stay unaffected.
    if capturing and typeof(self) == "Instance" then
        local m = getnamecallmethod()
        if m == "FireServer" or m == "InvokeServer" then
            local args = { ... }
            local argc = select("#", ...)
            task.spawn(function()
                local okName, nm = pcall(function()
                    return self.Name
                end)
                if okName and not IGNORE[nm] then
                    local ok, code, full, joined = pcall(buildCode, self, m, args, argc)
                    if ok then
                        local key = m .. "|" .. full .. "|" .. joined
                        if not seen[key] then
                            seen[key] = true
                            table.insert(detections, {
                                name = nm,
                                full = full,
                                method = m,
                                argsText = joined,
                                code = code,
                            })
                            if #detections > 200 then
                                table.remove(detections, 1)
                            end
                            if setclipboard then
                                pcall(setclipboard, code)
                            end
                            dirty = true
                        end
                    end
                end
            end)
        end
    end
    return old(self, ...)
end))

toast("Remote Spy aktif - trigger skill sekarang")
