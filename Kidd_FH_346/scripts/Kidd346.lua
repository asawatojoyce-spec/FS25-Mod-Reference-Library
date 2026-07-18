-- NI Modding
--
-- author  	Henly20 
-- date  	03-11-2012.
-- ni_modding@hotmail.com
-- http://nimodding.wordpress.com
  


Kidd346 = {};

function Kidd346.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Fillable, specializations) and SpecializationUtil.hasSpecialization(Attachable, specializations);
end;

function Kidd346:load(xmlFile)
    self.setIsTurnedOn = SpecializationUtil.callSpecializationsFunction("setIsTurnedOn");
    self.fillScale = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.fillScale#value"), 1);
    self.wasToFast = false;
    self.isTurnedOn = false;
	self.currentFruitType = FruitUtil.FRUITTYPE_UNKNOWN;
	
	self.lastArea = 0;
	self.lastAreaBiggerZero = self.lastArea > 0;

	self.pipeChaffParticleSystems = {};
    local i = 0;
    while true do
        local namei = string.format("vehicle.pipeChaffParticleSystems.pipeChaffParticleSystem(%d)", i);
		local nodei = Utils.indexToObject(self.components, getXMLString(xmlFile, namei .. "#index"));
		if nodei == nil then
			break;
		end; 
        Utils.loadParticleSystem(xmlFile, self.pipeChaffParticleSystems, namei, nodei, false, nil, self.baseDirectory)		
		Utils.setEmittingState(self.pipeChaffParticleSystems,false)
		i = i +1;		
    end;
	
	self.pipeGrassParticleSystems = {};
    local i = 0;
    while true do
        local namei = string.format("vehicle.pipeGrassParticleSystems.pipeGrassParticleSystem(%d)", i);
		local nodei = Utils.indexToObject(self.components, getXMLString(xmlFile, namei .. "#index"));
		if nodei == nil then
			break;
		end; 
        Utils.loadParticleSystem(xmlFile, self.pipeGrassParticleSystems, namei, nodei, false, nil, self.baseDirectory)		
		Utils.setEmittingState(self.pipeGrassParticleSystems,false)
		i = i +1;		
    end;
	
	self.isLoading = true;
	
      self.setPipeOpening = SpecializationUtil.callSpecializationsFunction("setPipeOpening");
      self.setPipeState = SpecializationUtil.callSpecializationsFunction("setPipeState");
      self.findAutoAimTrailerToUnload = Kidd346.findAutoAimTrailerToUnload;
      self.findTrailerToUnload = Kidd346.findTrailerToUnload;
      self.findTrailerRaycastCallback = Kidd346.findTrailerRaycastCallback;
      self.onTrailerTrigger = Kidd346.onTrailerTrigger;
  
      if self.isClient then

          local pipeSound = getXMLString(xmlFile, "vehicle.pipeSound#file");
          if pipeSound ~= nil and pipeSound ~= "" then
              pipeSound = Utils.getFilename(pipeSound, self.baseDirectory);
              self.pipeSound = createSample("pipeSound");
              loadSample(self.pipeSound, pipeSound, false);
              self.pipeSoundPitchOffset = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.pipeSound#pitchOffset"), 1);
              self.pipeSoundPitchScale = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.pipeSound#pitchScale"), 0);
              self.pipeSoundPitchMax = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.pipeSound#pitchMax"), 2.0);
          end;
      end;
 
      self.pipeNodes = {};
      self.numPipeStates = Utils.getNoNil(getXMLInt(xmlFile, "vehicle.pipe#numStates"), 2);
      self.currentPipeState = 1;
      self.targetPipeState = 1;
      self.pipeStateIsUnloading = {};
      self.pipeStateIsAutoAiming = {};
      local unloadingPipeStates = Utils.getVectorNFromString(getXMLString(xmlFile, "vehicle.pipe#unloadingStates"));
      if unloadingPipeStates ~= nil then
          for i=1, table.getn(unloadingPipeStates) do
              if unloadingPipeStates[i] ~= nil then
                  self.pipeStateIsUnloading[unloadingPipeStates[i] ] = true;
              end;
          end;
      end;
      local autoAimPipeStates = Utils.getVectorNFromString(getXMLString(xmlFile, "vehicle.pipe#autoAimStates"));
      if autoAimPipeStates ~= nil then
          for i=1, table.getn(autoAimPipeStates) do
              if autoAimPipeStates[i] ~= nil then
                  self.pipeStateIsAutoAiming[autoAimPipeStates[i] ] = true;
              end;
          end;
      end;
      local i = 0;
      while true do
          local key = string.format("vehicle.pipe.node(%d)", i);
          if not hasXMLProperty(xmlFile, key) then
              break;
          end;
          local node = Utils.indexToObject(self.components, getXMLString(xmlFile, key.."#index"));
          if node ~= nil then
              local entry = {};
              entry.node = node;
              entry.autoAimXRotation = Utils.getNoNil(getXMLBool(xmlFile, key.."#autoAimXRotation"), false);
              entry.autoAimYRotation = Utils.getNoNil(getXMLBool(xmlFile, key.."#autoAimYRotation"), false);
              entry.autoAimInvertZ = Utils.getNoNil(getXMLBool(xmlFile, key.."#autoAimInvertZ"), false);
              entry.states = {};
              for state=1,self.numPipeStates do
                  local stateKey = key..string.format(".state%d", state);
                  entry.states[state] = {};
                  local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, stateKey.."#translation"));
                  if x == nil or y == nil or z == nil then
                      x,y,z = getTranslation(node);
                  end;
                  entry.states[state].translation = {x,y,z};
                  local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, stateKey.."#rotation"));
                  if x == nil or y == nil or z == nil then
                      x,y,z = getRotation(node);
                  else
                      x,y,z = math.rad(x),math.rad(y),math.rad(z);
                  end;
                  entry.states[state].rotation = {x,y,z};
             end;
              local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, key.."#translationSpeeds"));
              if x ~= nil and y ~= nil and z ~= nil then
                  x,y,z = x*0.001,y*0.001,z*0.001;
                  if x ~= 0 or y ~= 0 or z ~= 0 then
                      entry.translationSpeeds = {x,y,z};
                  end;
              end;
              local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, key.."#rotationSpeeds"));
              if x ~= nil and y ~= nil and z ~= nil then
                  x,y,z = math.rad(x)*0.001,math.rad(y)*0.001,math.rad(z)*0.001;
                   if x ~= 0 or y ~= 0 or z ~= 0 then
                      entry.rotationSpeeds = {x,y,z};
                  end;
              end;
  
              local x,y,z = getTranslation(node);
              entry.curTranslation = {x,y,z};
              local x,y,z = getRotation(node);
              entry.curRotation = {x,y,z};
              table.insert(self.pipeNodes, entry);
          end;
          i = i + 1;
      end;
      if table.getn(self.pipeNodes) == 0 then
          -- use the old format
  
          local node = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.pipe#index"));
          if node ~= nil then
              self.numPipeStates = 2;
  
              local entry = {};
              entry.node = node;
              entry.states = {};
              entry.states[1] = {};
              entry.states[2] = {};
  
              local x,y,z = getRotation(node);
              entry.states[1].rotation = {0,0,z};
              entry.states[2].rotation = {math.rad(10),math.rad(-90),z};
  
              entry.rotationSpeeds = {0.00006, 0.0006, 0};
  
              local x,y,z = getRotation(node);
              entry.curRotation = {x,y,z};
  
              table.insert(self.pipeNodes, entry);
  
              self.pipeStateIsUnloading[2] = true;
          end;
      end;
  
      local pipeFlapLid = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.pipeFlapLid#index"));
      if pipeFlapLid ~= nil then
          if self.numPipeStates ~= 2 then
              print("Error: pipeFlapLid is only support with 2 pipe states in '"..self.configFileName.."'.");
          else
              local entry = {};
              entry.node = pipeFlapLid;
              entry.states = {};
              entry.states[1] = {};
              entry.states[2] = {};
  
              entry.states[1].rotation = {0,0,0};
              entry.states[2].rotation = {0,math.rad(-90),0};
 
              entry.rotationSpeeds = {0, 0.0006, 0};
  
              local x,y,z = getRotation(pipeFlapLid);
              entry.curRotation = {x,y,z};
  
              table.insert(self.pipeNodes, entry);
          end;
      end;
  
      if table.getn(self.pipeNodes) > 0 then
  
          self.pipeRaycastNode = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.pipe#raycastNodeIndex"));
   
          if self.pipeRaycastNode == nil then
              self.pipeRaycastNode = self.components[1].node;
          end;
      end;
      self.pipeRaycastDistance = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.pipe#raycastDistance"), 10);
	  
      self.onTrailerTrigger = Kidd346.onTrailerTrigger;
    
      self.aiTrailerTriggers = {};
  
      local i = 0;
      while true do
          local key = string.format("vehicle.aiTrailerTriggers.aiTrailerTrigger(%d)", i);
          if not hasXMLProperty(xmlFile, key) then
              break;
          end;
          local node = Utils.indexToObject(self.components, getXMLString(xmlFile, key.."#index"));
          local pipeState = getXMLInt(xmlFile, key.."#pipeState");
          if node ~= nil and pipeState ~= nil then
              self.aiTrailerTriggers[node] = {node=node, pipeState=pipeState};
          end;
          i = i + 1;
      end;
      local aiTrailerTrigger = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.aiTrailerTrigger#index"));
      if aiTrailerTrigger ~= nil then
          self.aiTrailerTriggers[aiTrailerTrigger] = {node=aiTrailerTrigger, pipeState=2};
      end;
      for _, aiTrailerTrigger in pairs(self.aiTrailerTriggers) do
          addTrigger(aiTrailerTrigger.node, "onTrailerTrigger", self);
      end;
  
    self.trailersInRange = {};
    self.isTrailerInRange = false;
    self.trailerInRangePipeState = 0;
    self.printWarningTime = 0;
	  
    if self.isClient then
        local workSound = getXMLString(xmlFile, "vehicle.workSound#file");
        if workSound ~= nil and workSound ~= "" then
            workSound = Utils.getFilename(workSound, self.baseDirectory);
            self.workSound = createSample("workSound");
            self.workSoundEnabled = false;
            loadSample(self.workSound, workSound, false);
            self.workSoundPitchOffset = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.workSound#pitchOffset"), 1);
            self.workSoundVolume = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.workSound#volume"), 1);
        end;
    end; 

	self.setTransRot = SpecializationUtil.callSpecializationsFunction("setTransRot");
	self.TransRotAnimation = getXMLString(xmlFile, "vehicle.TransRot#animationName");
	self.TransRot = false;
    self.setFruitOutput = SpecializationUtil.callSpecializationsFunction("setFruitOutput");	
	self.fruitOutputChange = true;	
    self.setVehicleRpmUp = SpecializationUtil.callSpecializationsFunction("setVehicleRpmUp");
    self.saveMinRpm = 0; 
    self.printWarningTime = 0;	
	
