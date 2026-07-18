AnimationHitch = {};

function AnimationHitch.prerequisitesPresent(specializations)
    return true;
end;

function AnimationHitch:load(xmlFile)

	self.setAnimationTime = SpecializationUtil.callSpecializationsFunction("setAnimationTime");
	
	self.animationParts = {};
	local i = 0;
	while true do
		local partName = string.format("vehicle.animationParts.animationPart(%d)", i);
		local animationPart = {};
		local partStr = getXMLString(xmlFile, partName .. "#rootNode");
		if partStr == nil then
            break;
        end;
        animationPart.rootNode = Utils.indexToObject(self.components, partStr);
		local charSet = getAnimCharacterSet(animationPart.rootNode);
		if charSet == nil then
			print("Error: invalid animation rootNode " .. partStr);
			break;
		else
			animationPart.animCharSet = charSet;
			animationPart.clip = getAnimClipIndex(animationPart.animCharSet, getXMLString(xmlFile, partName.."#clipName"));
			assignAnimTrackClip(animationPart.animCharSet, 0, animationPart.clip);
			animationPart.clipSpeed = Utils.getNoNil(getXMLFloat(xmlFile, partName .. "#clipSpeed"), 1);
			setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, animationPart.clipSpeed);
			animationPart.loop = Utils.getNoNil(getXMLBool(xmlFile, partName.."#loop"), false);
			setAnimTrackLoopState(animationPart.animCharSet, 0, animationPart.loop);
			animationPart.startPosition =  Utils.getNoNil(getXMLInt(xmlFile, partName .. "#startPosition"), 0);
			animationPart.currentPosition = animationPart.startPosition;
			setAnimTrackTime(animationPart.animCharSet, 0, animationPart.currentPosition);
			animationPart.accerlation = Utils.getNoNil(getXMLFloat(xmlFile, partName .. "#accerlation"), 0);
			animationPart.deAccerlation = Utils.getNoNil(getXMLFloat(xmlFile, partName .. "#deAccerlation"), 0)*-1;
			animationPart.loopSpeed = 0;
			local numJoints = Utils.getNoNil(getXMLInt(xmlFile, partName .. "#numJoints"), 0); 
			if numJoints > 0 then
				animationPart.joints = {};
				for j=1, numJoints do
					local jointString = string.format("%s.componentJoint%d", partName, j);
					local index = Utils.getNoNil(getXMLInt(xmlFile, jointString .."#index"), 0);
					if index == 0 then 
						print("Error: Invalid ComponenteJointIndex: "..index.."");
						break;
					end;
					local jointIndex = self.componentJoints[index];
					setJointFrame(jointIndex.jointIndex, 0, jointIndex.jointNode);
					table.insert(animationPart.joints, jointIndex);
				end;
			end;
			animationPart.offSet = Utils.getNoNil(getXMLInt(xmlFile, partName .. "#offSet"), 50);
			animationPart.loadSave = Utils.getNoNil(getXMLBool(xmlFile, partName.."#loadSave"), false);
			animationPart.animDuration = getAnimClipDuration(animationPart.animCharSet, animationPart.clip);
			if animationPart.currentPosition >= animationPart.animDuration then
				print("Error: Animation Part"..i.." startPosition larger or exakt then animation clip duration!");
				break;
			end;
			animationPart.animationEnabled = false;
			animationPart.inputTime = animationPart.currentPosition;
			animationPart.inputDone = false;
			animationPart.clipEndTime = false;
			animationPart.clipStartTime = false;
			animationPart.isLoading = false;
			table.insert(self.animationParts, animationPart);
        end;
        i = i + 1;
    end;
end;

function AnimationHitch:delete()
end;

function AnimationHitch:getSaveAttributesAndNodes(nodeIdent)
	local attributes = nil;
	for k, animationPart in pairs(self.animationParts) do
		if animationPart.loadSave then
			local minTime = math.max(animationPart.currentPosition, 0);
			local maxTime = math.min(minTime, animationPart.animDuration);
			local currentTime = string.format("%d", maxTime);
			local saveAttributes = "animation" .. k .. "=\"" .. currentTime .. "\""
			if k > 1 then
				attributes = attributes .. " " .. saveAttributes;
			else
				attributes = saveAttributes;
			end;
		end;
	end;
	return attributes, nil;
