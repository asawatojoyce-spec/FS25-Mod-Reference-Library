-- Name: ELS_settingsMenuExtension
-- Author: Chissel

ELS_settingsMenuExtension = {}

function ELS_settingsMenuExtension:onFrameOpen()
    if self.els_initSettingsMenuDone then
        return
    end

    local target = ELS_settingsMenuExtension
    
    
    ELS_settingsMenuExtension.els_steps = g_els_loanManager.loanManagerProperties:getLoanInterestSteps()
    ELS_settingsMenuExtension.els_durationSteps = g_els_loanManager.loanManagerProperties:getLoanDurationSteps()
    ELS_settingsMenuExtension.els_mortgageSteps = g_els_loanManager.loanManagerProperties:getMortgageSteps()
    ELS_settingsMenuExtension.els_specialRedemptionPercentageForAnnuityLoansSteps = g_els_loanManager.loanManagerProperties:getSpecialRedemptionPercentageForAnnuityLoansSteps()

    
    ELS_settingsMenuExtension:addSectionHeader(self)
    self.els_dynamicLoanInterest = ELS_settingsMenuExtension:addBinaryOption(
        self, 
        "onDynamicLoanInterestChanged",
        g_i18n:getText("els_settingsMenu_dynamicLoanInterestTitle"), 
        g_i18n:getText("els_settingsMenu_dynamicLoanInterestDescription")
    )
    self.els_dynamicLoanInterestValue = ELS_settingsMenuExtension:addMultiTextOption(
        self, 
        "onDynamicLoanInterestValueChanged", 
        ELS_settingsMenuExtension.els_steps, 
        g_i18n:getText("els_settingsMenu_dynamicLoanInterestValueTitle"), 
        g_i18n:getText("els_settingsMenu_dynamicLoanInterestValueDescription")
    )
    self.els_loanDurationValue = ELS_settingsMenuExtension:addMultiTextOption(
        self, 
        "onLoanDurationValueChanged", 
        ELS_settingsMenuExtension.els_durationSteps, 
        g_i18n:getText("els_settingsMenu_loanDurationValueTitle"), 
        g_i18n:getText("els_settingsMenu_loanDurationValueDescription")
    )
    self.els_vehicleMortgageValue = ELS_settingsMenuExtension:addMultiTextOption(
        self, 
        "onVehicleMortgageValueChanged", 
        ELS_settingsMenuExtension.els_mortgageSteps, 
        g_i18n:getText("els_settingsMenu_vehicleMortgageValueTitle"), 
        g_i18n:getText("els_settingsMenu_vehicleMortgageValueDescription")
    )
    self.els_farmlandMortgageValue = ELS_settingsMenuExtension:addMultiTextOption(
        self, 
        "onFarmlandMortgageValueChanged", 
        ELS_settingsMenuExtension.els_mortgageSteps, 
        g_i18n:getText("els_settingsMenu_farmlandMortgageValueTitle"), 
        g_i18n:getText("els_settingsMenu_farmlandMortgageValueDescription")
    )
    self.els_multipleSpecialRedemptionsAllowed = ELS_settingsMenuExtension:addBinaryOption(
        self, 
        "onMultipleSpecialRedemptionsAllowedChanged",
        g_i18n:getText("els_settingsMenu_multipleSpecialRedemptionsAllowedTitle"), 
        g_i18n:getText("els_settingsMenu_multipleSpecialRedemptionsAllowedDescription"),
        g_els_loanManager.loanManagerProperties.multipleSpecialRedemptionsAllowed
    )
    self.els_specialRedemptionPercentageForAnnuityLoans = ELS_settingsMenuExtension:addMultiTextOption(
        self, 
        "onSpecialRedemptionForAnnuityLoansChanged", 
        ELS_settingsMenuExtension.els_specialRedemptionPercentageForAnnuityLoansSteps, 
        g_i18n:getText("els_settingsMenu_specialRedemptionPercentageForAnnuityLoansTitle"), 
        g_i18n:getText("els_settingsMenu_specialRedemptionPercentageForAnnuityLoansDescription")
    )

    self.gameSettingsLayout:invalidateLayout()
	self:updateAlternatingElements(self.gameSettingsLayout)
	self:updateGeneralSettings(self.gameSettingsLayout)

    self.els_initSettingsMenuDone = true
    ELS_settingsMenuExtension:updateELSSettings(self)
end

function ELS_settingsMenuExtension:addSectionHeader(inGameMenuSettingsFrame)
    local textElement = TextElement.new()
    local textElementProfile = g_gui:getProfile("fs25_settingsSectionHeader")
    textElement.name = "sectionHeader"
    textElement:loadProfile(textElementProfile, true)
    textElement:setText(g_i18n:getText("els_settingsMenu_sectionTitle"))
    inGameMenuSettingsFrame.gameSettingsLayout:addElement(textElement)
    textElement:onGuiSetupFinished()