end;

function Kidd346:delete()
    if self.workSound ~= nil then
        delete(self.workSound);
    end;
    if self.pipeSound ~= nil then
        delete(self.pipeSound);
    end;
    for _, aiTrailerTrigger in pairs(self.aiTrailerTriggers) do
        removeTrigger(aiTrailerTrigger.node);
    end;
	Utils.deleteParticleSystem(self.pipeChaffParticleSystems);	
	Utils.deleteParticleSystem(self.pipeGrassParticleSystems);		
end;

function Kidd346:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if not resetVehicles then
		local isTransRotOn = Utils.getNoNil(getXMLBool(xmlFile, key.."#isTransRotOn"), true);
		if isTransRotOn ~= nil then
			self:setTransRot(isTransRotOn);
		end;
	end;
    return BaseMission.VEHICLE_LOAD_OK;
end;

function Kidd346:getSaveAttributesAndNodes(nodeIdent)
	local attributes = ' ';

	local mystring = 'isTransRotOn="' .. tostring(self.isTransRotOn) ..'"';	
	attributes = attributes .. mystring;

    local node = nil;
	return attributes, node;
end;

function Kidd346:readStream(streamId, connection)
    local turnedOn = streamReadBool(streamId);
    self:setIsTurnedOn(turnedOn, true);
    local fruitOut = streamReadBool(streamId);
    self:setFruitOutput(fruitOut, true);
	self.isLoading = true;
	self.lastAreaBiggerZero = streamReadBool(streamId);
	self.currentFruitType = streamReadInt8(streamId);
    local pipeState = streamReadUIntN(streamId, 3);
    self:setPipeState(pipeState, true);
    self:setTransRot(streamReadBool(streamId), true);
