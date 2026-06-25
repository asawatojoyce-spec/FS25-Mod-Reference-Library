-- Name: ELS_loanManagerProperties
-- Author: Chissel

ELS_loanManagerProperties = {}
local ELS_loanManagerProperties_mt = Class(ELS_loanManagerProperties, Object)

InitObjectClass(ELS_loanManagerProperties, "ELS_loanManagerProperties")

ELS_loanManagerProperties.minLoanInterest = 1.0
ELS_loanManagerProperties.maxLoanInterest = 10.0
ELS_loanManagerProperties.loanInterestSteps = 0.1
ELS_loanManagerProperties.loanInterestStartValue = 3.5
ELS_loanManagerProperties.vehicleMortgageStartPercentage = 0.5
ELS_loanManagerProperties.farmlandMortgageStartPercentage = 0.6
ELS_loanManagerProperties.mortgageSteps = 0.05
ELS_loanManagerProperties.mortgageMinValue = 0.00
ELS_loanManagerProperties.mortgageMaxValue = 1.001
ELS_loanManagerProperties.loanDurationStartValue = 20
ELS_loanManagerProperties.loanDurationSteps = 1
ELS_loanManagerProperties.minLoanDurationStep = 1
ELS_loanManagerProperties.maxLoanDurationStep = 35
ELS_loanManagerProperties.specialRedemptionPercentageForAnnuityLoansStart = 0.05
ELS_loanManagerProperties.specialRedemptionPercentageForAnnuityLoansSteps = 0.01
ELS_loanManagerProperties.specialRedemptionPercentageForAnnuityLoansMinValue = 0.00
ELS_loanManagerProperties.specialRedemptionPercentageForAnnuityLoansMaxValue = 1.001

function ELS_loanManagerProperties.new(isServer, isClient, customMt)
    local self = Object.new(isServer, isClient, customMt or ELS_loanManagerProperties_mt)

    self.loanInterest = ELS_loanManagerProperties.loanInterestStartValue
    self.maxLoanDuration = ELS_loanManagerProperties.loanDurationStartValue
    self.dynamicLoanInterest = true
    self.vehicleMortgagePercentage = ELS_loanManagerProperties.vehicleMortgageStartPercentage
    self.farmlandMortgagePercentage = ELS_loanManagerProperties.farmlandMortgageStartPercentage
    self.multipleSpecialRedemptionsAllowed = false
    self.specialRedemptionPercentageForAnnuityLoans = ELS_loanManagerProperties.specialRedemptionPercentageForAnnuityLoansStart
	self.propertiesDirtyFlag = self:getNextDirtyFlag()

	return self
end

function ELS_loanManagerProperties:getLoanInterestSteps()
    local steps = {}

    for i = self.minLoanInterest, self.maxLoanInterest, self.loanInterestSteps do
        table.insert(steps, string.format("%.1f", tostring(i)))
    end

    return steps
end

function ELS_loanManagerProperties:getLoanDurationSteps()
    local steps = {}

    for i = self.minLoanDurationStep, self.maxLoanDurationStep, self.loanDurationSteps do
        table.insert(steps, tostring(i))
    end

    return steps
end

function ELS_loanManagerProperties:getMortgageSteps()
    local steps = {}

    for i = self.mortgageMinValue, self.mortgageMaxValue, self.mortgageSteps do
        table.insert(steps, string.format("%.2f", tostring(i)))
    end

    return steps
end

function ELS_loanManagerProperties:getSpecialRedemptionPercentageForAnnuityLoansSteps()
    local steps = {}

    for i = self.specialRedemptionPercentageForAnnuityLoansMinValue, self.specialRedemptionPercentageForAnnuityLoansMaxValue, self.specialRedemptionPercentageForAnnuityLoansSteps do
        table.insert(steps, string.format("%.2f", tostring(i)))
    end

    return steps
end