end;

function AnimationHitch:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if not resetVehicles then
		for k, animationPart in pairs(self.animationParts) do
			local keyString = string.format("#animation%d", k);
			local inputTime = Utils.getNoNil(getXMLInt(xmlFile, key .. keyString), animationPart.startPosition);
			self:setAnimationTime(k, inputTime, true);
			animationPart.isLoading = animationPart.loadSave;
		end;
	end;
	return BaseMission.VEHICLE_LOAD_OK;
end;

function AnimationHitch:readStream(streamId, connection)
	for k, animationPart in pairs(self.animationParts) do
		local timeInput = streamReadInt32(streamId);
		self:setAnimationTime(k, timeInput, true);
		animationPart.isLoading = true;
	end;
end;

function AnimationHitch:writeStream(streamId, connection)
	for k, animationPart in pairs(self.animationParts) do
		streamWriteInt32(streamId, animationPart.inputTime);
	end;
end;

function AnimationHitch:mouseEvent(posX, posY, isDown, isUp, button)
end;

function AnimationHitch:keyEvent(unicode, sym, modifier, isDown)
end;

function AnimationHitch:update(dt)
	if self:getIsActiveForInput() then

			if InputBinding.isPressed(InputBinding.HITCHUPFH) and self:getIsActiveForInput() then
				self:setAnimationTime(1, self.animationParts[1].currentPosition+(self.animationParts[1].offSet*(dt/5)));
			elseif InputBinding.isPressed(InputBinding.HITCHDOWNFH) and self:getIsActiveForInput() then
				self:setAnimationTime(1, self.animationParts[1].currentPosition-(self.animationParts[1].offSet*(dt/5)));
			end;
	end
end;

function AnimationHitch:updateTick(dt)
	for k, animationPart in pairs(self.animationParts) do
		if animationPart.animationEnabled then
			local currentTime = animationPart.currentPosition;
			local timeInput = animationPart.inputTime;
			local clipSpeed = animationPart.clipSpeed;
			local loopState = animationPart.loop;
			local duration = animationPart.animDuration;
			local accerlationSpeed = animationPart.loopSpeed;
			if animationPart.isLoading then
				clipSpeed = animationPart.clipSpeed*animationPart.offSet;
				animationPart.isLoading = false;
			end;
			if loopState == true then
				if timeInput ~= 0 then
					if animationPart.accerlation ~= 0 then
						accerlationSpeed = math.min(accerlationSpeed+((accerlationSpeed+animationPart.accerlation)*animationPart.accerlation), clipSpeed);
						setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, accerlationSpeed);
						if accerlationSpeed >= clipSpeed then
							animationPart.inputDone = true;
							animationPart.loopSpeed = clipSpeed;
						else
							animationPart.loopSpeed = accerlationSpeed;
						end;
					else
						setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, clipSpeed);
						animationPart.inputDone = true;
					end;
				elseif timeInput == 0 then
					if animationPart.deAccerlation ~= 0 then
						accerlationSpeed = math.max(accerlationSpeed+(accerlationSpeed*animationPart.deAccerlation), 0);
						setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, accerlationSpeed);
						if accerlationSpeed <= 0 then
							animationPart.inputDone = true;
							animationPart.loopSpeed = 0;
						else
							animationPart.loopSpeed = accerlationSpeed;
						end;
					else
						setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, 0);
						disableAnimTrack(animationPart.animCharSet, animationPart.clip);
						animationPart.inputDone = true;
					end;
				end;
				renderText(0.01, 0.01, 0.03, string.format("accerlationSpeed: %f", accerlationSpeed));
			elseif loopState == false then
				if currentTime < timeInput and animationPart.inputDone == false then
					setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, clipSpeed);
					if currentTime+animationPart.offSet >= timeInput then
						animationPart.inputDone = true;
						setAnimTrackTime(animationPart.animCharSet, animationPart.clip, timeInput);
						setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, 0);
					end;
				elseif currentTime > timeInput and animationPart.inputDone == false then
					setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, -clipSpeed);
					if currentTime-animationPart.offSet <= timeInput then
						animationPart.inputDone = true;
						setAnimTrackTime(animationPart.animCharSet, animationPart.clip, timeInput);
						setAnimTrackSpeedScale(animationPart.animCharSet, animationPart.clip, 0);
					end;
				end;
				if currentTime >= duration-animationPart.offSet then
					animationPart.clipEndTime = true;
				elseif currentTime <= animationPart.offSet then
					animationPart.clipStartTime = true;
				elseif currentTime == animationPart.startPosition then
					animationPart.clipStartTime = true;
				else
					animationPart.clipStartTime = false;
					animationPart.clipEndTime = false;
				end;
			end;
			if animationPart.joints ~= nil then
				for k, joint in pairs(animationPart.joints) do
					setJointFrame(joint.jointIndex, 0, joint.jointNode);
				end;
			end;
			animationPart.currentPosition = getAnimTrackTime(animationPart.animCharSet, animationPart.clip);
		else
			enableAnimTrack(animationPart.animCharSet, animationPart.clip);
		end;
		animationPart.animationEnabled = isAnimTrackEnabled(animationPart.animCharSet, animationPart.clip);
	end;