end;

function Kidd346:writeStream(streamId, connection)
    streamWriteBool(streamId, self.isTurnedOn);
    streamWriteBool(streamId, self.fruitOutputChange);
	streamWriteBool(streamId, self.lastAreaBiggerZero);
	streamWriteInt8(streamId, self.currentFruitType);
    streamWriteUIntN(streamId, self.targetPipeState, 3);
    streamWriteBool(streamId, self.TransRot);
end;

function Kidd346:readUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		self.lastAreaBiggerZero = streamReadBool(streamId);
		self.currentFruitType = streamReadInt8(streamId);
	end;
end;

function Kidd346:writeUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		streamWriteBool(streamId, self.lastAreaBiggerZero);
		streamWriteInt8(streamId, self.currentFruitType);
	end;
end;

function Kidd346:mouseEvent(posX, posY, isDown, isUp, button)
end;

function Kidd346:keyEvent(unicode, sym, modifier, isDown)
end;

function Kidd346:update(dt)
    if self:getIsActive() then 
		if self.isClient and self:getIsActiveForInput() and not self:hasInputConflictWithSelection() then
			if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA) and not self.PTOId then
				self:setIsTurnedOn(not self.isTurnedOn);
			end;
			if InputBinding.isPressed(InputBinding.IMPLEMENT_EXTRA) and self.PTOId then
				self.printWarningTime = self.time + 1000;
			end;
			if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA2) then
				self:setTransRot(not self.isTransRotOn);
			 end;	
			if InputBinding.hasEvent(InputBinding.TOGGLEOUPUT) then
				self:setFruitOutput(not self.fruitOutputChange);
			end;		 
		end;
        local doAutoAiming = self.pipeStateIsAutoAiming[self.currentPipeState];
        local targetTrailer = nil;
        if doAutoAiming then
            targetTrailer = self:findAutoAimTrailerToUnload(self.currentFruitType);
	
            if targetTrailer == nil then
                doAutoAiming = false;
            end;
        end;
        if (self.currentPipeState ~= self.targetPipeState or doAutoAiming) and self.targetPipeState <= self.numPipeStates then
            local autoAimX, autoAimY, autoAimZ;
            if doAutoAiming then
                autoAimX, autoAimY, autoAimZ = getWorldTranslation(targetTrailer.fillAutoAimTargetNode);
            end;
 
              local moved = false;
              for i=1, table.getn(self.pipeNodes) do
                  local nodeMoved = false;
                  local pipeNode = self.pipeNodes[i];
  
                  local state = pipeNode.states[self.targetPipeState];
                  if pipeNode.translationSpeeds ~= nil then
                      for i=1, 3 do
                          if pipeNode.curTranslation[i] ~= state.translation[i] then
                              nodeMoved = true;
                              if pipeNode.curTranslation[i] < state.translation[i] then
                                  pipeNode.curTranslation[i] = math.min(pipeNode.curTranslation[i] + dt*pipeNode.translationSpeeds[i], state.translation[i]);
                              else
                                  pipeNode.curTranslation[i] = math.max(pipeNode.curTranslation[i] - dt*pipeNode.translationSpeeds[i], state.translation[i]);
                              end;
                         end;
                     end;
                      setTranslation(pipeNode.node, pipeNode.curTranslation[1],pipeNode.curTranslation[2],pipeNode.curTranslation[3])
                  end;
                  if pipeNode.rotationSpeeds ~= nil then
                      for i=1, 3 do
                          local targetRotation = state.rotation[i];
                          if doAutoAiming then
                              if pipeNode.autoAimXRotation and i == 1 then
                                  local x,y,z = getWorldTranslation(pipeNode.node);
                                  local x,y,z = worldDirectionToLocal(getParent(pipeNode.node), autoAimX-x, autoAimY-y, autoAimZ-z);
                                  targetRotation = -math.atan2(y,z);
                                  if pipeNode.autoAimInvertZ then
                                      targetRotation = targetRotation+math.pi;
                                  end;
                                  targetRotation = Utils.normalizeRotationForShortestPath(targetRotation, pipeNode.curRotation[i]);
                              elseif pipeNode.autoAimYRotation and i == 2 then
                                  local x,y,z = getWorldTranslation(pipeNode.node);
                                  local x,y,z = worldDirectionToLocal(getParent(pipeNode.node), autoAimX-x, autoAimY-y, autoAimZ-z);
                                  targetRotation = math.atan2(x,z);
                                  if pipeNode.autoAimInvertZ then
                                      targetRotation = targetRotation+math.pi;
                                  end;
                                  targetRotation = Utils.normalizeRotationForShortestPath(targetRotation, pipeNode.curRotation[i]);
                              end;
                          end;
                          if pipeNode.curRotation[i] ~= targetRotation then
                              nodeMoved = true;
                              if pipeNode.curRotation[i] < targetRotation then
                                  pipeNode.curRotation[i] = math.min(pipeNode.curRotation[i] + dt*pipeNode.rotationSpeeds[i], targetRotation);
                              else
                                  pipeNode.curRotation[i] = math.max(pipeNode.curRotation[i] - dt*pipeNode.rotationSpeeds[i], targetRotation);
                              end;
                          end;
                      end;
                      setRotation(pipeNode.node, pipeNode.curRotation[1],pipeNode.curRotation[2],pipeNode.curRotation[3])
                  end;
                  moved = moved or nodeMoved;
  
                  if nodeMoved and self.setMovingToolDirty ~= nil then
                      self:setMovingToolDirty(pipeNode.node);
                  end;
              end;
              if not moved then
                  self.currentPipeState = self.targetPipeState;
              end;
          end;
  
          if self.isClient then
              if self.currentPipeState ~= self.targetPipeState then
                  if self.pipeSound ~= nil and not self.pipeSoundEnabled then
                      if self:getIsActiveForSound() then
                          setSamplePitch(self.pipeSound, self.pipeSoundPitchOffset);
                          playSample(self.pipeSound, 0, 1, 0);
                          self.pipeSoundEnabled = true;
                      end;
                  end;
              else
                  if self.pipeSound ~= nil and self.pipeSoundEnabled then
                      stopSample(self.pipeSound);
                      self.pipeSoundEnabled = false;
                  end;
              end;
          end;
	end;
	
	for i, jointDesc in pairs(self.componentJoints) do
	   setJointFrame(self.componentJoints[i].jointIndex, 0, self.componentJoints[i].jointNode);
	end;
