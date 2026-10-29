-- ============================================================
-- EbonTransmogCheck
-- Checks the ProjectEbonhold appearance collection and shows the
-- result in the loot-roll window.
-- ============================================================

EbonTransmogCheckDB = EbonTransmogCheckDB or EbonholdTransmogCheckDB or {}
EbonTransmogCheckDB.language = EbonTransmogCheckDB.language or "en"
EbonholdTransmogCheckDB = nil

local languages = {
    en = {
        languageSetting = "Language",
        owned = "Appearance already collected",
        sourceMayBeAdded = "This item source may still be added separately.",
        notOwned = "Appearance not collected",
        unavailable = "Appearance cannot be checked",
        ownedMarker = "OK",
        notOwnedMarker = "NO",
        languageChanged = "Language set to English.",
        languageInvalid = "Unknown language. Choose: en, fr, de, ru, es.",
        usage = "Usage: /etmc lang en|fr|de|ru|es",
    },
    fr = {
        languageSetting = "Langue",
        owned = "Apparence déjà collectionnée",
        sourceMayBeAdded = "La source de cet objet peut encore être ajoutée séparément.",
        notOwned = "Apparence non collectionnée",
        unavailable = "Apparence non vérifiable",
        ownedMarker = "OUI",
        notOwnedMarker = "NON",
        languageChanged = "Langue réglée sur le français.",
        languageInvalid = "Langue inconnue. Choisissez : en, fr, de, ru, es.",
        usage = "Utilisation : /etmc lang en|fr|de|ru|es",
    },
    de = {
        languageSetting = "Sprache",
        owned = "Aussehen bereits gesammelt",
        sourceMayBeAdded = "Diese Gegenstandsquelle kann trotzdem separat hinzugefügt werden.",
        notOwned = "Aussehen nicht gesammelt",
        unavailable = "Aussehen nicht überprüfbar",
        ownedMarker = "JA",
        notOwnedMarker = "NEU",
        languageChanged = "Sprache auf Deutsch eingestellt.",
        languageInvalid = "Unbekannte Sprache. Auswahl: en, fr, de, ru, es.",
        usage = "Verwendung: /etmc lang en|fr|de|ru|es",
    },
    ru = {
        languageSetting = "Язык",
        owned = "Внешний вид уже собран",
        sourceMayBeAdded = "Этот предмет всё ещё может быть добавлен отдельно.",
        notOwned = "Внешний вид не собран",
        unavailable = "Не удалось проверить внешний вид",
        ownedMarker = "ДА",
        notOwnedMarker = "НЕТ",
        languageChanged = "Язык изменён на русский.",
        languageInvalid = "Неизвестный язык. Выберите: en, fr, de, ru, es.",
        usage = "Использование: /etmc lang en|fr|de|ru|es",
    },
    es = {
        languageSetting = "Idioma",
        owned = "Aspecto ya coleccionado",
        sourceMayBeAdded = "Esta fuente de objeto aún puede añadirse por separado.",
        notOwned = "Aspecto no coleccionado",
        unavailable = "No se puede comprobar el aspecto",
        ownedMarker = "SI",
        notOwnedMarker = "NO",
        languageChanged = "Idioma configurado en español.",
        languageInvalid = "Idioma desconocido. Elige: en, fr, de, ru, es.",
        usage = "Uso: /etmc lang en|fr|de|ru|es",
    },
}

local function getText(key)
    local language = EbonTransmogCheckDB.language
    return (languages[language] or languages.en)[key] or languages.en[key]
end

local refreshIndicators
local updateLanguageButtons

local function setLanguage(language, announce)
    if not languages[language] then return false end

    EbonTransmogCheckDB.language = language
    if refreshIndicators then refreshIndicators() end
    if updateLanguageButtons then updateLanguageButtons() end
    if announce then
        DEFAULT_CHAT_FRAME:AddMessage("[Ebonhold] " .. getText("languageChanged"))
    end
    return true
