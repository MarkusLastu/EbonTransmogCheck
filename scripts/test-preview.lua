local function noop() end
local frames = {}
local methods = {}
local altDown = true
local ctrlDown = false
local previewCalls = 0
local modelLoads = 0
local panelReady = false

local function newFrame(name)
    local frame = setmetatable({
        scripts = {}, children = {}, shown = false, mouseEnabled = false,
    }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^[A-Z]") then return noop end
    end })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end

function methods:SetScript(event, callback)
    self.scripts[event] = callback
end

function methods:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end

function methods:Show()
    self.shown = true
end

function methods:Hide()
    if not self.shown then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end

function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:IsMouseEnabled() return self.mouseEnabled end
function methods:EnableMouse(enabled) self.mouseEnabled = enabled end
function methods:GetChildren() return unpack(self.children) end
function methods:CreateFontString() return newFrame() end

function CreateFrame(_, name, ...) return newFrame(name) end
function InterfaceOptions_AddCategory(...) end
function IsControlKeyDown() return ctrlDown end
function IsAltKeyDown() return altDown end
function IsDressableItem(itemLink) return itemLink ~= nil end
function MouseIsOver(frame) return frame.mouseOver end
function GetLootRollItemLink(rollID) return "item:" .. rollID end
function wipe(values) for key in pairs(values) do values[key] = nil end end