end;

function Kidd346:updateTick(dt)
    self.wasToFast = false;
    self.lastArea = 0;
			
    if self:getIsActive() then
		if self.PTOId then
			self:setIsTurnedOn(false);
		end;
        self:setVehicleRpmUp(dt, self.isTurnedOn);		
        if not self.isTurnedOn then		
			self.currentFruitType = FruitUtil.FRUITTYPE_UNKNOWN;	
		end;
		local deltaLevel = 0;
        if self.isTurnedOn then
            local toFast = self:doCheckSpeedLimit() and self.attacherVehicle.lastSpeed*3600 > 20;
            if self.isServer then
                if not toFast then
                    local cuttingAreasSend = {};
                    for k, cuttingArea in pairs(self.cuttingAreas) do
                        if self:getIsAreaActive(cuttingArea) then
                            local x,y,z = getWorldTranslation(cuttingArea.start);
                            local x1,y1,z1 = getWorldTranslation(cuttingArea.width);
                            local x2,y2,z2 = getWorldTranslation(cuttingArea.height);
                            table.insert(cuttingAreasSend, {x,z,x1,z1,x2,z2});
                        end;
                    end;
                    if (table.getn(cuttingAreasSend) > 0) then
						local lastArea, fillType = CutAreaEvent.runLocally(cuttingAreasSend, self.fillTypes, self.currentFillType);
						self.lastArea = lastArea;
						self.lastAreaBiggerZero = (self.lastArea > 0);
						local pixelToSqm = g_currentMission:getFruitPixelsToSqm();
                        local sqm = lastArea*pixelToSqm;
						
							if lastArea > 0 then
								self.currentFruitType = FruitUtil.fillTypeToFruitType[fillType];

								local pixelToSqm = g_currentMission:getFruitPixelsToSqm();
								local literPerSqm = FruitUtil.fruitIndexToDesc[self.currentFruitType].literPerSqm;
								local sqm = lastArea * pixelToSqm;
								
								local deltaLevel = 0;		
								local fruitType = FruitUtil.fillTypeToFruitType[fillType]
								deltaLevel = sqm * literPerSqm * 8 * self.fillScale;								
								-- if self.currentFruitType == FruitUtil.FRUITTYPE_GRASS or self.currentFruitType == FruitUtil.FRUITTYPE_DRYGRASS then 
									-- deltaLevel = sqm * literPerSqm * 4 * self.fillScale;
								-- elseif self.currentFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
									-- deltaLevel = sqm * literPerSqm * 8 * self.fillScale;
								-- end;
								self.pipeIsUnloading = false;
								if self.pipeStateIsUnloading[self.currentPipeState] then
									if not self.fruitOutputChange then
										if self.currentFruitType == FruitUtil.FRUITTYPE_GRASS or self.currentFruitType == FruitUtil.FRUITTYPE_DRYGRASS then 
												local trailer = self:findTrailerToUnload(Fillable.FILLTYPE_GRASS_WINDROW);
												if trailer == nil then
													self.pipeIsUnloading = false;
												else
													if trailer:allowFillType(Fillable.FILLTYPE_GRASS_WINDROW) then
														trailer:resetFillLevelIfNeeded(Fillable.FILLTYPE_GRASS_WINDROW);
													end;
													trailer:setFillLevel(trailer.fillLevel+deltaLevel, Fillable.FILLTYPE_GRASS_WINDROW);
													self.pipeIsUnloading = true;						
												end;
										elseif self.currentFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
											local trailer = self:findTrailerToUnload(Fillable.FILLTYPE_CHAFF);
											if trailer == nil then
												self.pipeIsUnloading = false;
											else
												if trailer:allowFillType(Fillable.FILLTYPE_CHAFF) then
													trailer:resetFillLevelIfNeeded(Fillable.FILLTYPE_CHAFF);
												end;
												trailer:setFillLevel(trailer.fillLevel+deltaLevel, Fillable.FILLTYPE_CHAFF);
												self.pipeIsUnloading = true;
											end;
										end;
									else
										if self.currentFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
											local trailer = self:findTrailerToUnload(Fillable.FILLTYPE_CHAFF);
											if trailer == nil then
												self.pipeIsUnloading = false;
											else
												if trailer:allowFillType(Fillable.FILLTYPE_CHAFF) then
													trailer:resetFillLevelIfNeeded(Fillable.FILLTYPE_CHAFF);
												end;
												trailer:setFillLevel(trailer.fillLevel+deltaLevel, Fillable.FILLTYPE_CHAFF);
												self.pipeIsUnloading = true;
											end;
										end;
									end;	
								end;
								g_server:broadcastEvent(CutAreaEvent:new(cuttingAreasSend, fillType));
							end;
                    end;
                end;
            end;
            self.wasToFast = toFast;
        end;
		if self:getIsActive() then
			if self.isTurnedOn then
				if not self.workSoundEnabled and self:getIsActiveForSound() then
					playSample(self.workSound, 0, self.workSoundVolume, 0);
					setSamplePitch(self.workSound, self.workSoundPitchOffset);
					self.workSoundEnabled = true;
				end;
				self:setPipeState(2);
			else
				self:setPipeState(1);
				self.isTrailerInRange = false;			

			end;
			if not self.isTurnedOn then
				stopSample(self.workSound);
				self.workSoundEnabled = false;
			end;		
		end;	
		if self.isTurnedOn and self.attacherVehicle.lastSpeed*3600 < 20 and self.lastAreaBiggerZero then
			if not self.fruitOutputChange then
				if self.currentFruitType == FruitUtil.FRUITTYPE_GRASS or self.currentFruitType == FruitUtil.FRUITTYPE_DRYGRASS then 		
					Utils.setEmittingState(self.pipeGrassParticleSystems, true);	
					Utils.setEmittingState(self.pipeChaffParticleSystems, false);			
				else
					Utils.setEmittingState(self.pipeChaffParticleSystems, true);
					Utils.setEmittingState(self.pipeGrassParticleSystems, false);	
				end;
			else
				if self.currentFruitType == FruitUtil.FRUITTYPE_GRASS or self.currentFruitType == FruitUtil.FRUITTYPE_DRYGRASS then 		
					Utils.setEmittingState(self.pipeGrassParticleSystems, false);	
					Utils.setEmittingState(self.pipeChaffParticleSystems, true);			
				else
					Utils.setEmittingState(self.pipeChaffParticleSystems, true);
					Utils.setEmittingState(self.pipeGrassParticleSystems, false);	
				end;
			end;
		else
			Utils.setEmittingState(self.pipeChaffParticleSystems, false);
			Utils.setEmittingState(self.pipeGrassParticleSystems, false);			

		end;		
		
    end;
