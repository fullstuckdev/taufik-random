-- ============================================================
--  VD REMOTE LIST  (NO HOOK - game tetap normal, bisa mukul)
--  Cuma MEMBACA daftar RemoteEvent/RemoteFunction di
--  ReplicatedStorage. Tidak mencegat namecall apa pun.
--
--  Pakai: paste ke Delta -> Execute. Ketik "cure" di kotak
--  search buat nyaring. Tap remote -> copy. Copy All juga ada.
--  Draggable + minimize (icon melayang).
-- ============================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local entries = {} -- { {name, class, full, code} }
local filtered = {}
local query = ""
local minimized = false

local function toast(t)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Remote List",
            Text = tostring(t),
            Duration = 4,
        })
    end)
end

-- ---------- enumerate (no hook, one-time scan) ----------
local function scan()
    table.clear(entries)
    local seen = {}
    local ok, descendants = pcall(function()
        return RS:GetDescendants()
    end)
    if ok and descendants then
        for _, r in ipairs(descendants) do
            if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") or r:IsA("UnreliableRemoteEvent") then
                local full = r.Name
                pcall(function()
                    full = r:GetFullName()
                end)
                if not seen[full] then
                    seen[full] = true
                    local method = r:IsA("RemoteFunction") and "InvokeServer" or "FireServer"
                    entries[#entries + 1] = {
                        name = r.Name,
                        class = r.ClassName,
                        full = full,
                        code = ("local remote = game.%s\nremote:%s()"):format(full, method),
                    }
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        return a.full < b.full
    end)
end

local function applyFilter()
    table.clear(filtered)
    local q = query:lower()
    for _, e in ipairs(entries) do
        if q == "" or e.full:lower():find(q, 1, true) then
            filtered[#filtered + 1] = e
        end
    end
end

-- ---------- UI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "VD_RemoteList"
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
local GREY = Color3.fromRGB(70, 74, 90)
local TXT = Color3.fromRGB(235, 237, 245)

local function mkBtn(parent, text, color, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w or 64, 0, 26)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = TXT
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 440, 0, 380)
main.Position = UDim2.new(0.5, -220, 0.5, -190)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(60, 64, 80)
stroke.Thickness = 1

-- title bar
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 36)
bar.BackgroundColor3 = CARD
bar.BorderSizePixel = 0
bar.Parent = main
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -130, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "VD Remote List (no hook)"
title.TextColor3 = TXT
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local minBtn = mkBtn(bar, "Min", GREY, 44)
minBtn.Position = UDim2.new(1, -114, 0.5, -13)
local closeBtn = mkBtn(bar, "Close", RED, 56)
closeBtn.Position = UDim2.new(1, -64, 0.5, -13)

-- search box
local search = Instance.new("TextBox")
search.Size = UDim2.new(1, -20, 0, 30)
search.Position = UDim2.new(0, 10, 0, 44)
search.BackgroundColor3 = Color3.fromRGB(18, 19, 25)
search.BorderSizePixel = 0
search.PlaceholderText = "search... (contoh: cure / killer / revive)"
search.Text = ""
search.TextColor3 = TXT
search.PlaceholderColor3 = Color3.fromRGB(120, 124, 140)
search.Font = Enum.Font.Gotham
search.TextSize = 13
search.TextXAlignment = Enum.TextXAlignment.Left
search.ClearTextOnFocus = false
search.Parent = main
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 8)
local sPad = Instance.new("UIPadding", search)
sPad.PaddingLeft = UDim.new(0, 10)

-- action row
local actions = Instance.new("Frame")
actions.Size = UDim2.new(1, -20, 0, 30)
actions.Position = UDim2.new(0, 10, 0, 80)
actions.BackgroundTransparency = 1
actions.Parent = main
local aLayout = Instance.new("UIListLayout", actions)
aLayout.FillDirection = Enum.FillDirection.Horizontal
aLayout.Padding = UDim.new(0, 6)
aLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local rescanBtn = mkBtn(actions, "Rescan", ACCENT, 74)
local copyAllBtn = mkBtn(actions, "Copy All", GREEN, 84)
local countLbl = Instance.new("TextLabel")
countLbl.Size = UDim2.new(0, 180, 0, 26)
countLbl.BackgroundTransparency = 1
countLbl.Text = "0 shown"
countLbl.TextColor3 = Color3.fromRGB(160, 165, 180)
countLbl.Font = Enum.Font.Gotham
countLbl.TextSize = 12
countLbl.TextXAlignment = Enum.TextXAlignment.Left
countLbl.Parent = actions

-- list
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -206)
list.Position = UDim2.new(0, 10, 0, 116)
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
preview.Size = UDim2.new(1, -20, 0, 74)
preview.Position = UDim2.new(0, 10, 1, -82)
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
preview.Text = "-- tap a remote to view & copy"
preview.Parent = main
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 8)
local pPad = Instance.new("UIPadding", preview)
pPad.PaddingTop = UDim.new(0, 6)
pPad.PaddingLeft = UDim.new(0, 8)
pPad.PaddingRight = UDim.new(0, 8)

-- ---------- dragging ----------
local function attachDrag(handle, target)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
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
            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end
attachDrag(bar, main)

-- ---------- rendering ----------
local function copyText(txt)
    preview.Text = txt
    if setclipboard then
        pcall(setclipboard, txt)
    end
    toast("Copied")
end

local function refresh()
    for _, ch in ipairs(list:GetChildren()) do
        if ch:IsA("Frame") then
            ch:Destroy()
        end
    end
    for i, e in ipairs(filtered) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundColor3 = CARD
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = list
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameBtn = Instance.new("TextButton")
        nameBtn.Size = UDim2.new(1, -16, 1, 0)
        nameBtn.Position = UDim2.new(0, 8, 0, 0)
        nameBtn.BackgroundTransparency = 1
        nameBtn.Text = e.name .. "   (" .. e.class .. ")"
        nameBtn.TextColor3 = TXT
        nameBtn.Font = Enum.Font.Gotham
        nameBtn.TextSize = 12
        nameBtn.TextXAlignment = Enum.TextXAlignment.Left
        nameBtn.TextTruncate = Enum.TextTruncate.AtEnd
        nameBtn.Parent = row
        nameBtn.Activated:Connect(function()
            copyText(e.code)
        end)
    end
    countLbl.Text = #filtered .. " / " .. #entries .. " shown"
end

local function rebuild()
    applyFilter()
    refresh()
end

search:GetPropertyChangedSignal("Text"):Connect(function()
    query = search.Text
    rebuild()
end)

rescanBtn.Activated:Connect(function()
    scan()
    rebuild()
    toast("Rescanned: " .. #entries .. " remotes")
end)

copyAllBtn.Activated:Connect(function()
    local all = {}
    for i, e in ipairs(filtered) do
        all[i] = e.code
    end
    copyText(#all > 0 and table.concat(all, "\n\n") or "-- (kosong)")
end)

closeBtn.Activated:Connect(function()
    gui:Destroy()
end)

-- ---------- minimize -> floating icon ----------
local floatIcon = Instance.new("TextButton")
floatIcon.Name = "VD_ListFloat"
floatIcon.Size = UDim2.new(0, 46, 0, 46)
floatIcon.Position = UDim2.new(0, 20, 0.4, 0)
floatIcon.BackgroundColor3 = ACCENT
floatIcon.Text = "LIST"
floatIcon.TextColor3 = TXT
floatIcon.Font = Enum.Font.GothamBold
floatIcon.TextSize = 12
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

-- ---------- go ----------
scan()
rebuild()
toast("Remote List siap: " .. #entries .. " remotes (no hook)")