end

SLASH_EBONTRANSMOGCHECK1 = "/ebontransmogcheck"
SLASH_EBONTRANSMOGCHECK2 = "/etmc"
SLASH_EBONTRANSMOGCHECK3 = "/transmogcheck"
SlashCmdList.EBONTRANSMOGCHECK = function(message)
    local command, language = string.match((message or ""):lower(), "^(%S*)%s*(%S*)$")
    if command ~= "lang" and command ~= "language" then
        DEFAULT_CHAT_FRAME:AddMessage("[Ebonhold] " .. getText("usage"))
        return
    end

    if not languages[language] then
        DEFAULT_CHAT_FRAME:AddMessage("[Ebonhold] " .. getText("languageInvalid"))
        return
    end

    setLanguage(language, true)
end

local languageNames = {
    en = "English",
    fr = "Français",
    de = "Deutsch",
    ru = "Русский",
    es = "Español",
}
local languageOrder = { "en", "fr", "de", "ru", "es" }
local languageButtons = {}

local optionsPanel = CreateFrame("Frame", "EbonTransmogCheckOptionsPanel", InterfaceOptionsFramePanelContainer)
optionsPanel.name = "EbonTransmogCheck"

local optionsTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
optionsTitle:SetPoint("TOPLEFT", 16, -16)
optionsTitle:SetText("EbonTransmogCheck")

local languageLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
languageLabel:SetPoint("TOPLEFT", optionsTitle, "BOTTOMLEFT", 0, -20)

updateLanguageButtons = function()
    languageLabel:SetText(getText("languageSetting"))
    for _, language in ipairs(languageOrder) do
        local button = languageButtons[language]
        local marker = EbonTransmogCheckDB.language == language and " *" or ""
        button:SetText(languageNames[language] .. marker)
    end
end

for index, language in ipairs(languageOrder) do
    local button = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    button:SetSize(96, 26)
    button:SetPoint("TOPLEFT", languageLabel, "BOTTOMLEFT", (index - 1) * 104, -10)
    button:SetScript("OnClick", function()
        setLanguage(language, false)
    end)
    languageButtons[language] = button
end

optionsPanel:SetScript("OnShow", updateLanguageButtons)
updateLanguageButtons()
InterfaceOptions_AddCategory(optionsPanel)

local collectionDataReady = false
local activeRollItemLink
local previewActive = false
local previewedItemLink

local function getAppearanceOwned(itemID)
    local collections = _G.ezCollections
    if not collectionDataReady or not collections
        or not collections.GetAppearanceSourceRow or not collections.IsVisualCollected then
        return nil
    end

    local appearance = collections:GetAppearanceSourceRow(itemID)
    if not appearance or not appearance.visual then return nil end

    local sources = collections.Collections and collections.Collections.Appearances
    local itemSourceOwned = sources and sources[itemID] == true
    return collections:IsVisualCollected(appearance.visual), itemSourceOwned
end

-- ============================================================
-- Adds the localized collection status to a loot-roll tooltip.
-- ============================================================
local function addAppearanceStatus(tooltip, itemID)
    local owned, itemSourceOwned = getAppearanceOwned(itemID)

    if owned == true then
        tooltip:AddLine("|cff00ff00[Ebonhold] " .. getText("owned") .. "|r")
        if itemSourceOwned == false then
            tooltip:AddLine("|cffaaaaaa" .. getText("sourceMayBeAdded") .. "|r")
        end
    elseif owned == false then
        tooltip:AddLine("|cffff5555[Ebonhold] " .. getText("notOwned") .. "|r")
    else
        tooltip:AddLine("|cff888888[Ebonhold] " .. getText("unavailable") .. "|r")
    end
end

local function getLootItemID(rollID)
    local link = GetLootRollItemLink(rollID)
    local itemID = link and string.match(link, "item:(%d+)")
    return tonumber(itemID)