function ELS_loanManagerProperties:loadFromXMLFile(xmlFile, key)
    local loanInterest = xmlFile:getFloat(key.."#loanInterest") or ELS_loanManagerProperties.loanInterestStartValue
    self.loanInterest = tonumber(string.format("%.1f", loanInterest))
    self.dynamicLoanInterest = xmlFile:getBool(key.."#dynamicLoanInterest")
    self.maxLoanDuration = xmlFile:getInt(key.."#maxLoanDuration") or ELS_loanManagerProperties.loanDurationStartValue

    local vehicleMortgagePercentage = xmlFile:getFloat(key.."#vehicleMortgagePercentage") or ELS_loanManagerProperties.vehicleMortgageStartPercentage
    self.vehicleMortgagePercentage = tonumber(string.format("%.2f", vehicleMortgagePercentage))
    local farmlandMortgagePercentage = xmlFile:getFloat(key.."#farmlandMortgagePercentage") or ELS_loanManagerProperties.farmlandMortgageStartPercentage
    self.farmlandMortgagePercentage = tonumber(string.format("%.2f", farmlandMortgagePercentage))

    self.multipleSpecialRedemptionsAllowed = xmlFile:getBool(key.."#multipleSpecialRedemptionsAllowed")
    self.specialRedemptionPercentageForAnnuityLoans = xmlFile:getFloat(key.."#specialRedemptionPercentageForAnnuityLoans")

    return true
end

function ELS_loanManagerProperties:saveToXMLFile(xmlFile, key)
    xmlFile:setFloat(key.."#loanInterest", self.loanInterest)
    xmlFile:setBool(key.."#dynamicLoanInterest", self.dynamicLoanInterest)
    xmlFile:setInt(key.."#maxLoanDuration", self.maxLoanDuration)

    xmlFile:setFloat(key.."#vehicleMortgagePercentage", self.vehicleMortgagePercentage)
    xmlFile:setFloat(key.."#farmlandMortgagePercentage", self.farmlandMortgagePercentage)

    xmlFile:setBool(key.."#multipleSpecialRedemptionsAllowed", self.multipleSpecialRedemptionsAllowed)
    xmlFile:setFloat(key.."#specialRedemptionPercentageForAnnuityLoans", self.specialRedemptionPercentageForAnnuityLoans)
end

function ELS_loanManagerProperties:readStream(streamId, connection)
	ELS_loanManagerProperties:superClass().readStream(self, streamId, connection)

    self.loanInterest = streamReadFloat32(streamId)
    self.dynamicLoanInterest = streamReadBool(streamId)
    self.maxLoanDuration = streamReadInt32(streamId)

    self.vehicleMortgagePercentage = streamReadFloat32(streamId)
    self.farmlandMortgagePercentage = streamReadFloat32(streamId)
    
    self.multipleSpecialRedemptionsAllowed = streamReadBool(streamId)
    self.specialRedemptionPercentageForAnnuityLoans = streamReadFloat32(streamId)

    g_els_loanManager.loanManagerProperties = self
end

function ELS_loanManagerProperties:writeStream(streamId, connection)
	ELS_loanManagerProperties:superClass().writeStream(self, streamId, connection)

    streamWriteFloat32(streamId, self.loanInterest)
    streamWriteBool(streamId, self.dynamicLoanInterest)
    streamWriteInt32(streamId, self.maxLoanDuration)

    streamWriteFloat32(streamId, self.vehicleMortgagePercentage)
    streamWriteFloat32(streamId, self.farmlandMortgagePercentage)
    
    streamWriteBool(streamId, self.multipleSpecialRedemptionsAllowed)
    streamWriteFloat32(streamId, self.specialRedemptionPercentageForAnnuityLoans)
end

function ELS_loanManagerProperties:readUpdateStream(streamId, timestamp, connection)
    ELS_loanManagerProperties:superClass().readUpdateStream(self, streamId, timestamp, connection)

    self.loanInterest = streamReadFloat32(streamId)
    self.dynamicLoanInterest = streamReadBool(streamId)
    self.maxLoanDuration = streamReadInt32(streamId)

    self.vehicleMortgagePercentage = streamReadFloat32(streamId)
    self.farmlandMortgagePercentage = streamReadFloat32(streamId)
    
    self.multipleSpecialRedemptionsAllowed = streamReadBool(streamId)
    self.specialRedemptionPercentageForAnnuityLoans = streamReadFloat32(streamId)
end

function ELS_loanManagerProperties:writeUpdateStream(streamId, connection, dirtyMask)
    ELS_loanManagerProperties:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)

    streamWriteFloat32(streamId, self.loanInterest)
    streamWriteBool(streamId, self.dynamicLoanInterest)
    streamWriteInt32(streamId, self.maxLoanDuration)

    streamWriteFloat32(streamId, self.vehicleMortgagePercentage)
    streamWriteFloat32(streamId, self.farmlandMortgagePercentage)
    
    streamWriteBool(streamId, self.multipleSpecialRedemptionsAllowed)
    streamWriteFloat32(streamId, self.specialRedemptionPercentageForAnnuityLoans)
end
