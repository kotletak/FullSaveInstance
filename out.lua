-- ZERO-FAULT FULL GAME SAVER (Unlocks Archivable + GC/Nil Sweep + Full USI Config)
local Services = {
    "Workspace", "Lighting", "ReplicatedFirst", "ReplicatedStorage",
    "StarterGui", "StarterPack", "StarterPlayer", "Teams", "SoundService",
    "Chat", "TextChatService", "MaterialService", "LocalizationService",
    "ServerStorage", "ServerScriptService"
}

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local LP = game:GetService("Players").LocalPlayer

-- 1. Restore any server-mirrored vaults into real ServerStorage / ServerScriptService
local vault = RS:FindFirstChild("__OllieServerVault")
if vault then
    for _, pair in ipairs({{"ServerStorage", SS}, {"ServerScriptService", SSS}}) do
        local src = vault:FindFirstChild(pair[1]) or vault:FindFirstChild(pair[1] .. "_Dump")
        if src then
            for _, item in ipairs(src:GetChildren()) do
                pcall(function()
                    item.Archivable = true
                    item:Clone().Parent = pair[2]
                end)
            end
        end
    end
end

-- 2. Snapshot live PlayerGui & Backpack into StarterGui / StarterPack if Starter containers are stripped
pcall(function()
    if LP then
        local sGui = game:GetService("StarterGui")
        local pGui = LP:FindFirstChildOfClass("PlayerGui")
        if pGui and #sGui:GetChildren() == 0 then
            for _, gui in ipairs(pGui:GetChildren()) do
                if gui.Name ~= "TouchGui" and gui.Name ~= "FreeCamera" and gui.Name ~= "Chat" then
                    pcall(function()
                        gui.Archivable = true
                        gui:Clone().Parent = sGui
                    end)
                end
            end
        end

        local sPack = game:GetService("StarterPack")
        local bPack = LP:FindFirstChildOfClass("Backpack")
        if bPack and #sPack:GetChildren() == 0 then
            for _, tool in ipairs(bPack:GetChildren()) do
                pcall(function()
                    tool.Archivable = true
                    tool:Clone().Parent = sPack
                end)
            end
        end
    end
end)

-- 3. Harvest orphaned Instances from getnilinstances() AND Lua Garbage Collector (getgc)
local recoveredNil = SS:FindFirstChild("_RecoveredNil") or Instance.new("Folder", SS)
recoveredNil.Name = "_RecoveredNil"
recoveredNil.Archivable = true

local seen = {}
local function TryRecoverInstance(inst)
    if typeof(inst) ~= "Instance" or seen[inst] or inst == game then return end
    seen[inst] = true
    if inst.Parent == nil then
        local isUseful = inst:IsA("LuaSourceContainer")
            or inst:IsA("Model")
            or inst:IsA("Folder")
            or inst:IsA("Tool")
            or inst:IsA("ScreenGui")
            or inst:IsA("BasePart")
            or inst:IsA("RemoteEvent")
            or inst:IsA("RemoteFunction")
        if isUseful then
            pcall(function()
                inst.Archivable = true
                for _, d in ipairs(inst:GetDescendants()) do
                    pcall(function() d.Archivable = true end)
                end
                local cloned = inst:Clone()
                if cloned then
                    cloned.Parent = recoveredNil
                end
            end)
        end
    end
end

if getnilinstances then
    pcall(function()
        for _, inst in ipairs(getnilinstances()) do
            TryRecoverInstance(inst)
        end
    end)
end

if getgc then
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "Instance" then
                TryRecoverInstance(v)
            end
        end
    end)
end

-- 4. Force Archivable = true across every target service & descendant so nothing is skipped
for _, sName in ipairs(Services) do
    pcall(function()
        local s = game:GetService(sName)
        if s then
            pcall(function() s.Archivable = true end)
            for _, desc in ipairs(s:GetDescendants()) do
                pcall(function() desc.Archivable = true end)
            end
        end
    end)
end

-- 5. Execute UniversalSynSaveInstance with maximum fidelity & anti-timeout settings
local ok, usi = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true), "saveinstance")()
end)

if ok and type(usi) == "function" then
    usi({
        FilePath = string.format("Place_%d_Complete", game.PlaceId),
        mode = "full",
        Decompile = true,
        DecompileTimeout = 15,
        NilInstances = true,
        RemovePlayerCharacters = true,
        SaveBytecode = true,
        IsolateLocalPlayer = true,
        IsolateLocalPlayerCharacter = false,
        IsolateStarterPlayer = false,
        TreatUnionsAsParts = false, -- Keep real CSG unions first; USI auto-falls back if asset fetch fails
        IgnoreDefaultProps = false, -- Write all properties explicitly to prevent Studio defaults mismatch
        SaveNonCreatable = true,
        ReadMe = false,
        Anonymous = true,
        ExtraInstances = { SS, SSS, recoveredNil }
    })
elseif saveinstance then
    -- Hardware executor native fallback if GitHub is blocked
    saveinstance({
        mode = "full",
        decomptype = "new",
        noscripts = false,
        NilInstances = true,
        SaveBytecode = true
    })
end