end;

function Kidd346:draw()
    if self:getIsActive() then
		if self.wasToFast then
			g_currentMission:addWarning(g_i18n:getText("Dont_drive_to_fast") .. "\n" .. string.format(g_i18n:getText("Cruise_control_levelN"), "1", InputBinding.getKeyNamesOfDigitalAction(InputBinding.SPEED_LEVEL1)), 0.07+0.022, 0.019+0.029);
		end;
        if not self.PTOId then 
			if self.isTurnedOn then
				g_currentMission:addHelpButtonText(string.format(g_i18n:getText("turn_off_OBJECT"), self.typeDesc), InputBinding.IMPLEMENT_EXTRA);
			else
				g_currentMission:addHelpButtonText(string.format(g_i18n:getText("turn_on_OBJECT"), self.typeDesc), InputBinding.IMPLEMENT_EXTRA);
			end;
		end;
		if self.printWarningTime > self.time then
			g_currentMission:addWarning(g_i18n:getText("turnON_Error"), 0.018, 0.033);
		end;
        if self.isTransRotOn then
            g_currentMission:addHelpButtonText(string.format(g_i18n:getText("TRANSPORT"), self.typeDesc), InputBinding.IMPLEMENT_EXTRA2);
        else
            g_currentMission:addHelpButtonText(string.format(g_i18n:getText("FIELD"), self.typeDesc), InputBinding.IMPLEMENT_EXTRA2);
        end;
        if (self.currentFruitType == FruitUtil.FRUITTYPE_GRASS or self.currentFruitType == FruitUtil.FRUITTYPE_DRYGRASS) or self.currentFruitType == FruitUtil.FRUITTYPE_UNKNOWN then		
			if self.fruitOutputChange then
				g_currentMission:addHelpButtonText(string.format(g_i18n:getText("Chaff"), self.typeDesc), InputBinding.TOGGLEOUPUT);
			else
				g_currentMission:addHelpButtonText(string.format(g_i18n:getText("Grass"), self.typeDesc), InputBinding.TOGGLEOUPUT);			
			end;		
		end;
		if self.isClient then
			if self.currentFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
				g_currentMission:setFruitOverlayFruitType(self.currentFruitType);
			end;
		end;
	end;
