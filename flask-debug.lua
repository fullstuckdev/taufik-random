-- ============================================================
--  FLASK COOLDOWN DEBUG  (NO HOOK - aman, bisa mukul)
--  Pantau perubahan attribute di Player & Character. Lempar
--  poison SEKALI -> attribute cooldown (kalau ada di client)
--  bakal muncul + ke-copy clipboard. Paste hasilnya ke chat.
-- ============================================================

local lp = game:GetService("Players").LocalPlayer
local log = ""

local function toast(t)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "ATTR",
            Text = tostring(t),
            Duration = 6,
        })
    end)
end

local function record(line)
    log = log .. line .. "\n"
    if setclipboard then
        pcall(setclipboard, log)
    end
    toast(line)
end

local function watch(inst, tag)
    if not inst then
        return
    end
    -- snapshot attribute awal
    pcall(function()
        for name, val in pairs(inst:GetAttributes()) do
            if
                tostring(name):lower():find("cool")
                or tostring(name):lower():find("flask")
                or tostring(name):lower():find("poison")
                or tostring(name):lower():find("cure")
                or tostring(name):lower():find("charge")
            then
                record("[init] " .. tag .. "." .. name .. " = " .. tostring(val))
            end
        end
    end)
    inst.AttributeChanged:Connect(function(name)
        local ok, val = pcall(function()
            return inst:GetAttribute(name)
        end)
        record(tag .. "." .. name .. " = " .. tostring(ok and val or "?"))
    end)
end

watch(lp, "Player")
if lp.Character then
    watch(lp.Character, "Char")
end
lp.CharacterAdded:Connect(function(c)
    watch(c, "Char")
end)

toast("Flask debug aktif - lempar poison SEKALI sekarang")