end

local function updateIndicator(frame)
    if not frame or not frame.rollID then return end

    local itemID = getLootItemID(frame.rollID)
    if not itemID then
        if frame.transmogIndicator then frame.transmogIndicator:Hide() end
        return
    end

    if not frame.transmogIndicator then
        frame.transmogIndicator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.transmogIndicator:SetPoint("BOTTOMRIGHT", frame.IconFrame or frame, "BOTTOMRIGHT", -1, 1)
        frame.transmogIndicator:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    end

    local owned = getAppearanceOwned(itemID)
    if owned == true then
        frame.transmogIndicator:SetText(getText("ownedMarker"))
        frame.transmogIndicator:SetTextColor(0, 1, 0)
    elseif owned == false then
        frame.transmogIndicator:SetText(getText("notOwnedMarker"))
        frame.transmogIndicator:SetTextColor(1, 0.25, 0.25)
    else
        frame.transmogIndicator:SetText("?")
        frame.transmogIndicator:SetTextColor(0.7, 0.7, 0.7)
    end
    frame.transmogIndicator:Show()
end

refreshIndicators = function()
    for index = 1, 4 do
        local frame = _G["GroupLootFrame" .. index]
        if frame and frame:IsShown() then
            updateIndicator(frame)
        end
    end
end

local function closePreview()
    if previewActive and DressUpFrame then
        DressUpFrame:Hide()
    end
    previewActive = false
    previewedItemLink = nil
end

local function updateHeldPreview()
    if not activeRollItemLink or not IsControlKeyDown()
        or not DressUpItemLink or not DressUpFrame then
        closePreview()
        return
    end

    if previewedItemLink ~= activeRollItemLink then
        DressUpItemLink(activeRollItemLink)
        DressUpFrame:ClearAllPoints()
        DressUpFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        previewActive = true
        previewedItemLink = activeRollItemLink
    end
end

-- ProjectEbonhold sends the initial collection snapshot after login.
local collectionFrame = CreateFrame("Frame")
collectionFrame:RegisterEvent("PLAYER_LOGIN")
collectionFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if _G.ezCollections and _G.ezCollections.RegisterEvent then
            _G.ezCollections:RegisterEvent(self, "TRANSMOG_COLLECTION_UPDATED")
        end
        return
    end

    collectionDataReady = true
    refreshIndicators()
end)

-- ============================================================
-- Loot tooltip status and Ctrl-held dressing-room preview.
-- ============================================================
hooksecurefunc(GameTooltip, "SetLootRollItem", function(self, id)
    local link = GetLootRollItemLink(id)
    activeRollItemLink = link
    addAppearanceStatus(self, getLootItemID(id))
end)

GameTooltip:HookScript("OnTooltipSetItem", function()
    local _, itemLink = GameTooltip:GetItem()
    local tooltipItemID = itemLink and tonumber(string.match(itemLink, "item:(%d+)"))
    local rollItemID = activeRollItemLink and tonumber(string.match(activeRollItemLink, "item:(%d+)"))
    if tooltipItemID ~= rollItemID then
        activeRollItemLink = nil
    end
end)
GameTooltip:HookScript("OnUpdate", updateHeldPreview)
GameTooltip:HookScript("OnHide", function()
    if not IsControlKeyDown() then
        activeRollItemLink = nil
        closePreview()
    end
end)

local ctrlKeyFrame = CreateFrame("Frame")
ctrlKeyFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
ctrlKeyFrame:SetScript("OnEvent", function(_, _, key, state)
    if (key == "LCTRL" or key == "RCTRL") and state == "0" then
        activeRollItemLink = nil
        closePreview()
    end
end)

-- ============================================================
-- Compact indicator on each loot-roll icon.
-- ============================================================
if GroupLootFrame_OpenNewFrame then
    hooksecurefunc("GroupLootFrame_OpenNewFrame", refreshIndicators)
end