end;

function Kidd346:onDetach()
	Utils.setEmittingState(self.pipeChaffParticleSystems, false);
	Utils.setEmittingState(self.pipeGrassParticleSystems, false);
    if self.deactivateOnDetach then
        Kidd346.onDeactivate(self);
    else
    end;
    for _, aiTrailerTrigger in pairs(self.aiTrailerTriggers) do
        removeTrigger(aiTrailerTrigger.node);
    end;
    self.isTrailerInRange = false;
	self.isTurnedOn	= false;
	self.currentFruitType = FruitUtil.FRUITTYPE_UNKNOWN;
    for k, steerable in pairs(g_currentMission.steerables) do
        if self.attacherVehicleCopy == steerable then
            steerable.motor.minRpm = self.saveMinRpm;
            self.attacherVehicleCopy = nil;
        end;
    end;	
end;

function Kidd346:onAttach(attacherVehicle)
    for _, aiTrailerTrigger in pairs(self.aiTrailerTriggers) do
        addTrigger(aiTrailerTrigger.node, "onTrailerTrigger", self);
    end;
    if self.attacherVehicleCopy == nil then
        self.attacherVehicleCopy = self.attacherVehicle;
    end;
    self.saveMinRpm = self.attacherVehicle.motor.minRpm;	
end;

function Kidd346:onLeave()
	Utils.setEmittingState(self.pipeChaffParticleSystems, false);
	Utils.setEmittingState(self.pipeGrassParticleSystems, false);
    if self.deactivateOnLeave then
        Kidd346.onDeactivate(self);
    else
       Kidd346.onDeactivateSounds(self)
    end;
end;

function Kidd346:onDeactivate()
	Utils.setEmittingState(self.pipeChaffParticleSystems, false);
	Utils.setEmittingState(self.pipeGrassParticleSystems, false);
    self.isTurnedOn = false;
    Kidd346.onDeactivateSounds(self);
end;

function Kidd346:onDeactivateSounds()
      if self.pipeSound ~= nil and self.pipeSoundEnabled then
          stopSample(self.pipeSound);
          self.pipeSoundEnabled = false;
      end;
      if self.workSoundEnabled then
          stopSample(self.workSound);
          self.workSoundEnabled = false;
      end;
 end;

function Kidd346:setIsTurnedOn(turnedOn, noEventSend)
    SetTurnedOnEvent.sendEvent(self, turnedOn, noEventSend)
    self.isTurnedOn = turnedOn;