end;

function AnimationHitch:setAnimationTime(animationPart, timeInput, noEventSend)
	local minTime = math.max(timeInput, 0);
	local maxTime = math.min(minTime, self.animationParts[animationPart].animDuration);
	SetAnimationEvent.sendEvent(self, animationPart, maxTime, noEventSend);
	if maxTime ~= self.animationParts[animationPart].currentPosition then
		self.animationParts[animationPart].inputDone = false;
		self.animationParts[animationPart].inputTime = maxTime;
	end;
end;

function AnimationHitch:draw()	
	if self:getIsActive() then
			g_currentMission:addExtraPrintText("Key [ ]             	          	    Move Hitch Up/Down");
	end;
end;

function AnimationHitch:validateAttacherJoint(implement, jointDesc, dt)
    return true;
end;

SetAnimationEvent = {};
SetAnimationEvent_mt = Class(SetAnimationEvent, Event);

InitEventClass(SetAnimationEvent, "SetAnimationEvent");

function SetAnimationEvent:emptyNew()
    local self = Event:new(SetAnimationEvent_mt);
    self.className = "SetAnimationEvent";
    return self;
end;

function SetAnimationEvent:new(object, animationIndex, inputTime)
    local self = SetAnimationEvent:emptyNew()
    self.object = object;
	self.animationIndex = animationIndex;
	self.inputTime = inputTime;
    return self;
end;

function SetAnimationEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
	self.object = networkGetObject(id);
	self.animationIndex = streamReadInt32(streamId);
	self.inputTime = streamReadInt32(streamId);
    self:run(connection);
end;

function SetAnimationEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.object));
	streamWriteInt32(streamId, self.animationIndex);
	streamWriteInt32(streamId, self.inputTime);
end;

function SetAnimationEvent:run(connection)
	self.object:setAnimationTime(self.animationIndex, self.inputTime, true)
	if not connection:getIsServer() then
		g_server:broadcastEvent(SetAnimationEvent:new(self.object, self.animationIndex, self.inputTime), nil, connection, self.object);
	end;
end;

function SetAnimationEvent.sendEvent(vehicle, animationIndex, inputTime, noEventSend)
	local animationPart = vehicle.animationParts[animationIndex];
	if animationPart ~= nil then
		if inputTime ~= vehicle.animationParts[animationIndex].inputTime then
			if noEventSend == nil or noEventSend == false then
				if g_server ~= nil then
					g_server:broadcastEvent(SetAnimationEvent:new(vehicle, animationIndex, inputTime), nil, nil, vehicle);
				else
					g_client:getServerConnection():sendEvent(SetAnimationEvent:new(vehicle, animationIndex, inputTime));
				end;
			end;
		end;
	end;
end;

