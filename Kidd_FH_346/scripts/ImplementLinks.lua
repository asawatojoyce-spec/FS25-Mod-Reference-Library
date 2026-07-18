--
-- PowerShaft
-- Specialization for PowerShaft
--
-- @author  Manuel Leithner
-- @date  26/07/09
---------------------------------------
-- hydraulic hose
-- Specialization for hydraulic hose joint
--
-- @author  PeterJ - LS-UK modteam
-- @date  02/06/2012
--
-- Copyright (C) FS-UK modteam, Confidential, All Rights Reserved.
--

ImplementLinks = {};
ImplementLinks.stat = {};

function ImplementLinks.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Attachable, specializations);
end;

function ImplementLinks:load(xmlFile)
	
	---- attachable pto ----
	self.powerShaft = {};		
	self.powerShaft.node = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.implementLinks.powerShaft#index"));
	local x,y,z = getRotation(self.powerShaft.node);
	self.powerShaft.rot = {x,y,z};
	self.powerShaft.part = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.implementLinks.powerShaft#part"));
	x,y,z = getTranslation(self.powerShaft.part);
	self.powerShaft.trans = {x,y,z};
	self.powerShaft.fixPoint = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.implementLinks.powerShaft#fixPoint"));
	if self.powerShaft.node ~= nil then
		local ax, ay, az = getWorldTranslation(self.powerShaft.part);
		local bx, by, bz = getWorldTranslation(self.powerShaft.fixPoint);		
		self.powerShaft.distance = Utils.vector3Length(ax-bx, ay-by, az-bz);
		self.usePTO = true;
		self.PTOattached = self.powerShaft.node;
	end;
	self.attacherVehiclePowerShaft = nil;
	
	self.setPTO = SpecializationUtil.callSpecializationsFunction("setPTO");
	self.PTOdeattached = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.implementLinks.powerShaft#deattached"));
	self.enableManualPTOattach = Utils.getNoNil(getXMLBool(xmlFile, "vehicle.implementLinks.powerShaft#manualAttach"), false);	
	if self.enableManualPTOattach then	
		setVisibility(self.PTOdeattached,true);
		setVisibility(self.PTOattached,false);
	else
		setVisibility(self.PTOdeattached,false);
		setVisibility(self.PTOattached,true);
	end;
	
	self.PTOId = true;
	
	---- hydraulic hose ----
	self.hose = {};		
	self.hose.node = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.implementLinks.hose#index"));
	local x,y,z = getRotation(self.hose.node);
	self.hose.rot = {x,y,z};
	self.hose.part = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.implementLinks.hose#part"));
	x,y,z = getTranslation(self.hose.part);
	self.hose.trans = {x,y,z};
	self.hose.fixPoint = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.implementLinks.hose#fixPoint"));
	if self.hose.node ~= nil then
		local ax, ay, az = getWorldTranslation(self.hose.part);
		local bx, by, bz = getWorldTranslation(self.hose.fixPoint);		
		self.hose.distance = Utils.vector3Length(ax-bx, ay-by, az-bz);
		self.useHose = true;
	end;
	self.attacherVehicleHose = nil;
	
	self.doJointSearch = false;
end;

function ImplementLinks:delete()
end;

function ImplementLinks:readStream(streamId, connection)
	self.isLoading = true;
	local PTO = streamReadBool(streamId);
	self:setPTO(PTO, true);
end;
  
function ImplementLinks:writeStream(streamId, connection)
	streamWriteBool(streamId, self.PTOId);
end;

function ImplementLinks:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if not resetVehicles then
		local PTOlinked = getXMLBool(xmlFile, key.."#PTOdetached");
		if PTOlinked ~= nil then
			self:setPTO(PTOlinked);
			self.PTOId = PTOlinked;
		end;
	end;
	return BaseMission.VEHICLE_LOAD_OK;
end;
  
function ImplementLinks:getSaveAttributesAndNodes(nodeIdent)
	local attributes = ' ';

	local mystring = 'PTOdetached="' .. tostring(self.PTOId) ..'"';	
	attributes = attributes .. mystring;

    local node = nil;
	return attributes, node;
end;

function ImplementLinks:mouseEvent(posX, posY, isDown, isUp, button)
end;

function ImplementLinks:keyEvent(unicode, sym, modifier, isDown)
end;