end;

function Kidd346:setFruitOutput(fruitOut, noEventSend)
	FruitOutputEvent.sendEvent(self, fruitOut, noEventSend);
	self.fruitOutputChange = fruitOut;
end;

function Kidd346:setPipeOpening(pipeOpening, noEventSend)
      if pipeOpening then
          self:setPipeState(2, noEventSend);
      else
          self:setPipeState(1, noEventSend);
      end;
end;

function Kidd346:setVehicleRpmUp(dt, isActive)
    if self.attacherVehicle ~= nil and self.saveMinRpm ~= 0 then
        if dt ~= nil then
            if isActive == true then
                self.attacherVehicle.motor.minRpm = math.max(self.attacherVehicle.motor.minRpm-dt, -1000);
            else
                self.attacherVehicle.motor.minRpm = math.min(self.attacherVehicle.motor.minRpm+dt*2, self.saveMinRpm);
            end;
        else
            self.attacherVehicle.motor.minRpm = self.saveMinRpm;
        end;
        if self.attacherVehicle.isMotorStarted then
            local fuelUsed = 0.00000011*math.abs(self.attacherVehicle.motor.minRpm);
            self.attacherVehicle:setFuelFillLevel(self.attacherVehicle.fuelFillLevel-fuelUsed);
            g_currentMission.missionStats.fuelUsageTotal = g_currentMission.missionStats.fuelUsageTotal + fuelUsed;
            g_currentMission.missionStats.fuelUsageSession = g_currentMission.missionStats.fuelUsageSession + fuelUsed;
        end;
    end;
end;

  
function Kidd346:setPipeState(pipeState, noEventSend)
      if self.targetPipeState ~= pipeState then
          if noEventSend == nil or noEventSend == false then
              if g_server ~= nil then
                  g_server:broadcastEvent(SetPipeStateEvent:new(self, pipeState));
              else
                  g_client:getServerConnection():sendEvent(SetPipeStateEvent:new(self, pipeState), nil, nil, self);
              end;
          end;
          self.targetPipeState = pipeState;
          self.currentPipeState = 0;
      end;
end;
 
function Kidd346:findAutoAimTrailerToUnload(fruitType)
    local trailer = nil;

    local smallestTrailerId = nil;
    if self.trailersInRange ~= nil then
        for trailerInRange, pipeStage in pairs(self.trailersInRange) do
            if (trailerInRange:allowFillType(Fillable.FILLTYPE_GRASS_WINDROW) or trailerInRange:allowFillType(Fillable.FILLTYPE_CHAFF)) and trailerInRange.allowFillFromAir and trailerInRange.fillLevel < trailerInRange.capacity then
                local id = networkGetObjectId(trailerInRange);
                if trailer == nil or id < smallestTrailerId then
                    trailer = trailerInRange;
                    smallestTrailerId = id;
                end;
            end;
		end;
	end;
    return trailer;
end;
  
function Kidd346:findTrailerToUnload(fruitType)
  
      local x,y,z = getWorldTranslation(self.pipeRaycastNode);
      local dx,dy,dz = localDirectionToWorld(self.pipeRaycastNode, 0,-1,0);
  
      self.trailerFound = 0;
      raycastAll(x, y, z, dx,dy,dz, "findTrailerRaycastCallback", self.pipeRaycastDistance, self);
		
      local trailer = g_currentMission.nodeToVehicle[self.trailerFound];
      if trailer == nil or not (trailer:allowFillType(Fillable.FILLTYPE_GRASS_WINDROW) or trailer:allowFillType(Fillable.FILLTYPE_CHAFF)) or not trailer.allowFillFromAir or trailer.fillLevel >= trailer.capacity then
          return nil;
      end;
      return trailer;
	  

end;
  
function Kidd346:findTrailerRaycastCallback(transformId, x, y, z, distance)
 
    local vehicle = g_currentMission.nodeToVehicle[transformId];
    if vehicle ~= nil then
		if vehicle.exactFillRootNode == transformId then
			self.trailerFound = transformId;
			return false;
		end;
    end;
    return true;
end;

function Kidd346:onTrailerTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
      if onEnter or onLeave then
          local trailer = g_currentMission.nodeToVehicle[otherId];
          if trailer ~= nil and trailer.fillRootNode ~= nil then
             if onEnter or onStay then
                  self.trailersInRange[trailer] = self.aiTrailerTriggers[triggerId].pipeState;
                  self.trailerInRangePipeState = math.max(self.trailerInRangePipeState, self.aiTrailerTriggers[triggerId].pipeState);
                  self.isTrailerInRange = true;
            elseif onLeave then
                  self.trailersInRange[trailer] = nil;
                  self.isTrailerInRange = false;
                  self.trailerInRangePipeState = 0;
                  for trailer, pipeState in pairs(self.trailersInRange) do
                      self.trailerInRangePipeState = math.max(self.trailerInRangePipeState, pipeState);
                      self.isTrailerInRange = false;
                 end;
              end;
          end;
      end; 

end;

