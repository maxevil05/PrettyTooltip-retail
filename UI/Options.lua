-- Settings-page presentation and registration. The shared API lives in Core/Settings.lua.
local _, ns = ...
local setOption = ns.setOption
local L = ns.L

local page, category
ns.Options = {}

-- Called by the entry file after saved settings arrive.
function ns.Options.register()
    if page then return end
    page = CreateFrame("Frame")
    page.name = "PrettyTooltip"
    -- Created hidden, or the settings window never fires OnShow on first open.
    page:Hide()
    local controls = {}

    local function refreshControls()
        for _, control in ipairs(controls) do control.refresh() end
    end

    local pageTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", 16, -16)
    pageTitle:SetText("PrettyTooltip")
    local subtitle = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
    subtitle:SetText(L["A full reskin of tooltips. Changes apply the next time a tooltip opens."])

    local editorButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    editorButton:SetSize(180, 24)
    editorButton:SetPoint("TOPLEFT", 16, -64)
    editorButton:SetText(L["Open the style editor"])

    -- Explanations show on hover, which keeps the page short.
    local function explain(widget, title, text)
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[title], 1, 1, 1)
            GameTooltip:AddLine(L[text], nil, nil, nil, true)
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    explain(editorButton, "Style editor", "The look of every kind of tooltip, with a live sample: fonts, "
        .. "sizes, and colors for every part, text size, tints, and opacities, and each kind's own details, "
        .. "as disenchant results, the spell power breakdown, and the health bar. Also /ptip.")
    -- Opens over the settings window, which is left as it is: closing it from
    -- here would run its code under the addon's taint.
    editorButton:SetScript("OnClick", function()
        if ns.openEditor then ns.openEditor() end
    end)

    -- Two-tab layout. Each tab owns a scrollable canvas; the title and editor
    -- shortcut stay outside the scroll area so they never get clipped.
    local tabs = {}
    local panels = {}
    local activeTab = "general"
    local function makePanel(id)
        local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -112)
        scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -30, 12)
        local canvas = CreateFrame("Frame", nil, scroll)
        canvas:SetSize(700, 700)
        scroll:SetScrollChild(canvas)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local bar = self.ScrollBar or _G[self:GetName() and self:GetName() .. "ScrollBar" or ""]
            if bar then bar:SetValue(bar:GetValue() - delta * 42) end
        end)
        panels[id] = {scroll=scroll, canvas=canvas}
        scroll:Hide()
        return canvas
    end
    local general = makePanel("general")
    local modifiers = makePanel("modifiers")
    local function selectTab(id)
        activeTab = id
        for name, panel in pairs(panels) do
            panel.scroll:SetShown(name == id)
            if tabs[name] then
                tabs[name]:SetEnabled(name ~= id)
            end
        end
        refreshControls()
    end
    local function addTab(id, text, x)
        local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        button:SetSize(110, 24)
        button:SetPoint("TOPLEFT", page, "TOPLEFT", x, -80)
        button:SetText(L[text])
        button:SetScript("OnClick", function() selectTab(id) end)
        tabs[id] = button
    end
    addTab("general", "General", 16)
    addTab("modifiers", "Modifier Keys", 132)

    local function section(parent, x, y, text)
        local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        header:SetText(L[text])
        return y - 25
    end
    local function checkbox(parent, x, y, key, title, description, followsLayout)
        local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        button:SetSize(24, 24)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        if key then
            button:SetScript("OnClick", function(self)
                setOption(key, self:GetChecked() and true or false)
            end)
            button.refresh = function()
                button:SetChecked(ns.option(key))
                if followsLayout then button:SetEnabled(ns.option("layout") ~= "blizzard") end
            end
            controls[#controls + 1] = button
        else
            button:Disable()
        end
        if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
        explain(button, title, description)
        return button
    end
    local function radios(parent, x, y, choices, current, pick, spacing)
        spacing = spacing or 23
        for _, choice in ipairs(choices) do
            local value, label, note = choice[1], choice[2], choice[3]
            local button = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
            local caption = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            caption:SetPoint("LEFT", button, "RIGHT", 6, 0)
            caption:SetText(L[label])
            button:SetHitRectInsets(0, -(caption:GetStringWidth() + 8), 0, 0)
            button:SetScript("OnClick", function() pick(value); refreshControls() end)
            button.refresh = function() button:SetChecked(current() == value) end
            controls[#controls + 1] = button
            explain(button, label, note)
            y = y - spacing
        end
        return y
    end
    local function optionRadios(parent, x, y, key, choices)
        return radios(parent, x, y, choices, function() return ns.option(key) end,
            function(value) setOption(key, value) end)
    end

    -- GENERAL: full original tooltip-type table, including its last rows.
    local y = section(general, 8, -8, "Restyled Tooltips")
    local restyleLabel = general:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    restyleLabel:SetPoint("TOPLEFT", general, "TOPLEFT", 258, y)
    restyleLabel:SetText(L["Restyle"])
    local cursorLabel = general:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cursorLabel:SetPoint("TOPLEFT", general, "TOPLEFT", 360, y)
    cursorLabel:SetText(L["Follow cursor"])
    y = y - 19
    for _, tooltipType in ipairs(ns.TOOLTIP_TYPES) do
        local label = general:CreateFontString(nil, "ARTWORK",
            tooltipType.restyle and "GameFontHighlight" or "GameFontDisable")
        label:SetPoint("TOPLEFT", general, "TOPLEFT", 16, y - 3)
        label:SetText(L[tooltipType.label])
        checkbox(general, 263, y + 3, tooltipType.restyle,
            "Restyle " .. tooltipType.label:lower(), tooltipType.restyle
                and "Draws the PrettyTooltip panel. Off, this kind keeps the game's own tooltip, with the details modifier's rows added to it."
                or "Not restyled yet; this kind keeps the game's own tooltip.", true)
        checkbox(general, 365, y + 3, tooltipType.cursor, "Follow cursor",
            "Shows this kind's tooltip at the cursor when the game would put it in its default corner; bags and other panels keep theirs.")
        y = y - 24
    end
    y = y - 18
    local rightX = 460
    local rightY = section(general, rightX, -8, "Layout Style")
    rightY = optionRadios(general, rightX + 8, rightY, "layout", {
        {"pretty", "PrettyTooltip", "Draw the PrettyTooltip panel for each kind turned on under Restyled Tooltips."},
        {"blizzard", "Blizzard", "Keep the game's own tooltips."},
    }) - 18
    rightY = section(general, rightX, rightY, "Follow cursor")
    local combatBox = checkbox(general, rightX + 8, rightY + 4, "cursorDisableInCombat",
        "Disable in combat", "Use the default tooltip position during combat, then resume following the cursor afterward.")
    local combatLabel = general:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    combatLabel:SetPoint("LEFT", combatBox, "RIGHT", 6, 0)
    combatLabel:SetText(L["Disable in combat"])
    combatBox:SetHitRectInsets(0, -(combatLabel:GetStringWidth() + 8), 0, 0)
    rightY = rightY - 48
    rightY = section(general, rightX, rightY, "Style Editor Appearance")
    rightY = radios(general, rightX + 8, rightY, {
        {"native", "Blizzard", "Use the game's settings frame borders and controls."},
        {"flat", "Flat", "Use the flat editor appearance."},
    }, ns.editorStyle, function(value)
        setOption("editorStyle", value)
        if ns.refreshEditorStyle then ns.refreshEditorStyle() end
    end) - 18
    rightY = section(general, rightX, rightY, "Global scale")
    local scaleSlider = CreateFrame("Slider", nil, general, "MinimalSliderTemplate")
    scaleSlider:SetOrientation("HORIZONTAL")
    scaleSlider:SetPoint("TOPLEFT", general, "TOPLEFT", rightX + 12, rightY)
    scaleSlider:SetSize(125, 19)
    scaleSlider:SetMinMaxValues(50, 150)
    scaleSlider:SetValueStep(1)
    if scaleSlider.SetObeyStepOnDrag then scaleSlider:SetObeyStepOnDrag(true) end
    local scaleValue = scaleSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    scaleValue:SetPoint("TOP", scaleSlider, "BOTTOM", 0, -5)
    scaleValue:SetJustifyH("CENTER")
    scaleSlider:SetScript("OnValueChanged", function(self, percent)
        if self.updating then return end
        percent = math.floor(percent + .5)
        setOption("tooltipScale", percent ~= 100 and percent / 100 or nil)
        scaleValue:SetText(percent .. "%")
    end)
    scaleSlider.refresh = function()
        scaleSlider.updating = true
        local percent = math.floor(ns.tooltipScale() * 100 + .5)
        scaleSlider:SetValue(percent)
        scaleValue:SetText(percent .. "%")
        scaleSlider.updating = false
    end
    controls[#controls + 1] = scaleSlider
    explain(scaleSlider, "Global scale", "Scales every PrettyTooltip panel, including text, icons, spacing, and bars.")
    general:SetHeight(math.max(680, -y + 35, -rightY + 90))

    -- MODIFIERS: four independent groups, two columns and two rows.
    local function modifierGroup(x, y, heading, key, choices)
        local top = section(modifiers, x, y, heading)
        optionRadios(modifiers, x + 8, top, key, choices)
    end
    modifierGroup(8, -12, "Mythic+ Rating Modifier", "mythicScoreKey", {
        {"CTRL", "Ctrl", "Hold Ctrl to show dungeon score details."},
        {"ALT", "Alt", "Hold Alt to show dungeon score details."},
        {"NONE", "Always Show", "Always show dungeon score details."},
    })
    modifierGroup(380, -12, "Raid Progress Modifier", "raidProgressKey", {
        {"CTRL", "Ctrl", "Hold Ctrl to show raid progress."},
        {"ALT", "Alt", "Hold Alt to show raid progress."},
        {"NONE", "Always Show", "Always show raid progress."},
    })
    modifierGroup(8, -168, "Default Tooltip Modifier", "originalKey", {
        {"CTRL", "Ctrl", "Hold Ctrl to see the game's own tooltip instead of the panel."},
        {"ALT", "Alt", "Hold Alt to see the game's own tooltip instead of the panel."},
        {"NONE", "Never", "Never show the game's own tooltip in place of the panel."},
    })
    modifierGroup(380, -168, "Tooltip Details Modifier", "detailsKey", {
        {"SHIFT", "Shift", "Hold Shift to see additional tooltip details."},
        {"ALWAYS", "Always Show", "Always show additional tooltip details."},
    })
    modifiers:SetHeight(400)
    selectTab("general")

    page:SetScript("OnShow", refreshControls)
    -- Hooks the settings window calls on canvas pages: when it shows them, and
    -- from its Defaults button.
    page.OnRefresh = refreshControls
    page.OnDefault = function()
        ns.resetOptions()
        if ns.refreshEditorStyle then ns.refreshEditorStyle() end
        refreshControls()
    end

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(page, page.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end
    refreshControls()
end

-- The game's settings window does not open in combat; the player is told so
-- instead of nothing happening. True when it opened.
function ns.openSettings()
    if InCombatLockdown() then
        print(L["PrettyTooltip: the options cannot open during combat. Try again once it ends."])
        return false
    end
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(page)
    end
    return true
end