end

function ELS_settingsMenuExtension:addMultiTextOption(inGameMenuSettingsFrame, onClickCallback, texts, title, tooltip)
    local bitMap = BitmapElement.new()
    local bitMapProfile = g_gui:getProfile("fs25_multiTextOptionContainer")
    bitMap:loadProfile(bitMapProfile, true)

    local multiTextOption = MultiTextOptionElement.new()
    local multiTextOptionProfile = g_gui:getProfile("fs25_settingsMultiTextOption")
    multiTextOption:loadProfile(multiTextOptionProfile, true)
    multiTextOption.target = ELS_settingsMenuExtension
    multiTextOption:setCallback("onClickCallback", onClickCallback)
    multiTextOption:setTexts(texts)

    local multiTextOptionTitle = TextElement.new()
    local multiTextOptionTitleProfile = g_gui:getProfile("fs25_settingsMultiTextOptionTitle")
    multiTextOptionTitle:loadProfile(multiTextOptionTitleProfile, true)
    multiTextOptionTitle:setText(title)

    local multiTextOptionTooltip = TextElement.new()
    local multiTextOptionTooltipProfile = g_gui:getProfile("fs25_multiTextOptionTooltip")
    multiTextOptionTooltip.name = "ignore"
    multiTextOptionTooltip:loadProfile(multiTextOptionTooltipProfile, true)
    multiTextOptionTooltip:setText(tooltip)

    multiTextOption:addElement(multiTextOptionTooltip)
    bitMap:addElement(multiTextOption)
    bitMap:addElement(multiTextOptionTitle)

    multiTextOption:onGuiSetupFinished()
    multiTextOptionTitle:onGuiSetupFinished()
    multiTextOptionTooltip:onGuiSetupFinished()

    inGameMenuSettingsFrame.gameSettingsLayout:addElement(bitMap)
    bitMap:onGuiSetupFinished()
    
    return multiTextOption
end

function ELS_settingsMenuExtension:addBinaryOption(inGameMenuSettingsFrame, onClickCallback, title, tooltip)
    local bitMap = BitmapElement.new()
    local bitMapProfile = g_gui:getProfile("fs25_multiTextOptionContainer")

    bitMap:loadProfile(bitMapProfile, true)

    local binaryOption = BinaryOptionElement.new()
    binaryOption.useYesNoTexts = true
    local binaryOptionProfile = g_gui:getProfile("fs25_settingsBinaryOption")
    binaryOption:loadProfile(binaryOptionProfile, true)
    binaryOption.target = ELS_settingsMenuExtension
    binaryOption:setCallback("onClickCallback", onClickCallback)

    local binaryOptionTitle = TextElement.new()
    local binaryOptionTitleProfile = g_gui:getProfile("fs25_settingsMultiTextOptionTitle")
    binaryOptionTitle:loadProfile(binaryOptionTitleProfile, true)
    binaryOptionTitle:setText(title)

    local binaryOptionTooltip = TextElement.new()
    local binaryOptionTooltipProfile = g_gui:getProfile("fs25_multiTextOptionTooltip")
    binaryOptionTooltip.name = "ignore"
    binaryOptionTooltip:loadProfile(binaryOptionTooltipProfile, true)
    binaryOptionTooltip:setText(tooltip)

    binaryOption:addElement(binaryOptionTooltip)
    bitMap:addElement(binaryOption)
    bitMap:addElement(binaryOptionTitle)

    binaryOption:onGuiSetupFinished()
    binaryOptionTitle:onGuiSetupFinished()
    binaryOptionTooltip:onGuiSetupFinished()

    inGameMenuSettingsFrame.gameSettingsLayout:addElement(bitMap)
    bitMap:onGuiSetupFinished()
    
    return binaryOption
end

function ELS_settingsMenuExtension:updateGameSettings()
    ELS_settingsMenuExtension:updateELSSettings(self)
end

