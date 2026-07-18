CutAreaEvent = {};
CutAreaEvent_mt = Class(CutAreaEvent, Event);

InitEventClass(CutAreaEvent, "CutAreaEvent");

function CutAreaEvent:emptyNew()
    local self = Event:new(CutAreaEvent_mt);
    self.className="CutAreaEvent";
    return self;
end;

function CutAreaEvent:new(cuttingAreas, fruitType)
    local self = CutAreaEvent:emptyNew()
    self.cuttingAreas = cuttingAreas;
    self.fruitType = fruitType;
    return self;
end;

function CutAreaEvent:readStream(streamId, connection)
    local fruitType = streamReadInt8(streamId);
    local _fruitType = FruitUtil.fillTypeToFruitType[fruitType];
    local numAreas = streamReadUIntN(streamId, 4);

    local refX = streamReadFloat32(streamId);
    local refY = streamReadFloat32(streamId);
    local values = Utils.readCompressed2DVectors(streamId, refX, refY, numAreas*3-1, 0.01, true);
    for i=1,numAreas do
        local vi = i-1;
        local x = values[vi*3+1].x;
        local z = values[vi*3+1].y;
        local x1 = values[vi*3+2].x;
        local z1 = values[vi*3+2].y;
        local x2 = values[vi*3+3].x;
        local z2 = values[vi*3+3].y;
		Utils.updateFruitCutShortArea(_fruitType, x, z, x1, z1, x2, z2, 1);	
		Utils.cutFruitArea(_fruitType, x, z, x1, z1, x2, z2, true, true);
		Utils.updateFruitWindrowArea(_fruitType, x, z, x1, z1, x2, z2, 0);
		Utils.updateFruitCutLongArea(_fruitType, x, z, x1, z1, x2, z2, 0);
		if fruitType == FruitUtil.FRUITTYPE_GRASS or fruitType == FruitUtil.FRUITTYPE_DRYGRASS then
			Utils.switchFruitTypeArea(FruitUtil.FRUITTYPE_GRASS, FruitUtil.FRUITTYPE_DRYGRASS, x, z, x1, z1, x2, z2, 1)
		end;
    end;
end;

function CutAreaEvent:writeStream(streamId, connection)
    streamWriteInt8(streamId,self.fruitType);
    local numAreas = table.getn(self.cuttingAreas);
    streamWriteUIntN(streamId, numAreas, 4);
    local refX, refY;
    local values = {};
    for i=1, numAreas do
        local d = self.cuttingAreas[i];
        if i==1 then
            refX = d[1];
            refY = d[2];
            streamWriteFloat32(streamId, d[1]);
            streamWriteFloat32(streamId, d[2]);
        else
            table.insert(values, {x=d[1], y=d[2]});
        end;
        table.insert(values, {x=d[3], y=d[4]});
        table.insert(values, {x=d[5], y=d[6]});
    end;
    assert(table.getn(values) == numAreas*3 - 1);
    Utils.writeCompressed2DVectors(streamId, refX, refY, values, 0.01);
end;

function CutAreaEvent:run(connection)
    print("Error: Do not run CutAreaEvent locally");
end;

function CutAreaEvent.runLocally(cuttingAreas, fillTypes, currentFillType)
    local numAreas = table.getn(cuttingAreas);
    local refX, refY;
    local values = {};
    for i=1, numAreas do
        local d = cuttingAreas[i];
        if i==1 then
            refX = d[1];
            refY = d[2];
        else
            table.insert(values, {x=d[1], y=d[2]});
        end;
        table.insert(values, {x=d[3], y=d[4]});
        table.insert(values, {x=d[5], y=d[6]});
    end;
    assert(table.getn(values) == numAreas*3 - 1);
    local values = Utils.simWriteCompressed2DVectors(refX, refY, values, 0.01, true);
    local area = 0;
    for i=1, numAreas do
		local vi = i-1;
		local x = values[vi*3+1].x;
		local z = values[vi*3+1].y;
		local x1 = values[vi*3+2].x;
		local z1 = values[vi*3+2].y;
		local x2 = values[vi*3+3].x;
		local z2 = values[vi*3+3].y;
		for fruitType,v in pairs(fillTypes) do
			if fruitType ~= Fillable.FILLTYPE_UNKNOWN then
				if currentFillType == fruitType or currentFillType == Fillable.FILLTYPE_UNKNOWN then
					local _fruitType = FruitUtil.fillTypeToFruitType[fruitType];
					Utils.updateFruitCutShortArea(_fruitType, x, z, x1, z1, x2, z2, 1);
					local area = Utils.cutFruitArea(_fruitType, x, z, x1, z1, x2, z2, true, true);
					area = area + Utils.updateFruitWindrowArea(_fruitType, x, z, x1, z1, x2, z2, 0);
					area = area + Utils.updateFruitCutLongArea(_fruitType, x, z, x1, z1, x2, z2, 0);
					
					if area > 0 then
						if fruitType == FruitUtil.FRUITTYPE_GRASS or fruitType == FruitUtil.FRUITTYPE_DRYGRASS then
							Utils.switchFruitTypeArea(FruitUtil.FRUITTYPE_GRASS, FruitUtil.FRUITTYPE_DRYGRASS, x, z, x1, z1, x2, z2, 1)
						end;
						return area, fruitType;
					end;						
				end;
			end;
		end;
    end;
    return area, fruitType;
end;