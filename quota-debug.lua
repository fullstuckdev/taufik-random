-- ============================================================
--  CURE ATTR/VALUE MONITOR  (NO HOOK, ON-SCREEN, no notif needed)
--  Nampilin perubahan attribute/value angka di LAYAR (bukan notif).
--
--  Buat cari KUOTA revive: hook 1 survivor -> field yang 0->1 = kuota.
--  Buat cek cooldown POISON: lempar 1x -> lihat ada yg berubah / tidak.
-- ============================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer

-- ---------- UI (on-screen, touch, no notif) ----------
local gui = Instance.new("ScreenGui")
gui.Name = "VD_AttrMonitor"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
        gui.Parent = lp:WaitForChild("PlayerGui")
    end
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 420, 0, 340)
main.Position = UDim2.new(0.5, -210, 0.4, -170)
main.BackgroundColor3 = Color3.fromRGB(20, 21, 28)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 34)
bar.BackgroundColor3 = Color3.fromRGB(34, 36, 46)
bar.BorderSizePixel = 0
bar.Parent = main
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -140, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Attr/Value Monitor"
title.TextColor3 = Color3.fromRGB(235, 237, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local function mkBtn(text, color, xoff, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 24)
    b.Position = UDim2.new(1, xoff, 0.5, -12)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(235, 237, 245)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.BorderSizePixel = 0
    b.Parent = bar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local copyBtn = mkBtn("Copy", Color3.fromRGB(60, 200, 120), -128, 56)
local clrBtn = mkBtn("Clear", Color3.fromRGB(90, 130, 255), -66, 56)

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -20, 1, -44)
box.Position = UDim2.new(0, 10, 0, 40)
box.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
box.BorderSizePixel = 0
box.TextColor3 = Color3.fromRGB(210, 240, 210)
box.Font = Enum.Font.Code
box.TextSize = 12
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.TextWrapped = true
box.ClearTextOnFocus = false
box.MultiLine = true
box.Text = "monitor ready...\nhook survivor (cari kuota) / lempar poison (cek cooldown)\n"
box.Parent = main
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
local pad = Instance.new("UIPadding", box)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingTop = UDim.new(0, 6)

-- drag
do
    local drag, ds, sp
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            ds = i.Position
            sp = main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    drag = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end

local log = ""
local function rec(line)
    log = log .. line .. "\n"
    box.Text = log
    if setclipboard then
        pcall(setclipboard, log)
    end
end
copyBtn.Activated:Connect(function()
    if setclipboard then
        pcall(setclipboard, log)
    end
end)
clrBtn.Activated:Connect(function()
    log = ""
    box.Text = ""
end)

-- ---------- watchers ----------
local function watchAttrs(inst, tag)
    if not inst then
        return
    end
    pcall(function()
        for name, val in pairs(inst:GetAttributes()) do
            if type(val) == "number" then
                rec("[init] " .. tag .. ".@" .. name .. " = " .. tostring(val))
            end
        end
    end)
    inst.AttributeChanged:Connect(function(name)
        local ok, val = pcall(function()
            return inst:GetAttribute(name)
        end)
        if ok and type(val) == "number" then
            rec(tag .. ".@" .. name .. " = " .. tostring(val))
        end
    end)
end

local function watchValues(root, tag)
    if not root then
        return
    end
    pcall(function()
        for _, v in ipairs(root:GetDescendants()) do
            if v:IsA("IntValue") or v:IsA("NumberValue") then
                rec("[init] " .. tag .. "." .. v.Name .. " = " .. tostring(v.Value))
                v.Changed:Connect(function(nv)
                    rec(tag .. "." .. v:GetFullName() .. " = " .. tostring(nv))
                end)
            end
        end
    end)
    root.DescendantAdded:Connect(function(v)
        if v:IsA("IntValue") or v:IsA("NumberValue") then
            v.Changed:Connect(function(nv)
                rec("(new) " .. tag .. "." .. v:GetFullName() .. " = " .. tostring(nv))
            end)
        end
    end)
end

watchAttrs(lp, "Player")
watchValues(lp, "Player")
if lp.Character then
    watchAttrs(lp.Character, "Char")
    watchValues(lp.Character, "Char")
end
lp.CharacterAdded:Connect(function(c)
    watchAttrs(c, "Char")
    watchValues(c, "Char")
end)
pcall(function()
    watchValues(lp:WaitForChild("PlayerGui", 5), "GUI")
end)

rec("=== monitor started ===")