function Kidd346:setTransRot(isTransRot,noEventSend)
	SetTransRotEvent.sendEvent(self, isTransRot, noEventSend);
	-- Play TransRot animation --
	self.isTransRotOn = isTransRot;
	if self.isTransRotOn then
		if self.TransRotAnimation ~= nil and self.playAnimation ~= nil then
			self:playAnimation(self.TransRotAnimation, 1, nil, true);
			self.TransRot = true;
		end;
	else
		if self.TransRotAnimation ~= nil and self.playAnimation ~= nil then
			self:playAnimation(self.TransRotAnimation, -1, nil, true);
			self.TransRot = false;
		end;
	end;	
end;

SetTransRotEvent = {};
SetTransRotEvent_mt = Class(SetTransRotEvent, Event);

InitEventClass(SetTransRotEvent, "SetTransRotEvent");

function SetTransRotEvent:emptyNew()
    local self = Event:new(SetTransRotEvent_mt);
    self.className="SetTransRotEvent";
    return self;
end;

function SetTransRotEvent:new(vehicle, isTransRot)
    local self = SetTransRotEvent:emptyNew()
    self.vehicle = vehicle;
	self.isTransRot = isTransRot;
    return self;
end;

function SetTransRotEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
	self.isTransRot = streamReadBool(streamId);
    self.vehicle = networkGetObject(id);
    self:run(connection);
end;

function SetTransRotEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteBool(streamId, self.isTransRot);
end;

function SetTransRotEvent:run(connection)   
	self.vehicle:setTransRot(self.isTransRot, true);
    if not connection:getIsServer() then
        g_server:broadcastEvent(SetTransRotEvent:new(self.vehicle, self.isTransRot), nil, connection, self.vehicle);
    end;
end;

function SetTransRotEvent.sendEvent(vehicle, isTransRot, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(SetTransRotEvent:new(vehicle, isTransRot), nil, nil, vehicle);
		else
			g_client:getServerConnection():sendEvent(SetTransRotEvent:new(vehicle, isTransRot));
		end;
	end;
end;

SetPipeStateEvent = {};
SetPipeStateEvent_mt = Class(SetPipeStateEvent, Event);
  
InitEventClass(SetPipeStateEvent, "SetPipeStateEvent");
  
function SetPipeStateEvent:emptyNew()
      local self = Event:new(SetPipeStateEvent_mt);
      self.className = "SetPipeStateEvent";
      return self;
end;
  
function SetPipeStateEvent:new(object, pipeState)
      local self = SetPipeStateEvent:emptyNew()
      self.object = object;
      self.pipeState = pipeState;
      assert(self.pipeState >= 0 and self.pipeState < 8);
      return self;
end;
  
function SetPipeStateEvent:readStream(streamId, connection)
      local id = streamReadInt32(streamId);
      self.pipeState = streamReadUIntN(streamId, 3);
      self.object = networkGetObject(id);
      self:run(connection);
end;
  
function SetPipeStateEvent:writeStream(streamId, connection)
      streamWriteInt32(streamId, networkGetObjectId(self.object));
      streamWriteUIntN(streamId, self.pipeState, 3);
end;
  
function SetPipeStateEvent:run(connection)
      self.object:setPipeState(self.pipeState, true);
      if not connection:getIsServer() then
          g_server:broadcastEvent(SetPipeStateEvent:new(self.object, self.pipeState), nil, connection, self.object);
      end;
end;

FruitOutputEvent = {};
FruitOutputEvent_mt = Class(FruitOutputEvent, Event);
  
InitEventClass(FruitOutputEvent, "FruitOutputEvent");
  
function FruitOutputEvent:emptyNew()
     local self = Event:new(FruitOutputEvent_mt);
      self.className="FruitOutputEvent";
      return self;
end;
  
function FruitOutputEvent:new(object, fruitOut)
      local self = FruitOutputEvent:emptyNew()
      self.object = object;
      self.fruitOut = fruitOut;
      return self;
end;
  
function FruitOutputEvent:readStream(streamId, connection)
      local id = streamReadInt32(streamId);
      self.fruitOut = streamReadBool(streamId);
      self.object = networkGetObject(id);
      self:run(connection);
end;
  
function FruitOutputEvent:writeStream(streamId, connection)
      streamWriteInt32(streamId, networkGetObjectId(self.object));
      streamWriteBool(streamId, self.fruitOut);
end;
  
function FruitOutputEvent:run(connection)
      if not connection:getIsServer() then
         g_server:broadcastEvent(self, false, connection, self.object);
      end;
      self.object:setFruitOutput(self.fruitOut, true);
end;
  
function FruitOutputEvent.sendEvent(vehicle, fruitOut, noEventSend)
      if fruitOut ~= vehicle.fruitOutputChange then
          if noEventSend == nil or noEventSend == false then
              if g_server ~= nil then
                  g_server:broadcastEvent(FruitOutputEvent:new(vehicle, fruitOut), nil, nil, vehicle);
              else
                  g_client:getServerConnection():sendEvent(FruitOutputEvent:new(vehicle, fruitOut));
              end;
          end;
      end;
end;