function hooksecurefunc(target, method, callback)
    if type(target) == "string" then return end
    local original = target[method]
    target[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end

SlashCmdList = {}
UIParent = newFrame()
GameTooltip = newFrame()
ItemRefTooltip = newFrame()
local lootOwner = newFrame()
lootOwner.mouseOver = true
lootOwner:Show()
DressUpFrame = newFrame()
DressUpModel = newFrame()
local closeButton = newFrame()
local dragHandle = newFrame()
DressUpFrame.children = { DressUpModel, closeButton }
closeButton.children = { dragHandle }
DressUpFrame.mouseEnabled = true
closeButton.mouseEnabled = true
dragHandle.mouseEnabled = true

local function interceptsMouse(frame)
    if frame:IsMouseEnabled() then return true end
    for _, child in ipairs({ frame:GetChildren() }) do
        if interceptsMouse(child) then return true end
    end
    return false
end

function DressUpFrame:Show()
    self.shown = true
    if interceptsMouse(self) then GameTooltip:Hide() end
end

function ShowUIPanel(frame)
    frame:Show()
    if frame == DressUpFrame then panelReady = true end
end

function HideUIPanel(frame)
    frame:Hide()
    if frame == DressUpFrame then panelReady = false end
end

function DressUpModel:SetUnit(unit)
    assert(DressUpFrame:IsShown(), "Model must be initialized after the frame is shown")
    assert(panelReady, "Initialize the dressing room through ShowUIPanel before loading the model")
    self.unit = unit
    modelLoads = modelLoads + 1
end

function DressUpModel:GetModel() return self.unit and "player-model" end
function DressUpModel:IsVisible() return DressUpFrame:IsShown() end
function DressUpModel:GetWidth() return 316 end
function DressUpModel:GetHeight() return 331 end
function DressUpModel:GetAlpha() return 1 end
function GameTooltip:GetItem() return "Test item", self.ebonTransmogItemLink end
function GameTooltip:GetOwner() return lootOwner end

function DressUpItemLink(itemLink)
    previewCalls = previewCalls + 1
    DressUpFrame:Show()
    assert(DressUpModel.unit == "player", "Preview must load the player before trying on an item")
    DressUpModel.itemLink = itemLink
end

dofile("EbonTransmogCheck.lua")

local function hover(rollID)
    lootOwner.mouseOver = true
    lootOwner:Show()
    GameTooltip:Show()
    GameTooltip:SetLootRollItem(rollID)
    GameTooltip.scripts.OnUpdate(GameTooltip)
end

local function assertRestored()
    assert(not DressUpFrame:IsShown(), "Preview must close")
    assert(not EbonTransmogCheckPreviewFrame:IsShown(), "Stop the independent updater after closing")
    assert(DressUpFrame:IsMouseEnabled(), "Restore frame mouse input")
    assert(closeButton:IsMouseEnabled(), "Restore button mouse input")
    assert(dragHandle:IsMouseEnabled(), "Restore nested child mouse input")
    assert(not DressUpModel:IsMouseEnabled(), "Preserve previously disabled mouse input")
end

hover(100)
assert(DressUpFrame:IsShown() and GameTooltip:IsShown(), "Overlap must not hide the source tooltip")
assert(not interceptsMouse(DressUpFrame), "Preview and all children must pass mouse input through")
assert(DressUpModel.itemLink == "item:100", "Preview the loot-roll item")
for iteration = 1, 10 do GameTooltip.scripts.OnUpdate(GameTooltip) end
assert(previewCalls == 1 and modelLoads == 1, "Stable hover must not reopen or reset the preview")
for refresh = 1, 10 do
    GameTooltip:Hide()
    EbonTransmogCheckPreviewFrame.scripts.OnUpdate()
    assert(DressUpFrame:IsShown(), "Keep the preview during a tooltip refresh while its owner is hovered")
    hover(100)
end
assert(modelLoads == 1, "Refreshing the same loot tooltip must not reload the player model")
local diagnosticMessages = {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message)
        diagnosticMessages[#diagnosticMessages + 1] = message
    end,
}
SlashCmdList.EBONTRANSMOGCHECK("debug")
assert(#diagnosticMessages == 4, "Record opening and next-update diagnostics")
assert(diagnosticMessages[2]:find("model=player%-model"), "Record the loaded model")
assert(diagnosticMessages[3]:find("Next update"), "Sample model state again on the next update")

hover(200)
assert(DressUpModel.itemLink == "item:200", "Update preview when the item changes")
assert(modelLoads == 1, "Do not reset the model when switching items")

GameTooltip:Hide()
lootOwner.mouseOver = false
EbonTransmogCheckPreviewFrame.scripts.OnUpdate()
assertRestored()
DressUpModel.unit = nil
hover(300)
assert(modelLoads == 2, "Reload the player for a new preview")

altDown = false
GameTooltip.scripts.OnUpdate(GameTooltip)
assertRestored()
local callsBefore = previewCalls
ctrlDown = true
hover(400)
assert(previewCalls == callsBefore, "Ctrl alone must not open the temporary preview")
DressUpFrame:Show()
GameTooltip.scripts.OnUpdate(GameTooltip)
assert(DressUpFrame:IsShown(), "Ctrl-only hover must not close the normal dressing room")
DressUpFrame:Hide()
ctrlDown = false

altDown = true
hover(500)
local modifierFrame
for _, frame in ipairs(frames) do
    if frame.scripts.OnEvent and frame ~= EbonTransmogCheckOptionsPanel then
        modifierFrame = frame
    end
end
assert(modifierFrame, "Modifier event handler must be registered")
modifierFrame.scripts.OnEvent(modifierFrame, "MODIFIER_STATE_CHANGED", "LCTRL", "0")
assert(DressUpFrame:IsShown(), "Releasing Ctrl must not close an Alt preview")
modifierFrame.scripts.OnEvent(modifierFrame, "MODIFIER_STATE_CHANGED", "LALT", "0")
assert(DressUpFrame:IsShown(), "Keep the preview while either Alt key remains held")
altDown = false
modifierFrame.scripts.OnEvent(modifierFrame, "MODIFIER_STATE_CHANGED", "RALT", "0")
assertRestored()

altDown = true
hover(600)
lootOwner:Hide()
EbonTransmogCheckPreviewFrame.scripts.OnUpdate()
assertRestored()

print("PASS: preview overlap, model initialization, tooltip refreshes, item changes, owner leave/hide, Alt release, Ctrl independence, mouse restoration")