function ELS_settingsMenuExtension:updateELSSettings(currentPage)
    if not currentPage.els_initSettingsMenuDone then
        return
    end

    currentPage.els_dynamicLoanInterest:setIsChecked(g_els_loanManager.loanManagerProperties.dynamicLoanInterest, false, false)
    currentPage.els_multipleSpecialRedemptionsAllowed:setIsChecked(g_els_loanManager.loanManagerProperties.multipleSpecialRedemptionsAllowed, false, false)

    if g_els_loanManager.loanManagerProperties.dynamicLoanInterest then
        currentPage.els_dynamicLoanInterestValue:setDisabled(true)
    else
        currentPage.els_dynamicLoanInterestValue:setDisabled(false)
    end

    for index, value in pairs(ELS_settingsMenuExtension.els_steps) do
        if tonumber(value) == g_els_loanManager.loanManagerProperties.loanInterest then
            currentPage.els_dynamicLoanInterestValue:setState(index)
        end
    end

    for index, value in pairs(ELS_settingsMenuExtension.els_durationSteps) do
        if tonumber(value) == g_els_loanManager.loanManagerProperties.maxLoanDuration then
            currentPage.els_loanDurationValue:setState(index)
        end
    end

    for index, value in pairs(ELS_settingsMenuExtension.els_mortgageSteps) do
        if tonumber(value) == g_els_loanManager.loanManagerProperties.vehicleMortgagePercentage then
            currentPage.els_vehicleMortgageValue:setState(index)
        end
    end

    for index, value in pairs(ELS_settingsMenuExtension.els_mortgageSteps) do
        if value == string.format("%.2f", g_els_loanManager.loanManagerProperties.farmlandMortgagePercentage) then
            currentPage.els_farmlandMortgageValue:setState(index)
        end
    end

    if g_els_loanManager.loanManagerProperties.multipleSpecialRedemptionsAllowed then
        currentPage.els_specialRedemptionPercentageForAnnuityLoans:setDisabled(true)
    else
        currentPage.els_specialRedemptionPercentageForAnnuityLoans:setDisabled(false)
    end

    for index, value in pairs(ELS_settingsMenuExtension.els_specialRedemptionPercentageForAnnuityLoansSteps) do
        if value == string.format("%.2f", g_els_loanManager.loanManagerProperties.specialRedemptionPercentageForAnnuityLoans) then
            currentPage.els_specialRedemptionPercentageForAnnuityLoans:setState(index)
        end
    end
end

function ELS_settingsMenuExtension:onDynamicLoanInterestChanged(state)
    g_els_loanManager:setDynamicLoanInterest(state == BinaryOptionElement.STATE_RIGHT)
    ELS_settingsMenuExtension:updateELSSettings(g_gui.currentGui.target.currentPage)
end

function ELS_settingsMenuExtension:onDynamicLoanInterestValueChanged(state)
    local loanInterestValue = tonumber(ELS_settingsMenuExtension.els_steps[state])
    g_els_loanManager:setLoanInterestValue(loanInterestValue)
    ELS_settingsMenuExtension:updateELSSettings(g_gui.currentGui.target.currentPage)
end

function ELS_settingsMenuExtension:onLoanDurationValueChanged(state)
    local loanDurationValue = tonumber(ELS_settingsMenuExtension.els_durationSteps[state])
    g_els_loanManager:setMaxLoanDurationValue(loanDurationValue)
    ELS_settingsMenuExtension:updateELSSettings(g_gui.currentGui.target.currentPage)
end

function ELS_settingsMenuExtension:onVehicleMortgageValueChanged(state)
    local mortgageValue = tonumber(ELS_settingsMenuExtension.els_mortgageSteps[state])
    g_els_loanManager:setVehicleMortgageValue(mortgageValue)
    ELS_settingsMenuExtension:updateELSSettings(g_gui.currentGui.target.currentPage)
end

function ELS_settingsMenuExtension:onFarmlandMortgageValueChanged(state)
    local mortgageValue = tonumber(ELS_settingsMenuExtension.els_mortgageSteps[state])
    g_els_loanManager:setFarmlandMortgageValue(mortgageValue)
    ELS_settingsMenuExtension:updateELSSettings(g_gui.currentGui.target.currentPage)
end

function ELS_settingsMenuExtension:onMultipleSpecialRedemptionsAllowedChanged(state)
    g_els_loanManager:setMultipleSpecialRedemptionsAllowed(state == BinaryOptionElement.STATE_RIGHT)
    ELS_settingsMenuExtension:updateELSSettings(g_gui.currentGui.target.currentPage)
end

function ELS_settingsMenuExtension:onSpecialRedemptionForAnnuityLoansChanged(state)
    local specialRedemptionValue = tonumber(ELS_settingsMenuExtension.els_specialRedemptionPercentageForAnnuityLoansSteps[state])
    g_els_loanManager:setSpecialRedemptionPercentageForAnnuityLoans(specialRedemptionValue)
    ELS_settingsMenuExtension:updateELSSettings(g_gui.currentGui.target.currentPage)
end

function init()
    InGameMenuSettingsFrame.updateGameSettings = Utils.appendedFunction(InGameMenuSettingsFrame.updateGameSettings, ELS_settingsMenuExtension.updateGameSettings)
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, ELS_settingsMenuExtension.onFrameOpen)
end

init()