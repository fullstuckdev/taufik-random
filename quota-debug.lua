-- ============================================================
--  CURE QUOTA FINDER  (NO HOOK - aman, bisa mukul)
--  Cari di mana "kuota revive" disimpan. Jalankan -> HOOK 1
--  survivor -> field yang berubah 0->1 = kuotanya. Auto-copy.
-- ============================================================

local lp = game:GetService("Players").LocalPlayer
local log = ""

local function toast(t)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "QUOTA",
            Text = tostring(t),
            Duration = 7,
        })
    end)
end

local function rec(line)
    log = log .. line .. "\n"
    if setclipboard then
        pcall(setclipboard, log)
    end
    toast(line)
end

-- 1) attributes on player + character
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

-- 2) IntValue / NumberValue under player + character
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
-- juga pantau PlayerGui (kadang kuota disimpan sbg value di GUI)
pcall(function()
    watchValues(lp:WaitForChild("PlayerGui", 5), "GUI")
end)

toast("Quota finder aktif - HOOK 1 survivor sekarang")