function ImplementLinks:update(dt)
	
	if self.doJointSearch then
		for i=1, table.getn(self.attacherVehicle.attachedImplements) do
			if self.attacherVehicle.attachedImplements[i].object == self then			
				local index = self.attacherVehicle.attachedImplements[i].jointDescIndex;
				local joint = self.attacherVehicle.attacherJoints[index];	
				if joint.powerShaftAttacher ~= nil then
					self.attacherVehiclePowerShaft = joint.powerShaftAttacher;
				end;
				if joint.hydrahoseAttacher ~= nil then
					self.attacherVehicleHose = joint.hydrahoseAttacher;
				end;
			end;
		end;
		self.doJointSearch = false;
	end;
	
	if self:getIsActive() then
		if self.attacherVehiclePowerShaft ~= nil and self.usePTO then		
			local ax, ay, az = getWorldTranslation(self.powerShaft.node);
			local bx, by, bz = getWorldTranslation(self.attacherVehiclePowerShaft);
			local x, y, z = worldDirectionToLocal(getParent(self.powerShaft.node), bx-ax, by-ay, bz-az);
			setDirection(self.powerShaft.node, x, y, z, 0, -1, 0);
			local distance = Utils.vector3Length(ax-bx, ay-by, az-bz);
			setTranslation(self.powerShaft.part, 0, 0, distance-self.powerShaft.distance);		
		end;
		if self.attacherVehicleHose ~= nil and self.useHose then		
			local ax, ay, az = getWorldTranslation(self.hose.node);
			local bx, by, bz = getWorldTranslation(self.attacherVehicleHose);
			local x, y, z = worldDirectionToLocal(getParent(self.hose.node), bx-ax, by-ay, bz-az);
			setDirection(self.hose.node, x, y, z, 0, 1, 0);
			local distance = Utils.vector3Length(ax-bx, ay-by, az-bz);
			setScale(self.hose.part, 1, 1, distance/self.hose.distance);
		end;		
	end;
	
	if self.enableManualPTOattach then
		if not self:getIsActive() and self.isAttached then
			if self.playerInRange then
				if InputBinding.hasEvent(InputBinding.ATTACH) then
					self:setPTO(not self.PTOId);
				end;
				if self.PTOId then
					g_currentMission:addHelpButtonText(string.format(g_i18n:getText("ATTACHPTO"), self.typeDesc), InputBinding.ATTACH);
				else
					g_currentMission:addHelpButtonText(string.format(g_i18n:getText("DETACHPTO"), self.typeDesc), InputBinding.ATTACH);
				end;
			end;
		end;
	end;
	
end;

function ImplementLinks:updateTick(dt)	

	if g_currentMission.player ~= nil and self.PTOdeattached ~= nil then
		local nearestDistance = 2.5;
		local x1,y1,z1 = getWorldTranslation(self.PTOdeattached);
		local x2,y2,z2 = getWorldTranslation(g_currentMission.player.rootNode);
		local distance = Utils.vector3Length(x1-x2,y1-y2,z1-z2);
		if distance < nearestDistance then
			self.playerInRange = true; 
		else
			self.playerInRange = false; 
		end;
	end;
end;

function ImplementLinks:draw()
end;

function ImplementLinks:onAttach(attacherVehicle)
	self.isAttached = true;
	self.doJointSearch = true;
end;

function ImplementLinks:onDetach()
	self.isAttached = false;
	self.PTOId = true;
	if self.PTOId then	
		setTranslation(self.powerShaft.part, unpack(self.powerShaft.trans));
		setRotation(self.powerShaft.node, unpack(self.powerShaft.rot));
		self.attacherVehiclePowerShaft = nil;
		if self.enableManualPTOattach then	
			setVisibility(self.PTOdeattached,true);
			setVisibility(self.PTOattached,false);
		end;
	end;
	setRotation(self.hose.node, unpack(self.hose.rot));
	setScale(self.hose.part, 1, 1, 1);
	self.attacherVehicleHose = nil;
end;


function ImplementLinks:setPTO(PTO, noEventSend)
	if PTO ~= self.PTOId then
		 if noEventSend == nil or noEventSend == false then
			  if g_server ~= nil then
				  g_server:broadcastEvent(PTOEvent:new(self, PTO), nil, nil, self);
			  else
				  g_client:getServerConnection():sendEvent(PTOEvent:new(self, PTO));
			  end;
		  end;	
		  
		self.PTOId = PTO;
		
		if not self.PTOId then
			setVisibility(self.PTOdeattached,false);
			setVisibility(self.PTOattached,true);
		elseif self.PTOId then
			setVisibility(self.PTOdeattached,true);
			setVisibility(self.PTOattached,false);
		end;
	end;
end;

PTOEvent = {};
PTOEvent_mt = Class(PTOEvent, Event);

InitEventClass(PTOEvent, "PTOEvent");

function PTOEvent:emptyNew()
    local self = Event:new(PTOEvent_mt);
    self.className="PTOEvent";
    return self;
end;

function PTOEvent:new(object, PTO)
    local self = PTOEvent:emptyNew()
    self.object = object;
	self.PTO = PTO;
    return self;
end;

function PTOEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
	self.PTO = streamReadBool(streamId);
    self.object = networkGetObject(id);
    self:run(connection);
end;

function PTOEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.object));	
	streamWriteBool(streamId, self.PTO);	
end;

function PTOEvent:run(connection)
	self.object:setPTO(self.PTO, true);
	if not connection:getIsServer() then
		g_server:broadcastEvent(PTOEvent:new(self.object, self.PTO), nil, connection, self.object);
	end;
end;
