local EntityWatcher = require("EntityWatcher")
local WeaponSystem = require("WeaponSystem")
local GUI = require("GUI")
local MiniGameUISystem = InitMiniGameUISystem()
--local DEBUG=true
-----------------------------------------------------------------------------------------Common Function--------------------------------------------------------------------------------
local function assert(boolean, message)
    if not boolean then
        echo(
            "devilwalk",
            "devilwalk----------------------------------------------------------------assert failed!!!!:message:" ..
                tostring(message)
        )
    end
end
local function getDebugStack()
    if DEBUG then
        return debug.stack(nil, true)
    end
end
local function clone(from)
    local ret
    if type(from) == "table" then
        ret = {}
        for key, value in pairs(from) do
            ret[key] = clone(value)
        end
    else
        ret = from
    end
    return ret
end
local function new(class, parameters)
    local new_table = {}
    setmetatable(new_table, {__index = class})
    for key, value in pairs(class) do
        new_table[key] = clone(value)
    end
    local list = {}
    local dst = new_table
    while dst do
        list[#list + 1] = dst
        dst = dst._super
    end
    for i = #list, 1, -1 do
        list[i].construction(new_table, parameters)
    end
    return new_table
end
local function delete(inst)
    if inst then
        local list = {}
        local dst = inst
        while dst do
            list[#list + 1] = dst
            dst = dst._super
        end
        for i = 1, #list do
            list[i].destruction(inst)
        end
    end
end
local function inherit(class)
    local new_table = {}
    setmetatable(new_table, {__index = class})
    for key, value in pairs(class) do
        new_table[key] = clone(value)
    end
    new_table._super = class
    return new_table
end
local function lineStrings(text)
    local ret = {}
    local line = ""
    for i = 1, string.len(text) do
        local char = string.sub(text, i, i)
        if char == "\n" then
            ret[#ret + 1] = line
            line = ""
        elseif char == "\r" then
        else
            line = line .. char
        end
    end
    if line ~= "\n" and line ~= "" then
        ret[#ret + 1] = line
    end
    return ret
end
local function vec2Equal(vec1, vec2)
    return vec1[1] == vec2[1] and vec1[2] == vec2[2]
end
local function vec3Equal(vec1, vec2)
    return vec1[1] == vec2[1] and vec1[2] == vec2[2] and vec1[3] == vec2[3]
end
local function processFloat(value, leftPointBit)
    local part1 = math.floor(value)
    local part2 = value - math.floor(value)
    part2 = math.floor(part2 * 10 ^ leftPointBit) * 10 ^ (-leftPointBit)
    return part1 + part2
end
local function array(t)
    local ret = {}
    for _, value in pairs(t) do
        ret[#ret + 1] = value
    end
    return ret
end
local gOriginBlockIDs = {}
local function setBlock(x, y, z, blockID, blockDir)
    local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
    if not gOriginBlockIDs[key] then
        gOriginBlockIDs[key] = GetBlockId(x, y, z)
    end
    SetBlock(x, y, z, blockID, blockDir)
end
local function restoreBlock(x, y, z)
    local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
    if gOriginBlockIDs[key] then
        SetBlock(x, y, z, gOriginBlockIDs[key])
    end
end
local SavedData = {mMoney = 10000000000,mAttackTimeLevel = 100,mAttackValueLevel = 999,mHPLevel = 999}
local function getSavedData()
    return GetSavedData() or SavedData
end
-----------------------------------------------------------------------------------------Library-----------------------------------------------------------------------------------
local Framework = {}
local Command = {}
local CommandQueue = {}
local CommandQueueManager = {}
local Timer = {}
local Property = {}
local PropertyGroup = {}
local EntitySyncer = {}
local EntitySyncerManager = {}
local EntityCustom = {}
local EntityCustomManager = {}
local Host = {}
local Client = {}
local GlobalProperty = {}
local InputManager = {}
local PlayerManager = {}
local UI = {}
-----------------------------------------------------------------------------------------Framework-----------------------------------------------------------------------------------
function Framework.singleton(construct)
    if not Framework.msInstance and construct then
        Framework.msInstance = new(Framework)
    end
    return Framework.msInstance
end

function Framework:construction()
    GlobalProperty.initialize()
    PlayerManager.initialize()
    EntityCustomManager.singleton()
end

function Framework:destruction()
    PlayerManager.clear()
    delete(CommandQueueManager.singleton())
    delete(EntityCustomManager.singleton())
    MiniGameUISystem.shutdown()
    Framework.msInstance = nil
end

function Framework:update()
    GlobalProperty.update()
    CommandQueueManager.singleton():update()
    PlayerManager.update()
    EntityCustomManager.singleton():update()
end

function Framework:receiveMsg(parameter)
    if parameter.mKey ~= "GlobalProperty" then
        echo("devilwalk", "receiveMsg:parameter:")
        echo("devilwalk", parameter)
    end
    if parameter.mTo then
        if parameter.mTo == "Host" then
            Host.receive(parameter)
        elseif parameter.mTo == "All" then
            parameter.mTo = nil
            parameter.mFrom = parameter._from
            Host.broadcast(parameter)
        else
            local to = parameter.mTo
            parameter.mTo = nil
            parameter.mFrom = parameter._from
            Host.sendTo(to, parameter)
        end
    else
        Client.receive(parameter)
    end
end

function Framework:handleInput(event)
    InputManager.notify(event)
end
-----------------------------------------------------------------------------------------Command-----------------------------------------------------------------------------------
Command.EState = {Unstart = 0, Executing = 1, Finish = 2}
function Command:construction(parameter)
    -- echo("devilwalk", "devilwalk--------------------------------------------debug:Command:construction:parameter:")
    -- echo("devilwalk", parameter)
    self.mDebug = parameter.mDebug
    self.mState = Command.EState.Unstart
    self.mTimeOutProcess = parameter.mTimeOutProcess
end

function Command:destruction()
end

function Command:execute()
    self.mState = Command.EState.Executing
    echo("devilwalk", "devilwalk--------------------------------------------debug:Command:execute:self.mDebug:")
    echo("devilwalk", self.mDebug)
end

function Command:frameMove()
    if self.mState == Command.EState.Unstart then
        self:execute()
    elseif self.mState == Command.EState.Executing then
        self:executing()
    elseif self.mState == Command.EState.Finish then
        self:finish()
        return true
    end
end

function Command:executing()
    self.mExecutingTime = self.mExecutingTime or 0
    if self.mExecutingTime > 1000 then
        if self.mTimeOutProcess then
            self:mTimeOutProcess(self)
        else
            echo(
                "devilwalk",
                "devilwalk--------------------------------------------debug:Command:executing time out:self.mDebug:"
            )
            echo("devilwalk", self.mDebug)
        end
    end
    self.mExecutingTime = self.mExecutingTime + 1
end

function Command:finish()
    echo("devilwalk", "devilwalk--------------------------------------------debug:Command:finish:self.mDebug:")
    echo("devilwalk", self.mDebug)
end

function Command:stop()
    -- echo("devilwalk", "devilwalk--------------------------------------------debug:Command:stop:self.mDebug:")
    -- echo("devilwalk",self.mDebug)
end

function Command:restore()
    -- echo("devilwalk", "devilwalk--------------------------------------------debug:Command:restore:self.mDebug:")
    -- echo("devilwalk",self.mDebug)
end
-----------------------------------------------------------------------------------------Command Callback-----------------------------------------------------------------------------------------
local Command_Callback = inherit(Command)
function Command_Callback:construction(parameter)
    -- echo(
    --     "devilwalk",
    --     "devilwalk--------------------------------------------debug:Command_Callback:construction:parameter:"
    -- )
    -- echo("devilwalk", parameter)
    self.mExecuteCallback = parameter.mExecuteCallback
    self.mExecutingCallback = parameter.mExecutingCallback
    self.mFinishCallback = parameter.mFinishCallback
end

function Command_Callback:execute()
    Command_Callback._super.execute(self)
    if self.mExecuteCallback then
        self.mExecuteCallback(self)
    end
end

function Command_Callback:executing()
    Command_Callback._super.executing(self)
    if self.mExecutingCallback then
        self.mExecutingCallback(self)
    end
end

function Command_Callback:finish()
    Command_Callback._super.finish(self)
    if self.mFinishCallback then
        self.mFinishCallback(self)
    end
end
-----------------------------------------------------------------------------------------CommandQueue-----------------------------------------------------------------------------------
function CommandQueue:construction()
    self.mCommands = {}
end

function CommandQueue:destruction()
    if self.mCommands and #self.mCommands > 0 then
        for _, command in pairs(self.mCommands) do
            echo(
                "devilwalk",
                "devilwalk--------------------------------------------warning:CommandQueue:delete:command:" ..
                    tostring(command.mDebug)
            )
        end
    end
    self.mCommands = nil
end

function CommandQueue:update()
    if self.mCommands[1] then
        local ret = self.mCommands[1]:frameMove()
        if ret then
            table.remove(self.mCommands, 1)
        end
    end
end

function CommandQueue:post(cmd)
    echo("devilwalk", "CommandQueue:post:")
    echo("devilwalk", cmd.mDebug)
    self.mCommands[#self.mCommands + 1] = cmd
end

function CommandQueue:empty()
    return #self.mCommands == 0
end
-----------------------------------------------------------------------------------------CommandQueueManager-----------------------------------------------------------------------------------------
function CommandQueueManager.singleton()
    if not CommandQueueManager.msInstance then
        CommandQueueManager.msInstance = new(CommandQueueManager)
    end
    return CommandQueueManager.msInstance
end

function CommandQueueManager:construction()
    self.mQueues = {}
end

function CommandQueueManager:destruction()
    for _, queue in pairs(self.mQueues) do
        delete(queue)
    end
end

function CommandQueueManager:createQueue()
    local ret = new(CommandQueue)
    self.mQueues[#self.mQueues + 1] = ret
    return ret
end

function CommandQueueManager:destroyQueue(queue)
    for i, test in pairs(self.mQueues) do
        if queue == test then
            delete(queue)
            table.remove(self.mQueues, i)
            break
        end
    end
end

function CommandQueueManager:update()
    for _, queue in pairs(self.mQueues) do
        queue:update()
    end
end

function CommandQueueManager:post(cmd)
    local queue = self:createQueue()
    queue:post(cmd)
    queue:post(
        new(
            Command_Callback,
            {
                mDebug = "TemporyCommandFinish",
                mExecuteCallback = function(command)
                    command.mState = Command.EState.Finish
                    self:destroyQueue(queue)
                end
            }
        )
    )
end
-----------------------------------------------------------------------------------------Timer-----------------------------------------------------------------------------------------
function Timer.global()
    Timer.mGlobal = Timer.mGlobal or new(Timer)
    return Timer.mGlobal
end

function Timer:construction()
    self.mInitTime = GetTime() * 0.001
    self.mTime = self.mInitTime
end

function Timer:destruction()
end

function Timer:delta()
    local new_time = GetTime() * 0.001
    local ret = new_time - self.mTime
    self.mTime = new_time
    return ret
end

function Timer:total()
    local new_time = GetTime() * 0.001
    local ret = new_time - self.mInitTime
    return ret
end
-----------------------------------------------------------------------------------------Property-----------------------------------------------------------------------------------------
function Property:construction()
    self.mCommandQueue = CommandQueueManager.singleton():createQueue()
    self.mCache = {}
    self.mCommandRead = {}
    self.mCommandWrite = {}
end

function Property:destruction()
    CommandQueueManager.singleton():destroyQueue(self.mCommandQueue)
    if self.mPropertyListeners then
        for property, listeners in pairs(self.mPropertyListeners) do
            GlobalProperty.removeListener(self:_getLockKey(property), self)
        end
    end
end

function Property:lockRead(property, callback)
    GlobalProperty.lockRead(
        self:_getLockKey(property),
        function(value)
            self.mCache[property] = value
            callback(value)
        end
    )
end

function Property:unlockRead(property)
    GlobalProperty.unlockRead(self:_getLockKey(property))
end

function Property:lockWrite(property, callback)
    GlobalProperty.lockWrite(
        self:_getLockKey(property),
        function(value)
            self.mCache[property] = value
            callback(value)
        end
    )
end

function Property:unlockWrite(property)
    GlobalProperty.unlockWrite(self:_getLockKey(property))
end

function Property:write(property, value, callback)
    self.mCache[property] = value
    GlobalProperty.write(self:_getLockKey(property), value, callback)
end

function Property:safeWrite(property, value, callback)
    self.mCache[property] = value
    GlobalProperty.lockAndWrite(self:_getLockKey(property), value, callback)
end

function Property:safeRead(property, callback)
    self:lockRead(
        property,
        function(value)
            self:unlockRead(property)
            if callback then
                callback(value)
            end
        end
    )
end

function Property:read(property, callback)
    GlobalProperty.read(
        self:_getLockKey(property),
        function(value)
            self.mCache[property] = value
            callback(value)
        end
    )
end

function Property:readUntil(property, callback)
    self:read(
        property,
        function(value)
            if value then
                callback(value)
            else
                self:readUntil(property, callback)
            end
        end
    )
end

function Property:commandRead(property)
    -- self.mCommandQueue:post(
    --     new(
    --         Command_Callback,
    --         {
    --             mDebug = "Property:commandRead:" .. property,
    --             mExecuteCallback = function(command)
    --                 self:safeRead(
    --                     property,
    --                     function()
    --                         command.mState = Command.EState.Finish
    --                     end
    --                 )
    --             end
    --         }
    --     )
    -- )
    self.mCommandRead[property] = self.mCommandRead[property] or 0
    self.mCommandRead[property] = self.mCommandRead[property] + 1
    self:safeRead(
        property,
        function()
            self.mCommandRead[property] = self.mCommandRead[property] - 1
            if self.mCommandRead[property] == 0 then
                self.mCommandRead[property] = nil
            end
        end
    )
end

function Property:commandWrite(property, value)
    -- self.mCommandQueue:post(
    --     new(
    --         Command_Callback,
    --         {
    --             mDebug = "Property:commandWrite:" .. property,
    --             mExecuteCallback = function(command)
    --                 self:safeWrite(
    --                     property,
    --                     value,
    --                     function()
    --                         command.mState = Command.EState.Finish
    --                     end
    --                 )
    --             end
    --         }
    --     )
    -- )
    self.mCommandWrite[property] = self.mCommandWrite[property] or 0
    self.mCommandWrite[property] = self.mCommandWrite[property] + 1
    self:safeWrite(
        property,
        value,
        function()
            self.mCommandWrite[property] = self.mCommandWrite[property] - 1
            if self.mCommandWrite[property] then
                self.mCommandWrite[property] = nil
            end
        end
    )
end

function Property:commandFinish(callback, timeOutCallback)
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Property:commandFinish",
                mTimeOutProcess = function()
                    echo(
                        "devilwalk",
                        "Property:commandFinish:time out--------------------------------------------------------------"
                    )
                    echo("devilwalk", "self.mCommandRead")
                    echo("devilwalk", self.mCommandRead)
                    echo("devilwalk", "self.mCommandWrite")
                    echo("devilwalk", self.mCommandWrite)
                    if timeOutCallback then
                        timeOutCallback()
                    end
                end,
                mExecutingCallback = function(command)
                    if not next(self.mCommandRead) and not next(self.mCommandWrite) then
                        callback()
                        command.mState = Command.EState.Finish
                    end
                end
            }
        )
    )
end

function Property:cache()
    return self.mCache
end

function Property:addPropertyListener(property, callbackKey, callback, parameter)
    callbackKey = tostring(callbackKey)
    self.mPropertyListeners = self.mPropertyListeners or {}
    if not self.mPropertyListeners[property] then
        GlobalProperty.addListener(
            self:_getLockKey(property),
            self,
            function(_, value, preValue)
                self.mCache[property] = value
                self:notifyProperty(property, value, preValue)
            end
        )
    else
        callback(parameter, self.mCache[property], self.mCache[property])
    end
    self.mPropertyListeners[property] = self.mPropertyListeners[property] or {}
    self.mPropertyListeners[property][callbackKey] = {mCallback = callback, mParameter = parameter}
end

function Property:removePropertyListener(property, callbackKey)
    callbackKey = tostring(callbackKey)
    if self.mPropertyListeners and self.mPropertyListeners[property] then
        self.mPropertyListeners[property][callbackKey] = nil
    end
end

function Property:notifyProperty(property, value, preValue)
    -- echo("devilwalk", "Property:notifyProperty:property:" .. property)
    -- echo("devilwalk", value)
    if self.mPropertyListeners and self.mPropertyListeners[property] then
        for _, listener in pairs(self.mPropertyListeners[property]) do
            listener.mCallback(listener.mParameter, value, preValue)
        end
    end
end
-----------------------------------------------------------------------------------------Property Group-----------------------------------------------------------------------------------
function PropertyGroup:construction()
    self.mProperties = {}
end

function PropertyGroup:destruction()
end

function PropertyGroup:commandRead(propertyInstance, propertyName)
    propertyInstance:commandRead(propertyName)
    self.mProperties[tostring(propertyInstance)] = true
end

function PropertyGroup:commandWrite(propertyInstance, propertyName, propertyValue)
    propertyInstance:commandWrite(propertyName, propertyValue)
    self.mProperties[tostring(propertyInstance)] = true
end

function PropertyGroup:commandFinish(callback)
    local function _finish(propertyInstance)
        self.mProperties[tostring(propertyInstance)] = nil
        if not next(self.mProperties) then
            callback()
        end
    end
    for property_instance, _ in pairs(self.mProperties) do
        property_instance:commandFinish(
            function()
                _finish(property_instance)
            end
        )
    end
end
-----------------------------------------------------------------------------------------Entity Syncer----------------------------------------------------------------------------------------
function EntitySyncer:construction(parameter)
    self.mCommandQueue = CommandQueueManager.singleton():createQueue()
    if parameter.mEntityID then
        self.mEntityID = parameter.mEntityID
    elseif parameter.mEntity then
        self.mEntityID = parameter.mEntity.entityId
    end
end

function EntitySyncer:destruction()
    CommandQueueManager.singleton():destroyQueue(self.mCommandQueue)
end

function EntitySyncer:getEntity()
    return GetEntityById(self.mEntityID)
end

function EntitySyncer:setDisplayName(name, colour)
    self:broadcast("DisplayName", {mName = name, mColour = colour})
end

function EntitySyncer:setLocalDisplayNameColour(colour)
    self.mLocalDisplayNameColour = colour
    if self:getEntity() then
        self:getEntity():UpdateDisplayName(nil, self.mLocalDisplayNameColour)
    end
end

function EntitySyncer:broadcast(key, value)
    Host.broadcast(
        {mKey = "EntitySyncer", mEntityID = self:getEntity().entityId, mParameter = {mKey = key, mValue = value}}
    )
end

function EntitySyncer:receive(parameter)
    if not self:getEntity() then
        local parameter_clone = clone(parameter)
        self.mCommandQueue:post(
            new(
                Command_Callback,
                {
                    mDebug = "EntitySyncer:receive:mEntityID:" .. tostring(self.mEntityID),
                    mExecutingCallback = function(command)
                        if self:getEntity() then
                            self:receive(parameter_clone)
                            command.mState = Command.EState.Finish
                        end
                    end
                }
            )
        )
    else
        if parameter.mKey == "DisplayName" then
            -- echo("devilwalk","EntitySyncer:receive:DisplayName:"..parameter.mValue)
            self:getEntity():UpdateDisplayName(
                parameter.mValue.mName,
                self.mLocalDisplayNameColour or parameter.mValue.mColour
            )
        end
    end
end
-----------------------------------------------------------------------------------------Entity Syncer Manager----------------------------------------------------------------------------------------
function EntitySyncerManager.singleton()
    if not EntitySyncerManager.mInstance then
        EntitySyncerManager.mInstance = new(EntitySyncerManager)
    end
    return EntitySyncerManager.mInstance
end
function EntitySyncerManager:construction()
    self.mEntities = {}
    Client.addListener("EntitySyncer", self)
end

function EntitySyncerManager:destruction()
    Client.removeListener("EntitySyncer", self)
end

function EntitySyncerManager:update()
    for _, entity in pairs(self.mEntities) do
        entity:update()
    end
end

function EntitySyncerManager:receive(parameter)
    local entity = self.mEntities[parameter.mEntityID]
    if not entity then
        entity = new(EntitySyncer, {mEntityID = parameter.mEntityID})
        self.mEntities[parameter.mEntityID] = entity
    end
    entity:receive(parameter.mParameter)
end

function EntitySyncerManager:attach(entity)
    if not self.mEntities[entity.entityId] then
        self.mEntities[entity.entityId] = new(EntitySyncer, {mEntity = entity})
    end
end

function EntitySyncerManager:get(entity)
    self:attach(entity)
    return self.mEntities[entity.entityId]
end

function EntitySyncerManager:getByEntityID(entityID)
    return self.mEntities[entityID]
end
-----------------------------------------------------------------------------------------EntityCustom-----------------------------------------------------------------------------------------
function EntityCustom:construction(parameter)
    self.mModel = parameter.mModel
    self.mType = parameter.mType
    self.mScaling = self.mModel.mScaling or 1
    local real_x,real_y,real_z = ConvertToRealPosition(parameter.mX,parameter.mY,parameter.mZ)
    self.mPosition = vector3d:new(real_x,real_y,real_z)
    self.mFacing = self.mModel.mFacing or 0
    self.mTargets = {}
    if self.mModel.mFile then
        if parameter.mType == "EntityNPCOnline" then
            self.mEntity = CreateNPC({
                bx = parameter.mX,
                by = parameter.mY,
                bz = parameter.mZ,
                facing = 0,
                can_random_move = false,
                item_id = 10062,
                mDisableSync = true,
                is_dummy = true
            })
            self.mEntity._super.SetMainAssetPath(self.mEntity,self.mModel.mFile)
        else
            self.mEntity = CreateEntity(parameter.mX, parameter.mY, parameter.mZ, self.mModel.mFile)
        end
        self.mEntity:SetFacing(self.mFacing or 0)
        self.mEntity:SetScaling(self.mScaling or 1)
    elseif self.mModel.mResource then
        GetResourceModel(self.mModel.mResource,function(path)
            if parameter.mType == "EntityNPCOnline" then
                self.mEntity = CreateNPC({
                    bx = parameter.mX,
                    by = parameter.mY,
                    bz = parameter.mZ,
                    facing = 0,
                    can_random_move = false,
                    item_id = 10062,
                    mDisableSync = true,
                    is_dummy = true
                })
                self.mEntity._super.SetMainAssetPath(self.mEntity,path)
            else
                self.mEntity = CreateEntity(parameter.mX, parameter.mY, parameter.mZ, path)
            end
            self.mEntity:SetFacing(self.mFacing or 0)
            self.mEntity:SetScaling(self.mScaling or 1)
        end)
    end
    self.mClientKey = parameter.mClientKey
    self:setHostKey(parameter.mHostKey)
end

function EntityCustom:destruction()
    if self.mEntity then
        self.mEntity:SetDead(true)
    end
    self.mEntity = nil

    if self:_getSendKey() then
        Host.removeListener(self:_getSendKey(), self)
        Client.removeListener(self:_getSendKey(), self)
    end
end

function EntityCustom:update()
    if next(self.mTargets) then
        local target = self.mTargets[1]
        self.mTimer = self.mTimer or new(Timer)
        local speed = self.mMoveSpeed or 3
        if not self.mMoveDirection then
            self.mMoveDirection = (target - self.mPosition):normalize()
            self.mFacing = math.acos(self.mMoveDirection:dot(1,0,0))
            while self.mFacing > 3.14 do
                if self.mFacing > 3.15 then
                    self.mFacing = self.mFacing - 3.14
                else
                    self.mFacing = 3.14
                end
            end
            while self.mFacing < -3.14 do
                if self.mFacing < -3.15 then
                    self.mFacing = self.mFacing + 3.14
                else
                    self.mFacing = -3.14
                end
            end
            if self.mMoveDirection[3] > 0 then
                self.mFacing = -self.mFacing
            end
        end
        local next_pos = self.mPosition + self.mMoveDirection * speed * self.mTimer:delta()
        if (target - next_pos):dot(self.mMoveDirection) <= 0 then
            next_pos = target
        end
        self:_setPosition(next_pos[1],next_pos[2],next_pos[3])
        if next_pos == target then
            table.remove(self.mTargets,1)
            self.mMoveDirection = nil
        end
    end
    if self.mEntity then
        if self.mFacing and self.mFacing ~= self.mEntity:GetFacing() then
            self.mEntity:SetFacing(self.mFacing)
        end
        if not self.mPosition:equals(self.mEntity:getPosition()) then
            self.mEntity:SetPosition(self.mPosition[1],self.mPosition[2],self.mPosition[3])
        end
        if self.mAnimationID ~= self.mEntity:GetLastAnimId() then
            self.mEntity:SetAnimation(self.mAnimationID)
        end
    end
end

function EntityCustom:sendToHost(message, parameter)
    if self:_getSendKey() then
        Client.sendToHost(self:_getSendKey(), {mMessage = message, mParameter = parameter})
    end
end

function EntityCustom:requestToHost(message, parameter)
    self.mResponseCallback = self.mResponseCallback or {}
    self.mResponseCallback[message] = callback
    self:sendToHost(message, parameter)
end

function EntityCustom:hostSendToClient(playerID, message, parameter)
    if self:_getSendKey() then
        Host.sendTo(playerID, {mKey = self:_getSendKey(), mMessage = message, mParameter = parameter})
    end
end

function EntityCustom:clientSendToClient(playerID, message, parameter)
    if self:_getSendKey() then
        Client.sendToClient(playerID, self:_getSendKey(), {mMessage = message, mParameter = parameter})
    end
end

function EntityCustom:broadcast(message, parameter)
    if self:_getSendKey() then
        Client.broadcast(self:_getSendKey(), {mMessage = message, mParameter = parameter})
    end
end

function EntityCustom:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if self.mResponseCallback[message] then
            self.mResponseCallback[message](parameter.mParameter)
            self.mResponseCallback[message] = nil
        end
    else
        if parameter.mMessage == "SetPosition" then
            if parameter.mFrom ~= GetPlayerId() then
                self:_setPosition(parameter.mParameter.mX, parameter.mParameter.mY, parameter.mParameter.mZ)
            end
        elseif parameter.mMessage == "MoveTo" then
            if parameter.mFrom ~= GetPlayerId() then
                self:_moveTo(parameter.mParameter.mX, parameter.mParameter.mY, parameter.mParameter.mZ, parameter.mParameter.mType)
            end
        elseif parameter.mMessage == "SetAnimationID" then
            if parameter.mFrom ~= GetPlayerId() then
                self:_setAnimationID(parameter.mParameter.mID)
            end
        end
    end
end

function EntityCustom:setHostKey(hostKey)
    self.mHostKey = hostKey
    if self:_getSendKey() then
        Host.addListener(self:_getSendKey(), self)
        Client.addListener(self:_getSendKey(), self)
    end
end

function EntityCustom:setPosition(x, y, z)
    self:_setPosition(x,y,z)
    self:broadcast("SetPosition", {mX = x, mY = y, mZ = z})
end

function EntityCustom:getBlockPosition()
    local x,y,z = ConvertToBlockIndex(self.mPosition[1],self.mPosition[2] + 0.5,self.mPosition[3])
    return vector3d:new(x,y,z)
end

function EntityCustom:getPosition()
    return self.mPosition
end

function EntityCustom:moveToBlock(x,y,z,type)
    local real_x,real_y,real_z = ConvertToRealPosition(x,y,z)
    self:moveTo(real_x,real_y,real_z,type)
end

function EntityCustom:moveTo(x,y,z,type)
    self:_moveTo(x,y,z,type)
    self:broadcast("MoveTo",{mX = x, mY = y, mZ = z,mType = type})
end

function EntityCustom:_setPosition(x, y, z)
    self.mPosition[1] = x
    self.mPosition[2] = y
    self.mPosition[3] = z
end

function EntityCustom:_moveTo(x,y,z,type)
    if type == "addition" then
        self.mTargets[#self.mTargets+1] = vector3d:new(x,y,z)
    else
        self.mTargets = {vector3d:new(x,y,z)}
    end
end

function EntityCustom:setAnimationID(id)
    self:_setAnimationID(id)
    self:broadcast("setAnimationID",{mID = id})
end

function EntityCustom:_setAnimationID(id)
    self.mAnimationID = id
end

function EntityCustom:_getSendKey()
    if self.mHostKey then
        return "EntityCustom" .. tostring(self.mHostKey)
    end
end
-----------------------------------------------------------------------------------------EntityCustomManager-----------------------------------------------------------------------------------------
function EntityCustomManager.singleton()
    if not EntityCustomManager.msInstance then
        EntityCustomManager.msInstance = new(EntityCustomManager)
    end
    return EntityCustomManager.msInstance
end

function EntityCustomManager:construction()
    self.mEntities = {}
    self.mNextEntityHostKey = 1
    self.mNextEntityClientKey = 1

    Host.addListener("EntityCustomManager", self)
    Client.addListener("EntityCustomManager", self)

    self:requestToHost("SyncEntities",nil,function(parameter)
        for _,info in pairs(parameter.mEntities) do
            local entity = self:_createEntity(
                info.mType,
                0,
                0,
                0,
                info.mModel,
                info.mHostKey
            )
            entity.mPosition = vector3d:new(info.mPosition[1],info.mPosition[2],info.mPosition[3])
            entity.mAnimationID = info.mAnimationID
            entity.mFacing = info.mFacing
            entity.mScaling = info.mScaling
            if info.mTargets then
                for _,target in pairs(info.mTargets) do
                    entity.mTargets[#entity.mTargets+1] = vector3d:new(target[1],target[2],target[3])
                end
            end
            if info.mMoveDirection then
                entity.mMoveDirection = vector3d:new(info.mMoveDirection[1],info.mMoveDirection[2],info.mMoveDirection[3])
            end
        end
    end)
end

function EntityCustomManager:destruction()
    for _, entity in pairs(self.mEntities) do
        delete(entity)
    end
    self.mEntities = nil

    Host.removeListener("EntityCustomManager", self)
    Client.removeListener("EntityCustomManager", self)
end

function EntityCustomManager:update()
    for _,entity in pairs(self.mEntities) do
        entity:update()
    end
end

function EntityCustomManager:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if self.mResponseCallback[message] and self.mResponseCallback[message][parameter.mParameter.mResponseCallbackKey] then
            self.mResponseCallback[message][parameter.mParameter.mResponseCallbackKey](parameter.mParameter)
            self.mResponseCallback[message][parameter.mParameter.mResponseCallbackKey] = nil
        end
    else
        if parameter.mMessage == "CreateEntityHost" then
            local host_key = self:_generateNextEntityHostKey()
            self:hostSendToClient(parameter.mFrom, "CreateEntityHost_Response", {mHostKey = host_key,mResponseCallbackKey = parameter.mParameter.mResponseCallbackKey})
            self:hostBroadcast(
                "CreateEntity",
                {
                    mType = parameter.mParameter.mType,
                    mX = parameter.mParameter.mX,
                    mY = parameter.mParameter.mY,
                    mZ = parameter.mParameter.mZ,
                    mModel = parameter.mParameter.mModel,
                    mHostKey = host_key,
                    mPlayerID = parameter.mParameter.mPlayerID
                }
            )
        elseif parameter.mMessage == "CreateEntity" then
            if parameter.mParameter.mPlayerID ~= GetPlayerId() then
                self:_createEntity(
                    parameter.mParameter.mType,
                    parameter.mParameter.mX,
                    parameter.mParameter.mY,
                    parameter.mParameter.mZ,
                    parameter.mParameter.mModel,
                    parameter.mParameter.mHostKey
                )
            end
        elseif parameter.mMessage == "DestroyEntity" then
            self:_destroyEntity(self:getEntityByHostKey(parameter.mParameter.mHostKey))
        elseif parameter.mMessage == "CreateTrackEntity" then
            if parameter.mParameter.mPlayerID ~= GetPlayerId() then
                self:_createTrackEntity(parameter.mParameter.mTracks)
            end
        elseif parameter.mMessage == "SyncEntities" then
            local entities = {}
            for _,entity in pairs(self.mEntities) do
                entities[#entities+1] = 
                {mPosition = entity.mPosition
                ,mType = entity.mType
                ,mMoveDirection = entity.mMoveDirection
                ,mFacing = entity.mFacing
                ,mModel = entity.mModel
                ,mScaling = entity.mScaling
                ,mHostKey = entity.mHostKey
                ,mAnimationID = entity.mAnimationID
                ,mTargets = entity.mTargets}
            end
            self:hostSendToClient(parameter.mFrom, "SyncEntities_Response", {mEntities = entities,mResponseCallbackKey = parameter.mParameter.mResponseCallbackKey})
        end
    end
end

function EntityCustomManager:sendToHost(message, parameter)
    Client.sendToHost("EntityCustomManager", {mMessage = message, mParameter = parameter})
end

function EntityCustomManager:requestToHost(message, parameter, callback)
    self.mResponseCallback = self.mResponseCallback or {}
    self.mResponseCallback[message] = self.mResponseCallback[message] or  {}
    self.mResponseCallbackKey = self.mResponseCallbackKey or 1
    local callback_key = self.mResponseCallbackKey
    self.mResponseCallbackKey = self.mResponseCallbackKey + 1
    self.mResponseCallback[message][callback_key] = callback
    parameter = parameter or {}
    parameter.mResponseCallbackKey = callback_key
    self:sendToHost(message, parameter)
end

function EntityCustomManager:hostSendToClient(playerID, message, parameter)
    Host.sendTo(playerID, {mKey = "EntityCustomManager", mMessage = message, mParameter = parameter})
end

function EntityCustomManager:clientSendToClient(playerID, message, parameter)
    Client.sendToClient(playerID, "EntityCustomManager", {mMessage = message, mParameter = parameter})
end

function EntityCustomManager:clientBroadcast(message, parameter)
    Client.broadcast("EntityCustomManager", {mMessage = message, mParameter = parameter})
end

function EntityCustomManager:hostBroadcast(message, parameter)
    Host.broadcast({mKey = "EntityCustomManager", mMessage = message, mParameter = parameter})
end

function EntityCustomManager:createEntity(parameter,callback)
    local entity = self:_createEntity(parameter.mType, parameter.mX, parameter.mY, parameter.mZ, parameter.mModel)
    local client_key = entity.mClientKey
    self.mFakeEntities = self.mFakeEntities or {}
    self.mFakeEntities[client_key] = {mClientKey = client_key}
    self:requestToHost(
        "CreateEntityHost",
        {mType = parameter.mType, mX = parameter.mX, mY = parameter.mY, mZ = parameter.mZ, mModel = parameter.mModel, mPlayerID = GetPlayerId()},
        function(parameter)
            local entity = self:getEntityByClientKey(client_key)
            if entity then
                entity:setHostKey(parameter.mHostKey)
                self.mFakeEntities[client_key] = nil
            else
                self.mFakeEntities[client_key].mHostKey = parameter.mHostKey
            end
            if callback then
                callback(entity.mHostKey)
            end
        end
    )
    return client_key
end

function EntityCustomManager:getEntityByHostKey(hostKey)
    if not hostKey then
        return
    end
    for _, entity in pairs(self.mEntities) do
        if entity.mHostKey and entity.mHostKey == hostKey then
            return entity
        end
    end
end

function EntityCustomManager:getEntityByClientKey(clientKey)
    if not clientKey then
        return
    end
    for _, entity in pairs(self.mEntities) do
        if entity.mClientKey and entity.mClientKey == clientKey then
            return entity
        end
    end
end

function EntityCustomManager:destroyEntity(clientKey)
    local entity = self:getEntityByClientKey(clientKey)
    local host_key = entity.mHostKey
    local client_key = entity.mClientKey
    self:_destroyEntity(entity)
    if host_key then
        self:clientBroadcast("DestroyEntity", {mHostKey = host_key})
    else
        CommandQueueManager.singleton():post(
            new(
                Command_Callback,
                {
                    mDebug = "EntityCustomManager:destroyEntity",
                    mExecutingCallback = function(command)
                        local fake_entity = self.mFakeEntities[client_key]
                        if fake_entity and fake_entity.mHostKey then
                            self:clientBroadcast("DestroyEntity", {mHostKey = fake_entity.mHostKey})
                            self.mFakeEntities[client_key] = nil
                            command.mState = Command.EState.Finish
                        end
                    end
                }
            )
        )
    end
end

function EntityCustomManager:createTrackEntity(tracks)
    self:_createTrackEntity(tracks)
    self:clientBroadcast("CreateTrackEntity", {mTracks = tracks, mPlayerID = GetPlayerId()})
end

function EntityCustomManager:_createEntity(type, x, y, z, model, hostKey)
    local ret =
        new(
        EntityCustom,
        {mType = type, mX = x, mY = y, mZ = z, mModel = model,mClientKey = self:_generateNextEntityClientKey(), mHostKey = hostKey}
    )
    self.mEntities[#self.mEntities + 1] = ret
    return ret
end

function EntityCustomManager:_destroyEntity(entity)
    for i, test in pairs(self.mEntities) do
        if test == entity then
            delete(entity)
            table.remove(self.mEntities, i)
            break
        end
    end
end

function EntityCustomManager:_generateNextEntityHostKey()
    self.mIsHost = true
    local ret = self.mNextEntityHostKey
    self.mNextEntityHostKey = self.mNextEntityHostKey + 1
    return ret
end

function EntityCustomManager:_generateNextEntityClientKey()
    local ret = self.mNextEntityClientKey
    self.mNextEntityClientKey = self.mNextEntityClientKey + 1
    return ret
end

function EntityCustomManager:_createEntityTrack(entity, track, commandQueue)
    (commandQueue or CommandQueueManager.singleton()):post(
        new(
            Command_Callback,
            {
                mDebug = "EntityTrack/" .. tostring(entity.mClientKey),
                mExecutingCallback = function(command)
                    if track.mType == "Ray" then
                        command.mTimer = command.mTimer or new(Timer)
                        if command.mTimer:total() > track.mTime then
                            command.mState = Command.EState.Finish
                        end
                        local src_position = track.mSrcPosition or entity:getPosition()
                        command.mNextPosition =
                            vector3d:new(src_position[1], src_position[2], src_position[3]) +
                            vector3d:new(track.mDirection[1], track.mDirection[2], track.mDirection[3]) * track.mSpeed *
                                command.mTimer:total()
                        entity:_setPosition(
                            command.mNextPosition[1],
                            command.mNextPosition[2],
                            command.mNextPosition[3]
                        )
                    elseif track.mType == "Point" then
                        command.mTimer = command.mTimer or new(Timer)
                        if command.mTimer:total() > track.mTime then
                            command.mState = Command.EState.Finish
                        end
                    end
                end
            }
        )
    )
end

function EntityCustomManager:_createTrackEntity(tracks)
    local command_queue = CommandQueueManager.singleton():createQueue()
    for i, track in pairs(tracks) do
        local x, y, z = ConvertToBlockIndex(track.mSrcPosition[1], track.mSrcPosition[2], track.mSrcPosition[3])
        local entity = self:_createEntity(track.mEntityType, x, y, z, track.mModel)
        entity:_setPosition(track.mSrcPosition[1], track.mSrcPosition[2], track.mSrcPosition[3])
        self:_createEntityTrack(entity, track, command_queue)
        command_queue:post(
            new(
                Command_Callback,
                {
                    mDebug = "EntityCustomManager:_createTrackEntity/PostProcess/" .. tostring(i),
                    mExecuteCallback = function(command)
                        self:_destroyEntity(entity)
                        command.mState = Command.EState.Finish
                    end
                }
            )
        )
    end
    command_queue:post(
        new(
            Command_Callback,
            {
                mDebug = "EntityCustomManager:_createTrackEntity/Finish",
                mExecuteCallback = function(command)
                    command.mState = Command.EState.Finish
                    CommandQueueManager.singleton():destroyQueue(command_queue)
                end
            }
        )
    )
end
-----------------------------------------------------------------------------------------Host-----------------------------------------------------------------------------------------
function Host.addListener(key, listener)
    local listenerKey = tostring(listener)
    Host.mListeners = Host.mListeners or {}
    Host.mListeners[key] = Host.mListeners[key] or {}
    Host.mListeners[key][listenerKey] = listener
end

function Host.removeListener(key, listener)
    local listenerKey = tostring(listener)
    Host.mListeners[key][listenerKey] = nil
end

function Host.receive(parameter)
    if Host.mListeners then
        local listeners = Host.mListeners[parameter.mKey]
        if listeners then
            for _, listener in pairs(listeners) do
                listener:receive(parameter)
            end
        end
    end
end

function Host.sendTo(clientPlayerID, parameter)
    local new_parameter = clone(parameter)
    if not new_parameter.mFrom then
        new_parameter.mFrom = GetPlayerId()
    end
    SendTo(clientPlayerID, new_parameter)
end

function Host.broadcast(parameter, exceptSelf)
    local new_parameter = clone(parameter)
    new_parameter.mFrom = GetPlayerId()
    SendTo(nil, new_parameter)
    if not exceptSelf then
        receiveMsg(parameter)
    end
end

-----------------------------------------------------------------------------------------Client-----------------------------------------------------------------------------------------
function Client.addListener(key, listener)
    local listenerKey = tostring(listener)
    Client.mListeners = Client.mListeners or {}
    Client.mListeners[key] = Client.mListeners[key] or {}
    Client.mListeners[key][listenerKey] = listener
end

function Client.removeListener(key, listener)
    local listenerKey = tostring(listener)
    Client.mListeners[key][listenerKey] = nil
end

function Client.receive(parameter)
    if Client.mListeners then
        if parameter.mKey then
            local listeners = Client.mListeners[parameter.mKey]
            if listeners then
                for _, listener in pairs(listeners) do
                    listener:receive(parameter)
                end
            end
        elseif parameter.mMessage == "clear" then
            clear()
        end
    end
end

function Client.sendToHost(key, parameter)
    local new_parameter = clone(parameter)
    new_parameter.mKey = key
    new_parameter.mTo = "Host"
    if not new_parameter.mFrom then
        new_parameter.mFrom = GetPlayerId()
    end
    SendTo("host", new_parameter)
end

function Client.sendToClient(playerID, key, parameter)
    local new_parameter = clone(parameter)
    new_parameter.mKey = key
    new_parameter.mTo = playerID
    if not new_parameter.mFrom then
        new_parameter.mFrom = GetPlayerId()
    end
    if playerID == GetPlayerId() then
        Client.receive(new_parameter)
    else
        SendTo("host", new_parameter)
    end
end

function Client.broadcast(key, parameter)
    local new_parameter = clone(parameter)
    new_parameter.mKey = key
    new_parameter.mTo = "All"
    if not new_parameter.mFrom then
        new_parameter.mFrom = GetPlayerId()
    end
    SendTo("host", new_parameter)
end
-----------------------------------------------------------------------------------------GlobalProperty-----------------------------------------------------------------------------------------
function GlobalProperty.initialize()
    GlobalProperty.mCommandList = {}
    Host.addListener("GlobalProperty", GlobalProperty)
    Client.addListener("GlobalProperty", GlobalProperty)
end

function GlobalProperty.update()
    for index, command in pairs(GlobalProperty.mCommandList) do
        local ret = command:frameMove()
        if ret then
            table.remove(GlobalProperty.mCommandList, index)
            break
        end
    end
end

function GlobalProperty.clear()
end

function GlobalProperty.lockWrite(key, callback)
    callback = callback or function()
        end
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    assert(GlobalProperty.mResponseCallback["LockWrite"][key] == nil, "GlobalProperty.lockWrite:key:" .. key)
    GlobalProperty.mResponseCallback["LockWrite"][key] = {callback}
    Client.sendToHost("GlobalProperty", {mMessage = "LockWrite", mParameter = {mKey = key, mDebug = getDebugStack()}})
end
--must be locked
function GlobalProperty.write(key, value, callback)
    callback = callback or function()
        end
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    assert(GlobalProperty.mResponseCallback["Write"][key] == nil, "GlobalProperty.Write:key:" .. key)
    GlobalProperty.mResponseCallback["Write"][key] = {callback}
    Client.sendToHost(
        "GlobalProperty",
        {mMessage = "Write", mParameter = {mKey = key, mValue = value, mDebug = getDebugStack()}}
    )
end

function GlobalProperty.unlockWrite(key)
    Client.sendToHost("GlobalProperty", {mMessage = "UnlockWrite", mParameter = {mKey = key, mDebug = getDebugStack()}})
end

function GlobalProperty.lockRead(key, callback)
    callback = callback or function()
        end
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    GlobalProperty.mResponseCallback["LockRead"][key] = GlobalProperty.mResponseCallback["LockRead"][key] or {}
    GlobalProperty.mResponseCallback["LockRead"][key][#GlobalProperty.mResponseCallback["LockRead"][key] + 1] = callback
    Client.sendToHost("GlobalProperty", {mMessage = "LockRead", mParameter = {mKey = key, mDebug = getDebugStack()}})
end

function GlobalProperty.unlockRead(key)
    Client.sendToHost("GlobalProperty", {mMessage = "UnlockRead", mParameter = {mKey = key, mDebug = getDebugStack()}})
end

function GlobalProperty.read(key, callback)
    callback = callback or function()
        end
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    GlobalProperty.mResponseCallback["Read"][key] = GlobalProperty.mResponseCallback["Read"][key] or {}
    local callbacks = GlobalProperty.mResponseCallback["Read"][key]
    callbacks[#callbacks + 1] = callback
    Client.sendToHost("GlobalProperty", {mMessage = "Read", mParameter = {mKey = key, mDebug = getDebugStack()}})
end

function GlobalProperty.lockAndWrite(key, value, callback)
    callback = callback or function()
        end
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    GlobalProperty.mResponseCallback["LockAndWrite"][key] = GlobalProperty.mResponseCallback["LockAndWrite"][key] or {}
    local callbacks = GlobalProperty.mResponseCallback["LockAndWrite"][key]
    callbacks[#callbacks + 1] = callback
    Client.sendToHost(
        "GlobalProperty",
        {mMessage = "LockAndWrite", mParameter = {mKey = key, mValue = value, mDebug = getDebugStack()}}
    )
end

function GlobalProperty.addListener(key, listenerKey, callback, parameter)
    listenerKey = tostring(listenerKey)
    GlobalProperty.mListeners = GlobalProperty.mListeners or {}
    GlobalProperty.mListeners[key] = GlobalProperty.mListeners[key] or {}
    GlobalProperty.mListeners[key][listenerKey] = {mCallback = callback, mParameter = parameter}

    GlobalProperty.read(
        key,
        function(value)
            if value then
                callback(parameter, value, value)
            end
        end
    )
end

function GlobalProperty.removeListener(key, listenerKey)
    listenerKey = tostring(listenerKey)
    if GlobalProperty.mListeners and GlobalProperty.mListeners[key] then
        GlobalProperty.mListeners[key][listenerKey] = nil
    end
end

function GlobalProperty.notify(key, value, preValue)
    if GlobalProperty.mListeners and GlobalProperty.mListeners[key] then
        for listener_key, callback in pairs(GlobalProperty.mListeners[key]) do
            callback.mCallback(callback.mParameter, value, preValue)
        end
    end
end

function GlobalProperty:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if
            GlobalProperty.mResponseCallback and GlobalProperty.mResponseCallback[message] and
                GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey]
         then
            local callbacks = GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey]
            local callback = callbacks[1]
            if not callback then
                echo("devilwalk", "---------------------------------------------------------------------------------")
                echo("devilwalk", parameter)
            end
            table.remove(callbacks, 1)
            if not next(callbacks) then
                GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey] = nil
            end
            callback(parameter.mParameter.mValue)
        end
    else
        GlobalProperty.mProperties = GlobalProperty.mProperties or {}
        GlobalProperty.mProperties[parameter.mParameter.mKey] =
            GlobalProperty.mProperties[parameter.mParameter.mKey] or {}
        if parameter.mMessage == "LockWrite" then -- host
            if GlobalProperty._canWrite(parameter.mParameter.mKey) then
                GlobalProperty._lockWrite(parameter.mParameter.mKey, parameter._from, parameter.mParameter.mDebug)
                Host.sendTo(
                    parameter._from,
                    {
                        mMessage = "LockWrite_Response",
                        mKey = "GlobalProperty",
                        mParameter = {
                            mKey = parameter.mParameter.mKey,
                            mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                        }
                    }
                )
            else
                GlobalProperty.mCommandList[#GlobalProperty.mCommandList + 1] =
                    new(
                    Command_Callback,
                    {
                        mDebug = GetEntityById(parameter._from).nickname .. ":LockWrite:" .. parameter.mParameter.mKey,
                        mExecutingCallback = function(command)
                            if GlobalProperty._canWrite(parameter.mParameter.mKey) then
                                GlobalProperty._lockWrite(
                                    parameter.mParameter.mKey,
                                    parameter._from,
                                    parameter.mParameter.mDebug
                                )
                                Host.sendTo(
                                    parameter._from,
                                    {
                                        mMessage = "LockWrite_Response",
                                        mKey = "GlobalProperty",
                                        mParameter = {
                                            mKey = parameter.mParameter.mKey,
                                            mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                                        }
                                    }
                                )
                                command.mState = Command.EState.Finish
                            end
                        end,
                        mTimeOutProcess = function(command)
                            echo("devilwalk", "GlobalProperty write lock time out:" .. command.mDebug)
                            echo("devilwalk", parameter.mParameter.mDebug)
                            if GlobalProperty.mProperties[parameter.mParameter.mKey] then
                                if GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked then
                                    echo(
                                        "devilwalk",
                                        GetEntityById(
                                            GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked.mPlayerID
                                        ).nickname .. " write locked"
                                    )
                                end
                                if GlobalProperty.mProperties[parameter.mParameter.mKey].mReadLocked then
                                    for _, info in pairs(
                                        GlobalProperty.mProperties[parameter.mParameter.mKey].mReadLocked
                                    ) do
                                        echo("devilwalk", GetEntityById(info.mPlayerID).nickname .. " read locked")
                                    end
                                end
                                echo("devilwalk", GlobalProperty.mProperties[parameter.mParameter.mKey])
                            end
                        end
                    }
                )
            end
        elseif parameter.mMessage == "UnlockWrite" then -- host
            GlobalProperty._unlockWrite(parameter.mParameter.mKey, parameter._from)
        elseif parameter.mMessage == "Write" then -- host
            GlobalProperty._write(parameter.mParameter.mKey, parameter.mParameter.mValue, parameter._from)
            Host.sendTo(
                parameter._from,
                {
                    mMessage = "Write_Response",
                    mKey = "GlobalProperty",
                    mParameter = {
                        mKey = parameter.mParameter.mKey,
                        mValue = parameter.mParameter.mValue
                    }
                }
            )
        elseif parameter.mMessage == "LockRead" then -- host
            if GlobalProperty._canRead(parameter.mParameter.mKey) then
                GlobalProperty._lockRead(parameter.mParameter.mKey, parameter._from, parameter.mParameter.mDebug)
                Host.sendTo(
                    parameter._from,
                    {
                        mMessage = "LockRead_Response",
                        mKey = "GlobalProperty",
                        mParameter = {
                            mKey = parameter.mParameter.mKey,
                            mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                        }
                    }
                )
            else
                GlobalProperty.mCommandList[#GlobalProperty.mCommandList + 1] =
                    new(
                    Command_Callback,
                    {
                        mDebug = tostring(parameter._from) .. ":LockRead:" .. parameter.mParameter.mKey,
                        mExecutingCallback = function(command)
                            if GlobalProperty._canRead(parameter.mParameter.mKey) then
                                GlobalProperty._lockRead(
                                    parameter.mParameter.mKey,
                                    parameter._from,
                                    parameter.mParameter.mDebug
                                )
                                Host.sendTo(
                                    parameter._from,
                                    {
                                        mMessage = "LockRead_Response",
                                        mKey = "GlobalProperty",
                                        mParameter = {
                                            mKey = parameter.mParameter.mKey,
                                            mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                                        }
                                    }
                                )
                                command.mState = Command.EState.Finish
                            end
                        end,
                        mTimeOutProcess = function(command)
                            echo("devilwalk", "GlobalProperty read lock time out:" .. command.mDebug)
                            echo("devilwalk", parameter.mParameter.mDebug)
                            if GlobalProperty.mProperties[parameter.mParameter.mKey] then
                                if GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked then
                                    echo(
                                        "devilwalk",
                                        GetEntityById(
                                            GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked.mPlayerID
                                        ).nickname .. " write locked"
                                    )
                                end
                                if GlobalProperty.mProperties[parameter.mParameter.mKey].mReadLocked then
                                    for _, info in pairs(
                                        GlobalProperty.mProperties[parameter.mParameter.mKey].mReadLocked
                                    ) do
                                        echo("devilwalk", GetEntityById(info.mPlayerID).nickname .. " read locked")
                                    end
                                end
                                echo("devilwalk", GlobalProperty.mProperties[parameter.mParameter.mKey])
                            end
                        end
                    }
                )
            end
        elseif parameter.mMessage == "UnlockRead" then -- host
            GlobalProperty._unlockRead(parameter.mParameter.mKey, parameter._from)
        elseif parameter.mMessage == "Read" then -- host
            Host.sendTo(
                parameter._from,
                {
                    mMessage = "Read_Response",
                    mKey = "GlobalProperty",
                    mParameter = {
                        mKey = parameter.mParameter.mKey,
                        mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                    }
                }
            )
        elseif parameter.mMessage == "LockAndWrite" then -- host
            if GlobalProperty._canWrite(parameter.mParameter.mKey) then
                GlobalProperty._lockWrite(parameter.mParameter.mKey, parameter._from, parameter.mParameter.mDebug)
                GlobalProperty._write(parameter.mParameter.mKey, parameter.mParameter.mValue, parameter._from)
                Host.sendTo(
                    parameter._from,
                    {
                        mMessage = "LockAndWrite_Response",
                        mKey = "GlobalProperty",
                        mParameter = {
                            mKey = parameter.mParameter.mKey,
                            mValue = parameter.mParameter.mValue
                        }
                    }
                )
            else
                GlobalProperty.mCommandList[#GlobalProperty.mCommandList + 1] =
                    new(
                    Command_Callback,
                    {
                        mDebug = GetEntityById(parameter._from).nickname ..
                            ":LockAndWrite:" .. parameter.mParameter.mKey,
                        mExecutingCallback = function(command)
                            if GlobalProperty._canWrite(parameter.mParameter.mKey) then
                                GlobalProperty._lockWrite(
                                    parameter.mParameter.mKey,
                                    parameter._from,
                                    parameter.mParameter.mDebug
                                )
                                GlobalProperty._write(
                                    parameter.mParameter.mKey,
                                    parameter.mParameter.mValue,
                                    parameter._from
                                )
                                Host.sendTo(
                                    parameter._from,
                                    {
                                        mMessage = "LockAndWrite_Response",
                                        mKey = "GlobalProperty",
                                        mParameter = {
                                            mKey = parameter.mParameter.mKey,
                                            mValue = parameter.mParameter.mValue
                                        }
                                    }
                                )
                                command.mState = Command.EState.Finish
                            end
                        end,
                        mTimeOutProcess = function(command)
                            echo("devilwalk", "GlobalProperty write lock time out:" .. command.mDebug)
                            echo("devilwalk", parameter.mParameter.mDebug)
                            if GlobalProperty.mProperties[parameter.mParameter.mKey] then
                                if GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked then
                                    echo(
                                        "devilwalk",
                                        GetEntityById(
                                            GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked.mPlayerID
                                        ).nickname .. " write locked"
                                    )
                                end
                                if GlobalProperty.mProperties[parameter.mParameter.mKey].mReadLocked then
                                    for _, info in pairs(
                                        GlobalProperty.mProperties[parameter.mParameter.mKey].mReadLocked
                                    ) do
                                        echo("devilwalk", GetEntityById(info.mPlayerID).nickname .. " read locked")
                                    end
                                end
                                echo("devilwalk", GlobalProperty.mProperties[parameter.mParameter.mKey])
                            end
                        end
                    }
                )
            end
        elseif parameter.mMessage == "PropertyChange" then -- client
            GlobalProperty.notify(
                parameter.mParameter.mKey,
                parameter.mParameter.mValue,
                parameter.mParameter.mPreValue
            )
        end
    end
end

function GlobalProperty._lockWrite(key, playerID, debugInfo)
    assert(
        GlobalProperty.mProperties[key].mWriteLocked == nil,
        "GlobalProperty._lockWrite:GlobalProperty.mProperties[key].mWriteLocked ~= nil"
    )
    assert(
        GlobalProperty.mProperties[key].mReadLocked == nil or #GlobalProperty.mProperties[key].mReadLocked == 0,
        "GlobalProperty._lockWrite:GlobalProperty.mProperties[key].mReadLocked ~= 0 and GlobalProperty.mProperties[key].mReadLocked ~= nil"
    )
    -- echo("devilwalk", "GlobalProperty._lockWrite:key,playerID:" .. tostring(key) .. "," .. tostring(playerID))
    GlobalProperty.mProperties[key].mWriteLocked = {mPlayerID = playerID, mDebug = debugInfo}
    -- GlobalProperty._lockRead(key, playerID)
end

function GlobalProperty._unlockWrite(key, playerID)
    assert(
        GlobalProperty.mProperties[key].mWriteLocked and
            GlobalProperty.mProperties[key].mWriteLocked.mPlayerID == playerID,
        "GlobalProperty._unlockWrite:GlobalProperty.mProperties[key].mWriteLocked ~= playerID"
    )
    -- echo("devilwalk", "GlobalProperty._unlockWrite:key,playerID:" .. tostring(key) .. "," .. tostring(playerID))
    GlobalProperty.mProperties[key].mWriteLocked = nil
    -- GlobalProperty._unlockRead(key, playerID)
end

function GlobalProperty._write(key, value, playerID)
    assert(
        GlobalProperty.mProperties[key].mWriteLocked and
            GlobalProperty.mProperties[key].mWriteLocked.mPlayerID == playerID,
        "GlobalProperty._write:GlobalProperty.mProperties[key].mWriteLocked ~= playerID"
    )
    -- echo("devilwalk", "GlobalProperty._write:key,playerID,value:" .. tostring(key) .. "," .. tostring(playerID))
    -- echo("devilwalk", value)
    local pre_value = GlobalProperty.mProperties[key].mValue
    GlobalProperty.mProperties[key].mValue = value
    GlobalProperty._unlockWrite(key, playerID)
    Host.broadcast(
        {
            mMessage = "PropertyChange",
            mKey = "GlobalProperty",
            mParameter = {mKey = key, mValue = value, mPreValue = pre_value, mPlayerID = playerID}
        }
    )
end

function GlobalProperty._lockRead(key, playerID, debugInfo)
    --echo("devilwalk", "GlobalProperty._lockRead:key,playerID:" .. tostring(key) .. "," .. tostring(playerID))
    GlobalProperty.mProperties[key].mReadLocked = GlobalProperty.mProperties[key].mReadLocked or {}
    GlobalProperty.mProperties[key].mReadLocked[#GlobalProperty.mProperties[key].mReadLocked + 1] = {
        mPlayerID = playerID,
        mDebug = debugInfo
    }
end

function GlobalProperty._unlockRead(key, playerID)
    --echo("devilwalk", "GlobalProperty._unlockRead:key,playerID:" .. tostring(key) .. "," .. tostring(playerID))
    local unlocked
    for i = #GlobalProperty.mProperties[key].mReadLocked, 1, -1 do
        if GlobalProperty.mProperties[key].mReadLocked[i].mPlayerID == playerID then
            table.remove(GlobalProperty.mProperties[key].mReadLocked, i)
            unlocked = true
            break
        end
    end
    assert(unlocked, "GlobalProperty._unlockRead:key:" .. key .. ",playerID:" .. tostring(playerID))
end

function GlobalProperty._canWrite(key)
    -- echo("devilwalk", "GlobalProperty._canWrite:key:" .. tostring(key))
    -- echo("devilwalk", GlobalProperty.mProperties)
    return not GlobalProperty.mProperties[key].mWriteLocked and
        (not GlobalProperty.mProperties[key].mReadLocked or #GlobalProperty.mProperties[key].mReadLocked == 0)
end

function GlobalProperty._canRead(key)
    -- return GlobalProperty._canWrite(key)
    return not GlobalProperty.mProperties[key].mWriteLocked
end
-----------------------------------------------------------------------------------------InputManager-----------------------------------------------------------------------------------------
function InputManager.addListener(key, callback, parameter)
    InputManager.mListeners = InputManager.mListeners or {}
    InputManager.mListeners[key] = {mCallback = callback, mParameter = parameter}
end

function InputManager.removeListener(key)
    InputManager.mListeners[key] = nil
end

function InputManager.notify(event)
    if InputManager.mListeners then
        for _, listener in pairs(InputManager.mListeners) do
            listener.mCallback(listener.mParameter, event)
        end
    end
end
-----------------------------------------------------------------------------------------PlayerManager-----------------------------------------------------------------------------------------
function PlayerManager.initialize()
    PlayerManager.onPlayerIn(EntityWatcher.get(GetPlayerId()))
    PlayerManager.onPlayerEntityCreate(EntityWatcher.get(GetPlayerId()))
    EntityWatcher.on(
        "create",
        function(inst)
            echo("devilwalk","PlayerManager.initialize:EntityWatcher.on:inst:"..tostring(inst.id))
            PlayerManager.onPlayerIn(inst)
            if GetEntityById(inst.id) then
                PlayerManager.onPlayerEntityCreate(inst)
            end
            if PlayerManager.mHideAll then
                PlayerManager.hideAll()
            end
        end
    )
end

function PlayerManager.onPlayerIn(entityWatcher)
    PlayerManager.mPlayers = PlayerManager.mPlayers or {}
    PlayerManager.mPlayers[entityWatcher.id] = entityWatcher
    PlayerManager.notify("PlayerIn", {mPlayerID = entityWatcher.id})
end

function PlayerManager.onPlayerEntityCreate(entityWatcher)
    PlayerManager.mPlayerEntitices = PlayerManager.mPlayerEntitices or {}
    PlayerManager.mPlayerEntitices[entityWatcher.id] = entityWatcher
    PlayerManager.notify("PlayerEntityCreate", {mPlayerID = entityWatcher.id})
end

function PlayerManager.getPlayerByID(id)
    id = id or GetPlayerId()
    return PlayerManager.mPlayers[id]
end

function PlayerManager.update()
    for id, player in pairs(PlayerManager.mPlayers) do
        if not GetEntityById(id) and PlayerManager.mPlayerEntitices and PlayerManager.mPlayerEntitices[id] then
            PlayerManager.notify("PlayerRemoved", {mPlayerID = id})
            PlayerManager.mPlayers[id] = nil
            PlayerManager.mPlayerEntitices[id] = nil
        elseif GetEntityById(id) and (not PlayerManager.mPlayerEntitices or not PlayerManager.mPlayerEntitices[id]) then
            PlayerManager.onPlayerEntityCreate(player)
        end
    end
end

function PlayerManager.showAll()
    PlayerManager.mHideAll = nil
    for _, player in pairs(PlayerManager.mPlayers) do
        player.mEntity:SetVisible(true)
        player.mEntity:ShowHeadOnDisplay(true)
    end
end

function PlayerManager.hideAll()
    PlayerManager.mHideAll = true
    for _, player in pairs(PlayerManager.mPlayers) do
        player.mEntity:ShowHeadOnDisplay(false)
        player.mEntity:SetVisible(false)
    end
end

function PlayerManager.clear()
end

function PlayerManager.addEventListener(eventType, key, callback, parameter)
    PlayerManager.mEventListeners = PlayerManager.mEventListeners or {}
    PlayerManager.mEventListeners[eventType] = PlayerManager.mEventListeners[eventType] or {}
    PlayerManager.mEventListeners[eventType][key] = {mCallback = callback, mParameter = parameter}
end

function PlayerManager.removeEventListener(eventType, key)
    PlayerManager.mEventListeners = PlayerManager.mEventListeners or {}
    PlayerManager.mEventListeners[eventType] = PlayerManager.mEventListeners[eventType] or {}
    PlayerManager.mEventListeners[eventType][key] = nil
end

function PlayerManager.notify(eventType, parameter)
    if PlayerManager.mEventListeners and PlayerManager.mEventListeners[eventType] then
        local listeners = PlayerManager.mEventListeners[eventType]
        for key, listener in pairs(listeners) do
            listener.mCallback(listener.mParameter, parameter)
        end
    end
end
-----------------------------------------------------------------------------------------Game UI-----------------------------------------------------------------------------------------
function UI.messageBox(text, img)
    if UI.mMessageBox then
        UI.mMessageBoxMessageQueue = UI.mMessageBoxMessageQueue or {}
        UI.mMessageBoxMessageQueue[#UI.mMessageBoxMessageQueue + 1] = text
        return
    end
    UI.mMessageBox = MiniGameUISystem.createWindow("UI/MessageBox", "_ct", 0, 0, 600, 400)
    UI.mMessageBox:setZOrder(500)
    local background = UI.mMessageBox:createUI("Picture", "UI/MessageBox/Picture", "_lt", 0, 0, 600, 400)
    background:setBackgroundResource(255, 0, 0, 0, 0, "Fk2ztiR-hKdBug6TWtytWvAGu3mr")
    if img then
        local image =
            UI.mMessageBox:createUI("Picture", "UI/MessageBox/Picture/Image", "_lt", 50, 100, 500, 200, background)
        image:setBackgroundResource(img.pid, 0, 0, 0, 0, img.hash)
    end
    local info = UI.mMessageBox:createUI("Text", "UI/MessageBox/Text", "_lt", 0, 0, 600, 90, background)
    info:setTextFormat(5)
    info:setFontSize(25)
    info:setText(text)
    info:setFontColour("255 255 255")
    local button = UI.mMessageBox:createUI("Button", "UI/MessageBox/Button", "_lt", 250, 300, 100, 100, background)
    button:setBackgroundResource(257, 0, 0, 0, 0, "FtFq7Cxh7NP2JrWjJX2zUPdWFwJ7")
    button:addEventFunction(
        "onclick",
        function()
            MiniGameUISystem.destroyWindow(UI.mMessageBox)
            UI.mMessageBox = nil
            if UI.mMessageBoxMessageQueue and UI.mMessageBoxMessageQueue[1] then
                local new_text = UI.mMessageBoxMessageQueue[1]
                table.remove(UI.mMessageBoxMessageQueue, 1)
                UI.messageBox(new_text)
            end
        end
    )
end

function UI.yesOrNo(text, yesCallback, noCallback)
    if UI.mYesOrNo then
        MiniGameUISystem.destroyWindow(UI.mYesOrNo)
        UI.mYesOrNo = nil
    end
    if not text and not yesCallback and not noCallback then
        return
    end
    UI.mYesOrNo = MiniGameUISystem.createWindow("UI/YesOrNo", "_ct", 0, 0, 600, 400)
    UI.mYesOrNo:setZOrder(400)
    local background = UI.mYesOrNo:createUI("Picture", "UI/YesOrNo/Picture", "_lt", 0, 0, 600, 400)
    background:setBackgroundResource(255, 0, 0, 0, 0, "Fk2ztiR-hKdBug6TWtytWvAGu3mr")
    local info = UI.mYesOrNo:createUI("Text", "UI/YesOrNo/Text", "_lt", 0, 0, 600, 90, background)
    info:setTextFormat(5)
    info:setFontSize(25)
    info:setText(text)
    info:setFontColour("255 255 255")
    local button_yes = UI.mYesOrNo:createUI("Button", "UI/YesOrNo/Button/Yes", "_lt", 200, 300, 100, 100, background)
    button_yes:setFontSize(25)
    button_yes:setBackgroundResource(258, 0, 0, 0, 0, "FsDME5crdZJOkcnSw7vIx6MMncrY")
    button_yes:addEventFunction(
        "onclick",
        function()
            MiniGameUISystem.destroyWindow(UI.mYesOrNo)
            UI.mYesOrNo = nil
            if yesCallback then
                yesCallback()
            end
        end
    )
    local button_no = UI.mYesOrNo:createUI("Button", "UI/YesOrNo/Button/No", "_lt", 400, 300, 100, 100, background)
    button_no:setFontSize(25)
    button_no:setBackgroundResource(259, 0, 0, 0, 0, "FuANimWrOhUgBl-GgrqeQuc1YuRn")
    button_no:addEventFunction(
        "onclick",
        function()
            MiniGameUISystem.destroyWindow(UI.mYesOrNo)
            UI.mYesOrNo = nil
            if noCallback then
                noCallback()
            end
        end
    )
end
-----------------------------------------------------------------------------------------Table Define-----------------------------------------------------------------------------------
local GameConfig = {}
local GameCompute = {}
local GamePlayerProperty = inherit(Property)
local GameMonsterProperty = inherit(Property)
local GameMonsterManagerProperty = inherit(Property)
local GameProperty = inherit(Property)
local GameProtecterProperty = inherit(Property)
local GameEffectManager = {}
local Host_Game = {}
local Host_GamePlayerManager = {}
local Host_GameMonsterManager = {}
local Host_GameEffectManager = {}
local Host_GameTerrain = {}
local Host_GameMonsterGenerator = {}
local Host_GamePlayer = {}
local Host_GameMonster = {}
local Host_GameProtecter = {}
local Host_GameTower = {}
local Client_Game = {}
local Client_GamePlayerManager = {}
local Client_GameMonsterManager = {}
local Client_GameEffectManager = {}
local Client_GamePlayer = {}
local Client_GameMonster = {}
local Client_GameProtecter = {}
local Client_GameTower = {}
-----------------------------------------------------------------------------------------GameConfig-----------------------------------------------------------------------------------
GameConfig.mMonsterPointBlockID = 2101
GameConfig.mProtectedPointBlockID = 2102
GameConfig.mTowerPointBlockID = 128
GameConfig.mMonsterLibrary = {
  {mModel = {mFile = "character/v3/Pet/CAITOUBB/CAITOUbb.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 1 and level <= 16 then return true end end, mName = "雄性菜头宝宝"},
  {mModel = {mFile = "character/v3/Pet/CTBB/ctbb_LOD15.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 8 and level <= 24 then return true end end, mName = "雌性菜头宝宝"},
  {mModel = {mFile = "character/v3/Pet/HGS/HGS_LOD15.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 15 and level <= 32 then return true end end, mName = "皇冠蛇宝宝"},
  {mModel = {mFile = "character/v3/Pet/MFBB/MFBB_LOD15.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 22 and level <= 40 then return true end end, mName = "蜜蜂宝宝"},
  {mModel = {mFile = "character/v3/Pet/MGBB/mgbb_LOD15.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 29 and level <= 48 then return true end end, mName = "蘑菇宝宝"},
  {mModel = {mFile = "character/v3/Pet/PP/PP_LOD5.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 36 and level <= 56 then return true end end, mName = "PP机器人"},
  {mModel = {mFile = "character/v3/Pet/SJTZ/SJTZ_LOD05.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 43 and level <= 64 then return true end end, mName = "小精灵宝宝"},
  {mModel = {mFile = "character/v3/Pet/XGBB/XGBB_LOD5.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 50 and level <= 72 then return true end end, mName = "西瓜宝宝"},
  {mModel = {mFile = "character/v3/Pet/HDL/HDL_LOD15.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 57 and level <= 80 then return true end end, mName = "花朵兰宝宝"},
  {mModel = {mFile = "character/v3/Pet/YYCZ/yycz_LOD5.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 64 and level <= 88 then return true end end, mName = "音乐机器人"},
  {mModel = {mFile = "character/v5/02animals/DragonBaby/DragonBabyGreen/DragonBabyGreen.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 71 and level <= 96 then return true end end, mName = "绿龙宝宝"},
  {mModel = {mFile = "character/v5/02animals/DragonBaby/DragonBabyOrange/DragonBabyOrange.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 78 and level <= 104 then return true end end, mName = "橙龙宝宝"},
  {mModel = {mFile = "character/v5/02animals/DragonBaby/DragonBabyYellow/DragonBabyYellow.x", mScaling =2}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 85 and level <= 112 then return true end end, mName = "黄龙宝宝"},
  {mModel = {mFile = "character/v3/Npc/shitouren/shitouren.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 92 and level <= 120 then return true end end, mName = "石头人"},
  {mModel = {mFile = "character/v3/GameNpc/TZMYS/TZMYS.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 99 and level <= 128 then return true end end, mName = "兔子先生"},
  {mModel = {mFile = "character/v5/02animals/Pig/Pig_V1.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 106 and level <= 136 then return true end end, mName = "猪战士"},
  {mModel = {mFile = "character/v5/02animals/Pig/Pig_V2.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 113 and level <= 144 then return true end end, mName = "猪射手"},
  {mModel = {mFile = "character/v5/02animals/JXRXLG/JXRXLG.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 120 and level <= 152 then return true end end, mName = "机械人"},
  {mModel = {mFile = "character/v5/01human/SmallWindEagle/SmallWindEagle.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 127 and level <= 160 then return true end end, mName = "小风鹰"},
  {mModel = {mFile = "character/v5/02animals/SophieDragon/SophieDragon.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 134 and level <= 168 then return true end end, mName = "索菲龙"},
  {mModel = {mFile = "character/v5/02animals/XiYiJinJiaoLong/XiYiJinJiaoLong.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 141 and level <= 176 then return true end end, mName = "蜥蜴金蛟龙"},
  {mModel = {mFile = "character/v5/06quest/DisorderRobot/DisorderRobot.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 148 and level <= 184 then return true end end, mName = "无序机器人"},
  {mModel = {mFile = "character/v5/02animals/FireBon/FireBon.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 155 and level <= 192 then return true end end, mName = "冰魔"},
  {mModel = {mFile = "character/v5/01human/Dragon/Dragon.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 162 and level <= 200 then return true end end, mName = "龙"},
  {mModel = {mFile = "character/v5/01human/Messenger/Messenger.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 169 and level <= 208 then return true end end, mName = "蘑菇妖"},
  {mModel = {mFile = "character/v3/GameNpc/XRKZS/XRKZS.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 176 and level <= 216 then return true end end, mName = "熊人战士"},
  {mModel = {mFile = "character/v3/GameNpc/BZL/BZL.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 183 and level <= 224 then return true end end, mName = "冰紫龙"},
  {mModel = {mFile = "character/v3/GameNpc/FEILONG/FEILONG.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 190 and level <= 232 then return true end end, mName = "飞龙"},
  {mModel = {mFile = "character/v3/GameNpc/HUAYAO/HUAYAO.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 197 and level <= 240 then return true end end, mName = "花妖"},
  {mModel = {mFile = "character/v5/02animals/WhiteDragon/WhiteDragon.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 204 and level <= 248 then return true end end, mName = "白龙"},
  {mModel = {mFile = "character/v5/02animals/BlueDragon/BlueDragon.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 211 and level <= 256 then return true end end, mName = "蓝龙"},
  {mModel = {mFile = "character/v5/02animals/CyanDragon/CyanDragon.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 218 and level <= 264 then return true end end, mName = "暴龙"},
  {mModel = {mFile = "character/v5/02animals/EpicDragonDeath/EpicDragonDeath.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 225 and level <= 272 then return true end end, mName = "死亡龙"},
  {mModel = {mFile = "character/v5/02animals/EpicDragonFire/EpicDragonFire.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 232 and level <= 280 then return true end end, mName = "火龙"},
  {mModel = {mFile = "character/v5/02animals/EpicDragonIce/EpicDragonIce.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 239 and level <= 288 then return true end end, mName = "冰龙"},
  {mModel = {mFile = "character/v5/02animals/EpicDragonLife/EpicDragonLife.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 246 and level <= 296 then return true end end, mName = "生命龙"},
  {mModel = {mFile = "character/v5/02animals/EpicDragonStorm/EpicDragonStorm.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 253 and level <= 304 then return true end end, mName = "雷龙"},
  {mModel = {mFile = "character/v5/02animals/GoldenDragon/GoldenDragon_02.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 260 and level <= 312 then return true end end, mName = "金属性龙"},
  {mModel = {mFile = "character/v5/02animals/GreenDragon/GreenDragon_02.x", mScaling =1}, mAttackTime = 1, mStopTime = 1, mAttackRange = 1, mLevelEnable = function(level) if level >= 267 and level <= 320 then return true end end, mName = "绿龙"},
}
GameConfig.mTowerLibrary = {
    {mType = "箭塔",mAttacks = {{mType = "穿刺",mValue = 1,mRange = 1,mSpeed = 1}},mBuildTime = 0,mCost = 10,mModel = {mResource = {hash="Fpwm_tO5WWTM7KdZODWtX-GTr5FB",pid="280",ext="bmax",},mScaling = 1}}
}
GameConfig.mTerrainLibrary = {
    {mTemplateResource = {hash="FhrooRzcFZNtWX9vDBeyah4Bhq2q",pid="19189",ext="bmax",}},
}
GameConfig.mProtecter = {mHP = 3,mModel = {mResource = {hash = "FkgiJVNeYnWcWW68sMUEI7dRGjSE", pid = "14307", ext = "bmax"},mScaling = 1}}
GameConfig.mSafeHouse = {mTemplateResource = {hash = "FpHOk_oMV1lBqaTtMLjqAtqyzJp4", pid = "5453", ext = "bmax"}}
GameConfig.mMatch = {
    mMonsterGenerateSpeed = 0.9,
    mTime = 300
}
GameConfig.mPrepareTime = 1
GameConfig.mBullet = {mModel = {mResource = {hash = "FkgiJVNeYnWcWW68sMUEI7dRGjSE", pid = "14307", ext = "bmax"}}}
GameConfig.mHitEffect = {mModel = {mFile = "character/v5/09effect/ceshi/fire/2/OnHit.x", mScaling = 0.7}}
GameConfig.mSwitchLevelTime = 5
-----------------------------------------------------------------------------------------GameCompute-----------------------------------------------------------------------------------
function GameCompute.computePlayerHP(level)
    return 7 / GameCompute.computeMonsterAttackTime() * GameCompute.computeMonsterAttackValue(level)
end

function GameCompute.computePlayerAttackValue(level)
    return level + 19
end

function GameCompute.computePlayerAttackTime(level)
    local H1 = 0.00005
    local A8 = level
    local H2 = -(0.55 + (100 ^ 2 - 1) * H1) / 99
    local H3 = -H1 + (0.55 + (100 ^ 2 - 1) * H1) / 99 + 0.6
    local J1 = -H2 / (2 * H1)
    local J2 = (4 * H1 * H3 - H2 ^ 2) / (4 * H1)
    return H1 * (A8 - J1) ^ 2 + J2
end

function GameCompute.computePlayerAttackTimePercent(level)
    if level == 1 then
        return 0
    end
    local percent =
        (GameCompute.computePlayerAttackTime(1) - GameCompute.computePlayerAttackTime(level)) /
        GameCompute.computePlayerAttackTime(1)
    return processFloat(percent, 4) * 100
end

function GameCompute.computePlayerFightLevel(hpLevel, attackValueLevel, attackTimeLevel)
    return hpLevel + attackValueLevel + attackTimeLevel
end

function GameCompute.computeMonsterHP(level)
    local C8 = GameCompute.computePlayerAttackValue(level)
    local B3 = 2
    local D8 = GameCompute.computePlayerAttackTime(level)
    return C8 * B3 / D8
end

function GameCompute.computeMonsterAttackValue(level)
    return 9 + level
end

function GameCompute.computeMonsterAttackTime(level)
    return 1
end

function GameCompute.computeMonsterLevel(matchLevel)
    return math.ceil(math.max(matchLevel - 1, 1) / 3)
end

function GameCompute.computeMonsterGenerateCount(matchLevel)
    return 1
    -- local F2 = 45
    -- local F3 = 15
    -- if matchLevel == 1 then
    --     return F2 - F3
    -- elseif matchLevel > 1 then
    --     local level = (matchLevel - 1) % 3
    --     if level == 1 then
    --         return F2 - F3
    --     elseif level == 2 then
    --         return F2
    --     else
    --         return F2 + F3
    --     end
    -- end
end

function GameCompute.computeMonsterGenerateCountScale(players)
    return 1
end

function GameCompute.computeMatchSuccessMoney(matchLevel, playerCount)
    playerCount = math.max(playerCount, 2)
    local averageMonsterCount = 45
    return averageMonsterCount*
        monLootGold(GameCompute.computeMonsterLevel(matchLevel)) *
        (playerCount - 1) /
        playerCount
end
function GameCompute.computeMatchSuccessPlayerPlusMoney(matchLevel, playerCount)
    playerCount = math.max(playerCount, 2)
    local averageMonsterCount = 45
    return averageMonsterCount*
        monLootGold(GameCompute.computeMonsterLevel(matchLevel)) *
        (playerCount - 1) /
        playerCount -
        averageMonsterCount*
        monLootGold(GameCompute.computeMonsterLevel(matchLevel)) *
        1 /2
end

local function getNextLvTime(lv)
    if lv < 11 then
        return 0.015 * lv ^ 2 + 0.1 * lv + 0.6
    elseif lv >= 11 and lv < 31 then
        return 0.019 * lv ^ 2 + 0.1 * lv + 0.2
    elseif lv >= 31 and lv < 61 then
        return 0.035 * lv ^ 2 + 0.1 * lv - 10
    elseif lv >= 61 then
        return 0.09 * lv ^ 2 + 0.3 * lv - 168
    end
end

local function getNextSkillLvGold(lv)
    local C2 = 2
    local nextLvTime = getNextLvTime(lv)
    local killEfficiency = C2 / 60
    local goldEfficiency = lv * 20 + 40
    local nextLvGold = goldEfficiency * nextLvTime
    -- 三个技能升级
    nextSkillLvGold = processFloat(nextLvGold / 3, 2)
    return nextSkillLvGold
end

function monLootGold(lv)
    local C2 = 2
    local nextLvTime = getNextLvTime(lv)
    local killEfficiency = C2 / 60
    local goldEfficiency = lv * 20 + 40
    local nextLvGold = goldEfficiency * nextLvTime
    local nextLvMonNum = nextLvTime / killEfficiency
    local monLootGold = nextLvGold / nextLvMonNum
    return monLootGold
end
------------------------------------------------------------------------------------------UI----------------------------------------------------------------------------
local GUI = require("GUI")
-- local Player = GetPlayer()
-- isServer = (Player.name == "__MP__admin")
-- if isServer then
--     local server = require("server")
-- end
-- local saveData = GetSavedData()
local saveData = getSavedData()
local gameUi = {
    -- 升级界面
    {
        ui_name = "upgrade_background",
        type = "Picture",
        background_color = "0 0 0 255",
        align = "_ct",
        y = 0,
        x = 0,
        height = 400,
        width = 900,
        visible = false
    },
    {
        ui_name = "upgrade_title",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "能力提升"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 45,
        x = function()
            return getUiValue("upgrade_background", "x") - 0
        end,
        y = function()
            return getUiValue("upgrade_background", "y") - 180
        end,
        font_bold = true,
        height = 70,
        width = 300,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "close_button",
        type = "Button",
        align = "_ct",
        background_color = "220 20 60 255",
        text = function()
            local text = "X"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("upgrade_background", "x") + 420
        end,
        y = function()
            return getUiValue("upgrade_background", "y") - 170
        end,
        onclick = function()
            setUiValue("upgrade_background", "visible", false)
        end,
        font_bold = true,
        height = 50,
        width = 50,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_fightingLevel",
        type = "Text",
        align = "_ct",
        text = function()
            local text =
                "战斗力等级:" .. tostring(saveData.mHPLevel + saveData.mAttackValueLevel + saveData.mAttackTimeLevel - 3)
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("upgrade_background", "x") - 250
        end,
        y = function()
            return getUiValue("upgrade_background", "y") - 100
        end,
        font_bold = true,
        height = 70,
        width = 300,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "current_gold",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "金钱：" .. tostring(processFloat(saveData.mMoney, 2))
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("upgrade_background", "x") + 150
        end,
        y = function()
            return getUiValue("upgrade_background", "y") - 100
        end,
        font_bold = true,
        height = 70,
        width = 500,
        text_format = 2,
        --text_border = true,
        shadow = true,
        font_color = "255 215 0",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    -- 血量
    {
        ui_name = "upgrade_HP_background",
        type = "Picture",
        background_color = "12 210 62 255",
        align = "_ct",
        x = function()
            return getUiValue("upgrade_background", "x") - 300
        end,
        y = function()
            return getUiValue("upgrade_background", "y") + 0
        end,
        height = 150,
        width = 200,
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_HP",
        type = "Text",
        align = "_ct",
        text = function()
            local text =
                "生命等级:" ..
                tostring(saveData.mHPLevel - 1) ..
                    "\n\n生命值：" .. tostring(GameCompute.computePlayerHP(saveData.mHPLevel))
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_HP_background", "x") + 20
        end,
        y = function()
            return getUiValue("upgrade_HP_background", "y") - 0
        end,
        font_bold = true,
        height = 100,
        width = 200,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_HP_button",
        type = "Button",
        align = "_ct",
        background_color = "0 0 0 255",
        text = function()
            local text = "升级"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_HP_background", "x") + 0
        end,
        y = function()
            return getUiValue("upgrade_HP_background", "y") + 140
        end,
        onclick = function()
            local money = getNextSkillLvGold(saveData.mHPLevel)
            if saveData.mMoney >= money then
                saveData.mMoney = saveData.mMoney - money
                saveData.mHPLevel = saveData.mHPLevel + 1
                local x,y,z = GetPlayer():GetBlockPos()
                local client_key = EntityCustomManager.singleton():createEntity({mX = x,mY = y,mZ = z,mModel = {mFile = "character/v5/09effect/Upgrade/Upgrade_CirqueGlowRed.x"}},function(hostKey)
                end)
                CommandQueueManager.singleton():post(new(Command_Callback,{mDebug = "UpdateLevel",mExecutingCallback = function(command)
                    command.mTimer = command.mTimer or new(Timer)
                    command.mEntitySyncTimer = command.mEntitySyncTimer or new(Timer)
                    local entity = EntityCustomManager.singleton():getEntityByClientKey(client_key)
                    if command.mEntitySyncTimer:total() > 0.1 then
                        if entity.mHostKey then
                            entity:setPosition(GetPlayer():getPosition()[1],GetPlayer():getPosition()[2],GetPlayer():getPosition()[3])
                        end
                        delete(command.mEntitySyncTimer)
                        command.mEntitySyncTimer = nil
                    end
                    if command.mTimer:total() > 0.5 then
                        EntityCustomManager.singleton():destroyEntity(client_key)
                        command.mState = Command.EState.Finish
                    end
                end}))
            end
        end,
        font_bold = true,
        height = 35,
        width = 80,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_HP_gold",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "需要金钱：" .. tostring(getNextSkillLvGold(saveData.mHPLevel or 1))
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_HP_background", "x") + 0
        end,
        y = function()
            return getUiValue("upgrade_HP_background", "y") + 110
        end,
        font_bold = true,
        height = 50,
        width = 200,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 215 0",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    -- 攻击力
    {
        ui_name = "upgrade_attack_background",
        type = "Picture",
        background_color = "236 45 14 255",
        align = "_ct",
        x = function()
            return getUiValue("upgrade_background", "x") - 0
        end,
        y = function()
            return getUiValue("upgrade_background", "y") + 0
        end,
        height = 150,
        width = 200,
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_attack",
        type = "Text",
        align = "_ct",
        text = function()
            local text =
                "攻击等级:" ..
                tostring(saveData.mAttackValueLevel - 1) ..
                    "\n\n攻击力：" .. tostring(GameCompute.computePlayerAttackValue(saveData.mAttackValueLevel))
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_attack_background", "x") + 20
        end,
        y = function()
            return getUiValue("upgrade_attack_background", "y") + 0
        end,
        font_bold = true,
        height = 100,
        width = 200,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_attack_button",
        type = "Button",
        align = "_ct",
        background_color = "0 0 0 255",
        text = function()
            local text = "升级"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_attack_background", "x") + 0
        end,
        y = function()
            return getUiValue("upgrade_attack_background", "y") + 140
        end,
        onclick = function()
            local money = getNextSkillLvGold(saveData.mAttackValueLevel)
            if saveData.mMoney >= money then
                saveData.mMoney = saveData.mMoney - money
                saveData.mAttackValueLevel = saveData.mAttackValueLevel + 1
                local x,y,z = GetPlayer():GetBlockPos()
                local client_key = EntityCustomManager.singleton():createEntity({mX = x,mY = y,mZ = z,mModel = {mFile = "character/v5/09effect/Upgrade/Upgrade_CirqueGlowRed.x"}},function(hostKey)
                end)
                CommandQueueManager.singleton():post(new(Command_Callback,{mDebug = "UpdateLevel",mExecutingCallback = function(command)
                    command.mTimer = command.mTimer or new(Timer)
                    command.mEntitySyncTimer = command.mEntitySyncTimer or new(Timer)
                    local entity = EntityCustomManager.singleton():getEntityByClientKey(client_key)
                    if command.mEntitySyncTimer:total() > 0.1 then
                        if entity.mHostKey then
                            entity:setPosition(GetPlayer():getPosition()[1],GetPlayer():getPosition()[2],GetPlayer():getPosition()[3])
                        end
                        delete(command.mEntitySyncTimer)
                        command.mEntitySyncTimer = nil
                    end
                    if command.mTimer:total() > 0.5 then
                        EntityCustomManager.singleton():destroyEntity(client_key)
                        command.mState = Command.EState.Finish
                    end
                end}))
            end
        end,
        font_bold = true,
        height = 35,
        width = 80,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_attack_gold",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "需要金钱：" .. tostring(getNextSkillLvGold(saveData.mAttackValueLevel or 1))
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_attack_background", "x") + 0
        end,
        y = function()
            return getUiValue("upgrade_attack_background", "y") + 110
        end,
        font_bold = true,
        height = 50,
        width = 200,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 215 0",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    -- 攻速
    {
        ui_name = "upgrade_attSpeed_background",
        type = "Picture",
        background_color = "245 230 9 255",
        align = "_ct",
        x = function()
            return getUiValue("upgrade_background", "x") + 300
        end,
        y = function()
            return getUiValue("upgrade_background", "y") + 0
        end,
        height = 150,
        width = 200,
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_attSpeed",
        type = "Text",
        align = "_ct",
        text = function()
            local text =
                "攻速等级:" ..
                tostring(saveData.mAttackTimeLevel - 1) ..
                    "\n\n攻速提升：" ..
                        tostring(GameCompute.computePlayerAttackTimePercent(saveData.mAttackTimeLevel)) .. "%"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_attSpeed_background", "x") + 20
        end,
        y = function()
            return getUiValue("upgrade_attSpeed_background", "y") + 0
        end,
        font_bold = true,
        height = 100,
        width = 200,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_attSpeed_button",
        type = "Button",
        align = "_ct",
        background_color = "0 0 0 255",
        text = function()
            local text = "升级"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_attSpeed_background", "x") + 0
        end,
        y = function()
            return getUiValue("upgrade_attSpeed_background", "y") + 140
        end,
        onclick = function()
            local money = getNextSkillLvGold(saveData.mAttackTimeLevel)
            if saveData.mMoney >= money then
                saveData.mMoney = saveData.mMoney - money
                saveData.mAttackTimeLevel = saveData.mAttackTimeLevel + 1
                local x,y,z = GetPlayer():GetBlockPos()
                local client_key = EntityCustomManager.singleton():createEntity({mX = x,mY = y,mZ = z,mModel = {mFile = "character/v5/09effect/Upgrade/Upgrade_CirqueGlowRed.x"}},function(hostKey)
                end)
                CommandQueueManager.singleton():post(new(Command_Callback,{mDebug = "UpdateLevel",mExecutingCallback = function(command)
                    command.mTimer = command.mTimer or new(Timer)
                    command.mEntitySyncTimer = command.mEntitySyncTimer or new(Timer)
                    local entity = EntityCustomManager.singleton():getEntityByClientKey(client_key)
                    if command.mEntitySyncTimer:total() > 0.1 then
                        if entity.mHostKey then
                            entity:setPosition(GetPlayer():getPosition()[1],GetPlayer():getPosition()[2],GetPlayer():getPosition()[3])
                        end
                        delete(command.mEntitySyncTimer)
                        command.mEntitySyncTimer = nil
                    end
                    if command.mTimer:total() > 0.5 then
                        EntityCustomManager.singleton():destroyEntity(client_key)
                        command.mState = Command.EState.Finish
                    end
                end}))
            end
        end,
        font_bold = true,
        height = 35,
        width = 80,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    {
        ui_name = "upgrade_attSpeed_gold",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "需要金钱：" .. tostring(getNextSkillLvGold(saveData.mAttackTimeLevel or 1))
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("upgrade_attSpeed_background", "x") + 0
        end,
        y = function()
            return getUiValue("upgrade_attSpeed_background", "y") + 110
        end,
        font_bold = true,
        height = 50,
        width = 200,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 215 0",
        visible = function()
            return getUiValue("upgrade_background", "visible")
        end
    },
    -- 左下角状态栏
    {
        ui_name = "state_background",
        type = "Picture",
        background_color = "0 0 0 255",
        align = "_lb",
        y = -10,
        x = 10,
        height = 250,
        width = 300,
        visible = true
    },
    {
        ui_name = "state_current_gold",
        type = "Text",
        align = "_lb",
        text = function()
            local text = "金钱：" .. tostring(processFloat(saveData.mMoney, 2))
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("state_background", "x") + 0
        end,
        y = function()
            return getUiValue("state_background", "y") - 170
        end,
        font_bold = true,
        height = 70,
        width = 500,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 215 0",
        visible = function()
            return getUiValue("state_background", "visible")
        end
    },
    {
        ui_name = "state_fightingLevel",
        type = "Text",
        align = "_lb",
        text = function()
            local text =
                "战斗力等级:" .. tostring(saveData.mHPLevel + saveData.mAttackValueLevel + saveData.mAttackTimeLevel - 3)
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("state_background", "x") - 0
        end,
        y = function()
            return getUiValue("state_background", "y") - 120
        end,
        font_bold = true,
        height = 70,
        width = 400,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("state_background", "visible")
        end
    },
    {
        ui_name = "state_levels",
        type = "Text",
        align = "_lb",
        text = function()
            local text =
                "生命(Lv" ..
                tostring(saveData.mHPLevel - 1) ..
                    ")：" ..
                        tostring(GameCompute.computePlayerHP(saveData.mHPLevel)) ..
                            "\n攻击(lv" ..
                                tostring(saveData.mAttackValueLevel - 1) ..
                                    ")：" ..
                                        tostring(GameCompute.computePlayerAttackValue(saveData.mAttackValueLevel)) ..
                                            "\n攻速(lv" ..
                                                tostring(saveData.mAttackTimeLevel - 1) ..
                                                    ")：" ..
                                                        tostring(
                                                            GameCompute.computePlayerAttackTimePercent(
                                                                saveData.mAttackTimeLevel
                                                            )
                                                        ) ..
                                                            "%\n"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("state_background", "x") - 0
        end,
        y = function()
            return getUiValue("state_background", "y") - 30
        end,
        font_bold = true,
        height = 100,
        width = 400,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("state_background", "visible")
        end
    },
    {
        ui_name = "upgrade_button",
        type = "Button",
        align = "_lb",
        background_color = "22 255 0 255",
        text = function()
            local text = "升级(U)"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("state_background", "x") + 200
        end,
        y = function()
            return getUiValue("state_background", "y") - 60
        end,
        onclick = function()
            setUiValue("upgrade_background", "visible", true)
        end,
        font_bold = true,
        height = 50,
        width = 100,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("state_background", "visible")
        end
    },
    -- 关卡信息
    {
        ui_name = "levelInfo_background",
        type = "Picture",
        background_color = "0 0 0 0",
        align = "_ctt",
        y = 0,
        x = 0,
        height = 200,
        width = 300,
        visible = false
    },
    {
        ui_name = "levelInfo_monsterLeft",
        type = "Text",
        align = "_ctt",
        text = function()
            if Client_Game.singleton():getMonsterManager():getProperty():cache().mMonsterCount then
                local text =
                    "怪物剩余：" .. tostring(Client_Game.singleton():getMonsterManager():getProperty():cache().mMonsterCount)
                return text
            end
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("levelInfo_background", "x") - 190
        end,
        y = function()
            return getUiValue("levelInfo_background", "y") - 0
        end,
        font_bold = true,
        height = 100,
        width = 220,
        text_format = 2,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("levelInfo_background", "visible")
        end
    },
    {
        ui_name = "levelInfo_currentLevel",
        type = "Text",
        align = "_ctt",
        text = function()
            local text = "关卡：" .. tostring(Client_Game.singleton():getProperty():cache().mLevel)
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("levelInfo_background", "x") + 280
        end,
        y = function()
            return getUiValue("levelInfo_background", "y") - 0
        end,
        font_bold = true,
        height = 100,
        width = 400,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("levelInfo_background", "visible")
        end
    },
    {
        ui_name = "levelInfo_timeLeft",
        type = "Text",
        align = "_ctt",
        text = function()
            local text =
                "剩余时间：" ..
                tostring(
                    math.floor(Client_Game.singleton():getProperty():cache().mFightLeftTime or GameConfig.mMatch.mTime)
                ) ..
                    "秒"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("levelInfo_background", "x") + 0
        end,
        y = function()
            return getUiValue("levelInfo_background", "y") + 60
        end,
        font_bold = true,
        height = 100,
        width = 300,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("levelInfo_background", "visible")
        end
    },
    {
        ui_name = "chooseLv_vote_button",
        type = "Button",
        align = "_ctt",
        background_color = "22 255 0 255",
        text = function()
            local text = "选关投票(L)"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 18,
        x = function()
            return getUiValue("levelInfo_background", "x") + 370
        end,
        y = function()
            return getUiValue("levelInfo_background", "y") + 5
        end,
        onclick = function()
            setUiValue("chooseLevel_background", "visible", true)
        end,
        font_bold = true,
        height = 40,
        width = 120,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return true
        end
    },
    -- 排行榜
    {
        ui_name = "ranking_background",
        type = "Picture",
        background_color = "0 0 0 0",
        align = "_rt",
        y = 0,
        x = 0,
        height = 200,
        width = 300,
        visible = true
    },
    {
        ui_name = "ranking_tip",
        type = "Text",
        align = "_rt",
        text = function()
            local text = "按tab打开/关闭排行榜"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 18,
        x = function()
            return getUiValue("ranking_background", "x") + 0
        end,
        y = function()
            return getUiValue("ranking_background", "y") + 100
        end,
        font_bold = true,
        height = 100,
        width = 200,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255 150",
        visible = function()
            return true
            -- return getUiValue("ranking_background", "visible")
        end
    },
    {
        ui_name = "ranking_tittle",
        type = "Text",
        align = "_rt",
        text = function()
            local text = "玩家        战斗力等级     金钱         杀怪数"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 18,
        x = function()
            return getUiValue("ranking_background", "x") + 80
        end,
        y = function()
            return getUiValue("ranking_background", "y") + 130
        end,
        font_bold = true,
        height = 100,
        width = 400,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("ranking_background", "visible")
        end
    },
    {
        ui_name = "ranking_playerName",
        type = "Text",
        align = "_rt",
        text = function()
            local players = Client_Game.singleton():getPlayerManager():getPlayersSortByFightLevel()
            local text = ""
            for i, player in pairs(players) do
                if GetEntityById(player:getID()) then
                    text = text .. tostring(i) .. "." .. GetEntityById(player:getID()).nickname .. "\n"
                end
            end
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 18,
        x = function()
            return getUiValue("ranking_background", "x") - 210
        end,
        y = function()
            return getUiValue("ranking_background", "y") + 160
        end,
        font_bold = true,
        height = 500,
        width = 150,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("ranking_background", "visible")
        end
    },
    {
        ui_name = "ranking_fightLevel",
        type = "Text",
        align = "_rt",
        text = function()
            local players = Client_Game.singleton():getPlayerManager():getPlayersSortByFightLevel()
            local text = ""
            for i, player in pairs(players) do
                text =
                    text ..
                    tostring(
                        GameCompute.computePlayerFightLevel(
                            (player:getProperty():cache().mHPLevel or 1) - 1,
                            (player:getProperty():cache().mAttackValueLevel or 1) - 1,
                            (player:getProperty():cache().mAttackTimeLevel or 1) - 1
                        )
                    ) ..
                        "\n"
            end
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 18,
        x = function()
            return getUiValue("ranking_background", "x") - 170
        end,
        y = function()
            return getUiValue("ranking_background", "y") + 160
        end,
        font_bold = true,
        height = 500,
        width = 50,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("ranking_background", "visible")
        end
    },
    {
        ui_name = "ranking_gold",
        type = "Text",
        align = "_rt",
        text = function()
            local players = Client_Game.singleton():getPlayerManager():getPlayersSortByFightLevel()
            local text = ""
            for i, player in pairs(players) do
                text = text .. tostring(processFloat(player:getProperty():cache().mMoney or 0, 2)) .. "\n"
            end
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 18,
        x = function()
            return getUiValue("ranking_background", "x") - 50
        end,
        y = function()
            return getUiValue("ranking_background", "y") + 160
        end,
        font_bold = true,
        height = 500,
        width = 100,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("ranking_background", "visible")
        end
    },
    {
        ui_name = "ranking_kills",
        type = "Text",
        align = "_rt",
        text = function()
            local players = Client_Game.singleton():getPlayerManager():getPlayersSortByFightLevel()
            local text = ""
            for i, player in pairs(players) do
                text = text .. tostring(player:getProperty():cache().mKill) .. "\n"
            end
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 18,
        x = function()
            return getUiValue("ranking_background", "x") + 30
        end,
        y = function()
            return getUiValue("ranking_background", "y") + 160
        end,
        font_bold = true,
        height = 500,
        width = 100,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("ranking_background", "visible")
        end
    },
    -- 选关界面
    {
        ui_name = "chooseLevel_background",
        type = "Picture",
        background_color = "0 0 0 255",
        align = "_ct",
        y = 0,
        x = 0,
        height = 400,
        width = 800,
        visible = false
    },
    {
        ui_name = "close_chooseLevel_button",
        type = "Button",
        align = "_ct",
        background_color = "220 20 60 255",
        text = function()
            local text = "X"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") + 370
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") - 170
        end,
        onclick = function()
            setUiValue("chooseLevel_background", "visible", false)
        end,
        font_bold = true,
        height = 50,
        width = 50,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "chooseLevel_title",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "选关投票"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 40,
        x = function()
            return getUiValue("chooseLevel_background", "x") + 0
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") - 180
        end,
        font_bold = true,
        height = 50,
        width = 200,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "chooseLevel_text",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "1.仅能选择低于自己战斗力等级的关卡发起投票\n2.需要大于50%的队友同意，才能选关成功"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("chooseLevel_background", "x") + 50
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") - 100
        end,
        font_bold = true,
        height = 100,
        width = 500,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level1_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "1"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") - 300
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") - 40
        end,
        onclick = function()
          local level = 1
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level2_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "30"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") - 150
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") - 40
        end,
        onclick = function()
          local level = 30
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level3_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "60"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") - 0
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") - 40
        end,
        onclick = function()
          local level = 60
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level4_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "90"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") + 150
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") - 40
        end,
        onclick = function()
          local level = 90
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level5_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "120"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") + 300
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") - 40
        end,
        onclick = function()
          local level = 120
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level6_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "150"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") - 300
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") + 80
        end,
        onclick = function()
          local level = 150
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level7_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "180"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") - 150
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") + 80
        end,
        onclick = function()
          local level = 180
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level8_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "210"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") - 0
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") + 80
        end,
        onclick = function()
          local level = 210
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level9_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "240"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") + 150
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") + 80
        end,
        onclick = function()
          local level = 240
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "level10_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "270"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("chooseLevel_background", "x") + 300
        end,
        y = function()
            return getUiValue("chooseLevel_background", "y") + 80
        end,
        onclick = function()
          local level = 270
          local player = Client_Game.singleton():getPlayerManager():getPlayerByID()
          local fightLevel = GameCompute.computePlayerFightLevel(
              (player:getProperty():cache().mHPLevel or 1) - 1,
              (player:getProperty():cache().mAttackValueLevel or 1) - 1,
              (player:getProperty():cache().mAttackTimeLevel or 1) - 1
          )
          if fightLevel >= level then
            Tip("你已选择关卡"..level.."等待其他玩家投票...", 3000, "255 255 0", "reload")
            Client_Game.singleton():switchLevel(level)
          else
            Tip("需要战斗力等级达到"..level.."，才能选择此关！", 3000, "255 255 0", "reload")
          end
        end,
        font_bold = true,
        height = 50,
        width = 80,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("chooseLevel_background", "visible")
        end
    },
    {
        ui_name = "voteLevel_background",
        type = "Picture",
        background_color = "0 0 0 255",
        align = "_ct",
        y = 0,
        x = 0,
        height = 400,
        width = 800,
        visible = false
    },
    {
        ui_name = "close_voteLevel_button",
        type = "Button",
        align = "_ct",
        background_color = "220 20 60 255",
        text = function()
            local text = "X"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("voteLevel_background", "x") + 370
        end,
        y = function()
            return getUiValue("voteLevel_background", "y") - 170
        end,
        onclick = function()
            setUiValue("voteLevel_background", "visible", false)
        end,
        font_bold = true,
        height = 50,
        width = 50,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("voteLevel_background", "visible")
        end
    },
    {
        ui_name = "voteLevel_title",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "换关投票"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 40,
        x = function()
            return getUiValue("voteLevel_background", "x") + 0
        end,
        y = function()
            return getUiValue("voteLevel_background", "y") - 150
        end,
        font_bold = true,
        height = 100,
        width = 500,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("voteLevel_background", "visible")
        end
    },
    {
        ui_name = "voteTimeLeft",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "剩余时间：200"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("voteLevel_background", "x") - 250
        end,
        y = function()
            return getUiValue("voteLevel_background", "y") - 150
        end,
        onclick = function()
            -- closeSafeHouseUI()
        end,
        font_bold = true,
        height = 50,
        width = 250,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("voteLevel_background", "visible")
        end
    },
    {
        ui_name = "voteLevel_text",
        type = "Text",
        align = "_ct",
        text = function()
            -- local text = "战斗力等级:" .. tostring(saveData.mHPLevel + saveData.mAttackValueLevel + saveData.mAttackTimeLevel)
            local text = "玩家名玩家名 想切换到关卡等级200，是否同意？"
            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 20,
        x = function()
            return getUiValue("voteLevel_background", "x") + 50
        end,
        y = function()
            return getUiValue("voteLevel_background", "y") - 100
        end,
        font_bold = true,
        height = 100,
        width = 500,
        text_format = 0,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("voteLevel_background", "visible")
        end
    },
    {
        ui_name = "agree_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "同意(Y)"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("voteLevel_background", "x") - 180
        end,
        y = function()
            return getUiValue("voteLevel_background", "y") + 0
        end,
        onclick = function()
            -- closeSafeHouseUI()
            if getUiValue("agree_button","onclickCallback") then
                getUiValue("agree_button","onclickCallback")()
            end
            setUiValue("agree_text","font_color","255 255 0")
            setUiValue("disagree_text","font_color","255 255 255")
        end,
        font_bold = true,
        height = 50,
        width = 150,
        text_format = 5,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("voteLevel_background", "visible")
        end,
        enabled = true
    },
    {
        ui_name = "disagree_button",
        type = "Button",
        align = "_ct",
        background_color = "255 255 255 255",
        text = function()
            local text = "不同意(N)"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("voteLevel_background", "x") + 180
        end,
        y = function()
            return getUiValue("voteLevel_background", "y") + 0
        end,
        onclick = function()
            -- closeSafeHouseUI()
            if getUiValue("disagree_button","onclickCallback") then
                getUiValue("disagree_button","onclickCallback")()
            end
            setUiValue("agree_text","font_color","255 255 255")
            setUiValue("disagree_text","font_color","255 255 0")
        end,
        font_bold = true,
        height = 50,
        width = 150,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "220 20 60",
        visible = function()
            return getUiValue("voteLevel_background", "visible")
        end,
        enabled = true
    },
    {
        ui_name = "agree_text",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "(10票)"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("voteLevel_background", "x") - 180
        end,
        y = function()
            return getUiValue("voteLevel_background", "y") + 80
        end,
        onclick = function()
            -- closeSafeHouseUI()
        end,
        font_bold = true,
        height = 50,
        width = 150,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("voteLevel_background", "visible")
        end
    },
    {
        ui_name = "disagree_text",
        type = "Text",
        align = "_ct",
        text = function()
            local text = "(10票)"

            return text
        end,
        -- font_type = "Source Han Sans SC Bold",
        font_size = 30,
        x = function()
            return getUiValue("voteLevel_background", "x") + 180
        end,
        y = function()
            return getUiValue("voteLevel_background", "y") + 80
        end,
        onclick = function()
            -- closeSafeHouseUI()
        end,
        font_bold = true,
        height = 50,
        width = 150,
        text_format = 1,
        --text_border = true,
        shadow = true,
        font_color = "255 255 255",
        visible = function()
            return getUiValue("voteLevel_background", "visible")
        end
    }
}

function initUi()
    for i = 1, #gameUi do
        GUI.UI(gameUi[i])
    end
end

function uninitUi()
    for i = 1, #gameUi do
        gameUi[i].destroy = true
    end
end

function getUi(name)
    for i = 1, #gameUi do
        if gameUi[i].ui_name == name then
            return gameUi[i]
        end
    end
    return {}
end

function getUiValue(ui_name, key)
    local ui = getUi(ui_name)
    if type(ui[key]) == "function" then
        return ui[key]()
    end
    return ui[key]
end

function setUiValue(ui_name, key, value)
    local ui = getUi(ui_name)
    if ui then
        ui[key] = value
    end
end

function showUi(name)
    local ui = getUi(name)
    if ui then
        ui.visible = true
    end
end

function hideUi(name)
    local ui = getUi(name)
    if ui then
        ui.visible = false
    end
end
-----------------------------------------------------------------------------------------GamePlayerProperty-----------------------------------------------------------------------------------
function GamePlayerProperty:construction(parameter)
    self.mPlayerID = parameter.mPlayerID
end

function GamePlayerProperty:destruction()
end

function GamePlayerProperty:_getLockKey(propertyName)
    return "GamePlayerProperty/" .. tostring(self.mPlayerID) .. "/" .. propertyName
end
-----------------------------------------------------------------------------------------GameMonsterProperty-----------------------------------------------------------------------------------
function GameMonsterProperty:construction(parameter)
    self.mID = parameter.mID
end

function GameMonsterProperty:destruction()
end

function GameMonsterProperty:_getLockKey(propertyName)
    return "GameMonsterProperty/" .. tostring(self.mID) .. "/" .. propertyName
end
-----------------------------------------------------------------------------------------GameMonsterManagerProperty-----------------------------------------------------------------------------------
function GameMonsterManagerProperty:construction(parameter)
end

function GameMonsterManagerProperty:destruction()
end

function GameMonsterManagerProperty:_getLockKey(propertyName)
    return "GameMonsterProperty/" .. propertyName
end
-----------------------------------------------------------------------------------------GameProperty-----------------------------------------------------------------------------------
function GameProperty:construction(parameter)
end

function GameProperty:destruction()
end

function GameProperty:_getLockKey(propertyName)
    return "GameProperty/" .. propertyName
end
-----------------------------------------------------------------------------------------GameProtecterProperty-----------------------------------------------------------------------------------
function GameProtecterProperty:construction(parameter)
end

function GameProtecterProperty:destruction()
end

function GameProtecterProperty:_getLockKey(propertyName)
    return "GameProtecterProperty/" .. propertyName
end
-----------------------------------------------------------------------------------------GameEffectManager-----------------------------------------------------------------------------------
GameEffectManager.Effect = {}
function GameEffectManager.Effect:construction(parameter)
end

function GameEffectManager.Effect:destruction()
    self.mDelete = true
end

GameEffectManager.MonsterDead = inherit(GameEffectManager.Effect)
GameEffectManager.MonsterDead.PlayerEffect = {}

function GameEffectManager.MonsterDead.PlayerEffect:construction(parameter)
    local src_position = vector3d:new(parameter.mMonsterInfo.mPosition)
    self.mTargetPosition = vector3d:new(parameter.mPlayerInfo.mPosition) - src_position
    self.mBillboardSet = CreateBillboardSet(src_position[1], src_position[2], src_position[3])
    self.mBillboardSet:setDefaultDimensions(1, 1)
    self.mBillboardSet:setTexture(CreateItemStack(142):GetIcon())
    self.mBillboards = {}
    local billboard_count = math.ceil(parameter.mPlayerInfo.mMoney / 1)
    for i = 1, billboard_count do
        local billboard = self.mBillboardSet:createBillboard()
        billboard:setPosition(math.random(-1, 1), math.random(-1, 1), math.random(-1, 1))
        self.mBillboards[#self.mBillboards + 1] = {
            mBillboard = billboard,
            mDirection = (self.mTargetPosition - billboard:getPosition()):normalize()
        }
    end
end

function GameEffectManager.MonsterDead.PlayerEffect:destruction()
    self.mBillboards = nil
    self.mBillboardSet:delete()
    self.mBillboardSet = nil
end

function GameEffectManager.MonsterDead.PlayerEffect:update()
    self.mBillboardSet:render()
    local need_delete = true
    for _, billboard in pairs(self.mBillboards) do
        need_delete = need_delete and billboard.mBillboard:getPosition():equals(self.mTargetPosition, 0.01)
    end
    if need_delete then
        delete(self)
    else
        self.mTimer = self.mTimer or new(Timer)
        for _, billboard in pairs(self.mBillboards) do
            local new_pos = billboard.mBillboard:getPosition() + billboard.mDirection * self.mTimer:total() * 10
            if billboard.mDirection[1] > 0 then
                new_pos[1] = math.min(self.mTargetPosition[1], new_pos[1])
            else
                new_pos[1] = math.max(self.mTargetPosition[1], new_pos[1])
            end
            if billboard.mDirection[2] > 0 then
                new_pos[2] = math.min(self.mTargetPosition[2], new_pos[2])
            else
                new_pos[2] = math.max(self.mTargetPosition[2], new_pos[2])
            end
            if billboard.mDirection[3] > 0 then
                new_pos[3] = math.min(self.mTargetPosition[3], new_pos[3])
            else
                new_pos[3] = math.max(self.mTargetPosition[3], new_pos[3])
            end
            billboard.mBillboard:setPosition(new_pos[1], new_pos[2], new_pos[3])
        end
    end
end

function GameEffectManager.MonsterDead:construction(parameter)
    self.mPlayerEffects = {}
    for _, player_info in pairs(parameter.mPlayerInfos) do
        self.mPlayerEffects[#self.mPlayerEffects + 1] =
            new(
            GameEffectManager.MonsterDead.PlayerEffect,
            {mPlayerInfo = player_info, mMonsterInfo = parameter.mMonsterInfo}
        )
    end
end

function GameEffectManager.MonsterDead:destruction()
    for _, effect in pairs(self.mPlayerEffects) do
        delete(effect)
    end
    self.mPlayerEffects = nil
end

function GameEffectManager.MonsterDead:update()
    local index = 1
    while index <= #self.mPlayerEffects do
        local effect = self.mPlayerEffects[index]
        if effect.mBillboardSet then
            effect:update()
            index = index + 1
        else
            table.remove(self.mPlayerEffects, index)
        end
    end
    if #self.mPlayerEffects == 0 then
        delete(self)
    end
end

function GameEffectManager:construction()
    self.mEffects = {}
end

function GameEffectManager:destruction()
    for _, effect in pairs(self.mEffects) do
        delete(effect)
    end
    self.mEffects = nil
end

function GameEffectManager:createMonsterDead(monsterInfo, playerInfos)
    self.mEffects[#self.mEffects + 1] =
        new(GameEffectManager.MonsterDead, {mMonsterInfo = monsterInfo, mPlayerInfos = playerInfos})
end

function GameEffectManager:update()
    local index = 1
    while index <= #self.mEffects do
        local effect = self.mEffects[index]
        if effect.mDelete then
            table.remove(self.mEffects, index)
        else
            effect:update()
            index = index + 1
        end
    end
end
-----------------------------------------------------------------------------------------Host_Game-----------------------------------------------------------------------------------
function Host_Game.singleton()
    return Host_Game.msInstance
end

function Host_Game:construction()
    Host_Game.msInstance = self
    self.mCommandQueue = CommandQueueManager.singleton():createQueue()
    self.mProperty = new(GameProperty)
    self.mEffectManager = new(Host_GameEffectManager)
    self.mSafeHouse = {}
    self.mProtecter = new(Host_GameProtecter)
    local x, y, z = GetHomePosition()
    x, y, z = ConvertToBlockIndex(x, y + 0.5, z)
    y = y - 1
    self.mSafeHouse.mTerrain =
        new(
        Host_GameTerrain,
        {mTemplateResource = GameConfig.mSafeHouse.mTemplateResource, mHomePosition = {x, y + 100, z}}
    )
    self.mSafeHouse.mTerrain:applyTemplate(
        function()
            self.mPlayerManager = new(Host_GamePlayerManager)
            self.mMonsterManager = new(Host_GameMonsterManager)
            self:start()
        end
    )
    Host.addListener("Game", self)
end

function Host_Game:destruction()
    CommandQueueManager.singleton():destroyQueue(self.mCommandQueue)
    delete(self.mPlayerManager)
    self.mPlayerManager = nil
    delete(self.mMonsterManager)
    self.mMonsterManager = nil
    delete(self.mEffectManager)
    self.mEffectManager = nil
    if self.mSafeHouse then
        delete(self.mSafeHouse.mTerrain)
    end
    if self.mScene then
        delete(self.mScene.mTerrain)
    end
    if self.mProtecter then
        delete(self.mProtecter)
    end
    self.mProperty:safeWrite("mLevel")
    self.mProperty:safeWrite("mWaveLevel")
    self.mProperty:safeWrite("mState")
    self.mProperty:safeWrite("mSafeHouseLeftTime")
    self.mProperty:safeWrite("mFightLeftTime")
    self.mProperty:safeWrite("mSwitchLevel")
    self.mProperty:safeWrite("mSwitchLevelAgree")
    self.mProperty:safeWrite("mSwitchLevelDisagree")
    self.mProperty:safeWrite("mWavePrepareLeftTime")
    delete(self.mProperty)
    Host.removeListener("Game", self)
    Host_Game.msInstance = nil
end

function Host_Game:update(deltaTime)
    if self.mPlayerManager then
        self.mPlayerManager:update(deltaTime)
    end
    if self.mMonsterManager then
        self.mMonsterManager:update(deltaTime)
    end
    if self.mEffectManager then
        self.mEffectManager:update(deltaTime)
    end
    if self.mSafeHouse then
        self.mSafeHouse.mTerrain:update()
    end
    if self.mScene then
        self.mScene.mTerrain:update()
    end
end

function Host_Game:receive(parameter)
    if parameter.mMessage == "SwitchLevelRequest" then
        if self.mSwitchLevelRequester then
            self:sendToClient(parameter.mFrom, "SwitchLevelRequest_Response", {mResult = false})
        else
            self:sendToClient(parameter.mFrom, "SwitchLevelRequest_Response", {mResult = true})
            self.mSwitchLevelRequester = parameter.mFrom
            self:broadcast(
                "SwitchLevel",
                {mRequester = self.mSwitchLevelRequester, mLevel = parameter.mParameter.mLevel}
            )
            CommandQueueManager.singleton():post(
                new(
                    Command_Callback,
                    {
                        mDebug = "Host_Game:receive/SwitchLevelRequest",
                        mExecutingCallback = function(command)
                            command.mTimer = command.mTimer or new(Timer)
                            if command.mTimer:total() > GameConfig.mSwitchLevelTime then
                                if
                                    self.mProperty:cache().mSwitchLevelAgree and
                                        self.mProperty:cache().mSwitchLevelAgree >=
                                            math.floor(#self.mPlayerManager.mPlayers * 0.5)
                                 then
                                    self.mProperty:safeWrite("mSwitchLevel", parameter.mParameter.mLevel)
                                end
                                self.mSwitchLevelRequester = nil
                                self.mProperty:safeWrite("mSwitchLevelAgree")
                                self.mProperty:safeWrite("mSwitchLevelDisagree")
                                command.mState = Command.EState.Finish
                            end
                        end
                    }
                )
            )
        end
    elseif parameter.mMessage == "SwitchLevelAnswer" then
        if parameter.mParameter.mResult and parameter.mParameter.mRequester == self.mSwitchLevelRequester then
            self.mProperty:safeWrite("mSwitchLevelAgree", (self.mProperty:cache().mSwitchLevelAgree or 0) + 1)
        elseif not parameter.mParameter.mResult and parameter.mParameter.mRequester == self.mSwitchLevelRequester then
            self.mProperty:safeWrite("mSwitchLevelDisagree", (self.mProperty:cache().mSwitchLevelDisagree or 0) + 1)
        end
    end
end

function Host_Game:broadcast(message, parameter)
    Host.broadcast({mKey = "Game", mMessage = message, mParameter = parameter})
end

function Host_Game:sendToClient(playerID, message, parameter)
    Host.sendTo(playerID, {mKey = "Game", mMessage = message, mParameter = parameter})
end

function Host_Game:getPlayerManager()
    return self.mPlayerManager
end

function Host_Game:getMonsterManager()
    return self.mMonsterManager
end

function Host_Game:getEffectManager()
    return self.mEffectManager
end

function Host_Game:getProtecter()
    return self.mProtecter
end

function Host_Game:setScene(scene, callback)
    if self.mScene then
        delete(self.mScene.mTerrain)
    end
    self.mScene = scene
    if self.mScene then
        self.mProperty:safeWrite("mState", "Fight")
        self.mProperty:safeWrite("mFightLeftTime", GameConfig.mMatch.mTime)
        self.mProperty:safeWrite("mSafeHouseLeftTime")
        self.mScene.mTerrain:applyTemplate(
            function()
                self.mPlayerManager:setScene(self.mScene)
                self.mMonsterManager:setScene(self.mScene)
                self.mProtecter:setScene(self.mScene)
                callback()
            end
        )
    else
        self.mPlayerManager:setScene(self.mSafeHouse)
        self.mMonsterManager:setScene(self.mSafeHouse)
        self.mProtecter:setScene(self.mSafeHouse)
        callback()
    end
end

function Host_Game:start()
    self.mProperty:safeWrite("mLevel", self.mProperty:cache().mSwitchLevel or 1)
    self.mProperty:safeWrite("mSwitchLevel")
    self.mProperty:safeWrite("mState", "SafeHouse")
    self.mProperty:safeWrite("mSafeHouseLeftTime", GameConfig.mPrepareTime)
    self.mPlayerManager:initializePlayerProperties()
    self:setScene(
        nil,
        function()
            self:_nextMatch()
        end
    )
end

function Host_Game:getProperty()
    return self.mProperty
end

function Host_Game:_startWave(wave)
    self.mProperty:safeWrite("mWaveLevel", wave or 1)
    self.mProperty:safeWrite("mWavePrepareLeftTime", GameConfig.mPrepareTime)
    self.mPlayerManager:initializePlayerProperties()
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Host_Game:_startWave/Prepare",
                mExecutingCallback = function(command)
                    command.mTimer = command.mTimer or new(Timer)
                    if command.mTimer:total() >= GameConfig.mPrepareTime then
                        command.mState = Command.EState.Finish
                        self.mProperty:safeWrite("mWavePrepareLeftTime")
                    else
                        local left_time = math.floor(GameConfig.mPrepareTime - command.mTimer:total())
                        if left_time ~= self.mProperty:cache().mSafeHouseLeftTime then
                            self.mProperty:safeWrite("mWavePrepareLeftTime", left_time)
                        end
                    end
                end
            }
        )
    )
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Host_Game:_startWave/Start",
                mTimeOutProcess = function()end,
                mExecuteCallback = function(command)
                    self.mMonsterManager:setScene(self.mScene)
                end,
                mExecutingCallback = function(command)
                    --check time up
                    command.mTimer = command.mTimer or new(Timer)
                    if command.mTimer:total() >= GameConfig.mMatch.mTime then
                        self:broadcast("FightFail")
                        command.mState = Command.EState.Finish
                        self:start()
                        return
                    else
                        local left_time = math.floor(GameConfig.mMatch.mTime - command.mTimer:total())
                        if left_time ~= self.mProperty:cache().mFightLeftTime then
                            self.mProperty:safeWrite("mFightLeftTime", left_time)
                        end
                    end
                    --check success
                    if self.mMonsterManager:isAllDead() then
                        self:broadcast("WaveSuccess")
                        command.mState = Command.EState.Finish
                        self:_startWave(self.mProperty:cache().mWaveLevel + 1)
                    elseif self.mProtecter:getProperty():cache().mHP <= 0 then--check failed
                        self:broadcast("FightFail")
                        command.mState = Command.EState.Finish
                        self:start()
                    end
                end
            }
        )
    )
end

function Host_Game:_nextMatch()
    self.mProperty:safeWrite("mState", "SafeHouse")
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Host_Game:_nextMatch/Prepare",
                mExecutingCallback = function(command)
                    command.mTimer = command.mTimer or new(Timer)
                    if command.mTimer:total() >= GameConfig.mPrepareTime then
                        self.mProperty:safeWrite("mSafeHouseLeftTime")
                        command.mState = Command.EState.Finish
                    else
                        local left_time = math.floor(GameConfig.mPrepareTime - command.mTimer:total())
                        if left_time ~= self.mProperty:cache().mSafeHouseLeftTime then
                            self.mProperty:safeWrite("mSafeHouseLeftTime", left_time)
                        end
                    end
                end
            }
        )
    )
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Host_Game:_nextMatch/Start",
                mExecuteCallback = function(command)
                    command.mState = Command.EState.Finish
                    self:_startMatch(
                        function()
                            self:_startWave(1)
                        end
                    )
                end
            }
        )
    )
end

function Host_Game:_startMatch(callback)
    local scene = {mLevel = self.mProperty:cache().mLevel}
    local terrains = {}
    for _, terrain in pairs(GameConfig.mTerrainLibrary) do
        if not terrain.mLevel or terrain.mLevel == self.mProperty:cache().mLevel then
            terrains[#terrains + 1] = terrain
        end
    end
    if #terrains > 0 then
        local terrain_config = terrains[math.random(1, #terrains)]
        scene.mTerrain = new(Host_GameTerrain, {mTemplateResource = terrain_config.mTemplateResource})
        self:setScene(scene, callback)
    else
        self:setScene(nil, callback)
    end
end
-----------------------------------------------------------------------------------------Host_GamePlayerManager-----------------------------------------------------------------------------------
function Host_GamePlayerManager:construction()
    self.mPlayers = {}

    for id, player in pairs(PlayerManager.mPlayers) do
        self:_createPlayer(EntityWatcher.get(id))
    end
    PlayerManager.addEventListener(
        "PlayerEntityCreate",
        "Host_GamePlayerManager",
        function(inst, parameter)
            echo("devilwalk","Host_GamePlayerManager:construction:PlayerEntityCreate:"..tostring(parameter.mPlayerID))
            self:_createPlayer(EntityWatcher.get(parameter.mPlayerID))
        end,
        self
    )
    PlayerManager.addEventListener(
        "PlayerRemoved",
        "Host_GamePlayerManager",
        function(inst, parameter)
            echo("devilwalk","Host_GamePlayerManager:construction:PlayerRemoved:"..tostring(parameter.mPlayerID))
            self:_destroyPlayer(parameter.mPlayerID)
        end,
        self
    )
    Host.addListener("GamePlayerManager", self)
end

function Host_GamePlayerManager:destruction()
    self:reset()
    PlayerManager.removeEventListener("PlayerEntityCreate", "Host_GamePlayerManager")
    PlayerManager.removeEventListener("PlayerRemoved", "Host_GamePlayerManager")
    Host.removeListener("GamePlayerManager", self)
end

function Host_GamePlayerManager:update()
end

function Host_GamePlayerManager:broadcast(message, parameter)
    Host.broadcast({mKey = "GamePlayerManager", mMessage = message, mParameter = parameter})
end

function Host_GamePlayerManager:receive(parameter)
end

function Host_GamePlayerManager:reset()
    self:broadcast("Reset")
    for _, player in pairs(self.mPlayers) do
        delete(player)
    end
    self.mPlayers = {}
end

function Host_GamePlayerManager:getPlayerByID(playerID)
    playerID = playerID or GetPlayerId()
    for _, player in pairs(self.mPlayers) do
        if player:getID() == playerID then
            return player
        end
    end
end

function Host_GamePlayerManager:initializePlayerProperties(propertyName)
    self:eachPlayer("initializeProperty", propertyName)
end

function Host_GamePlayerManager:setScene(scene)
    self.mScene = scene
    if self.mScene then
        self:eachPlayer("setPosition", self.mScene.mTerrain:getProtectPoint())
    end
end

function Host_GamePlayerManager:_createPlayer(entityWatcher)
    local ret = new(Host_GamePlayer, {mEntityWatcher = entityWatcher, mConfigIndex = 1})
    self.mPlayers[#self.mPlayers + 1] = ret
    if Host_Game.singleton().mScene then
        local pos = Host_Game.singleton().mScene.mTerrain:getProtectPoint()
        SetEntityBlockPos(ret:getID(), pos[1], pos[2], pos[3])
    elseif Host_Game.singleton().mSafeHouse then
        local pos = Host_Game.singleton().mSafeHouse.mTerrain:getProtectPoint()
        SetEntityBlockPos(ret:getID(), pos[1], pos[2], pos[3])
    end
    return ret
end

function Host_GamePlayerManager:_destroyPlayer(id)
    for i, player in pairs(self.mPlayers) do
        if player:getID() == id then
            delete(player)
            table.remove(self.mPlayers, i)
            break
        end
    end
end

function Host_GamePlayerManager:eachPlayer(functionName, ...)
    for _, player in pairs(self.mPlayers) do
        player[functionName](player, ...)
    end
end

function Host_GamePlayerManager:isAllDead()
    for _, player in pairs(self.mPlayers) do
        if not player:getProperty():cache().mHP or player:getProperty():cache().mHP > 0 then
            return false
        end
    end
    return true
end
-----------------------------------------------------------------------------------------Host_GameMonsterManager-----------------------------------------------------------------------------------
function Host_GameMonsterManager:construction()
    self.mMonsters = {}
    self.mProperty = new(GameMonsterManagerProperty)

    PlayerManager.addEventListener(
        "PlayerEntityCreate",
        "Host_GameMonsterManager",
        function(inst, parameter)
            for _, monster in pairs(self.mMonsters) do
                if monster:getProperty():cache().mHP > 0 then
                    self:sendToClient(parameter.mPlayerID, "CreateMonster", {mID = monster:getID()})
                end
            end
        end,
        self
    )
    Host.addListener("GameMonsterManager", self)
end

function Host_GameMonsterManager:destruction()
    self:reset()
    self.mProperty:safeWrite("mMonsterCount")
    delete(self.mProperty)
    Host.removeListener("GameMonsterManager", self)
end

function Host_GameMonsterManager:reset()
    self:broadcast("Reset")
    for _, monster in pairs(self.mMonsters) do
        delete(monster)
    end
    self.mMonsters = {}
    delete(self.mMonsterGenerator)
end

function Host_GameMonsterManager:setScene(scene)
    self:reset()

    if scene and scene.mTerrain and #scene.mTerrain:getMonsterRoads() > 0 then
        self.mMonsterGenerator =
            new(
            Host_GameMonsterGenerator,
            {
                mRoads = scene.mTerrain:getMonsterRoads(),
                mGenerateSpeed = GameConfig.mMatch.mMonsterGenerateSpeed *
                    #Host_Game.singleton():getPlayerManager().mPlayers,
                mGenerateCount = GameCompute.computeMonsterGenerateCount(
                    Host_Game.singleton():getProperty():cache().mLevel
                ) * GameCompute.computeMonsterGenerateCountScale(Host_Game.singleton():getPlayerManager().mPlayers)
            }
        )
    else
        delete(self.mMonsterGenerator)
        self.mMonsterGenerator = nil
    end
end

function Host_GameMonsterManager:update(deltaTime)
    --更新现有怪物逻辑
    self:_updateMonsters(deltaTime)
    --产生新怪物
    self:_generateMonsters(deltaTime)
    self:_updateMonsterCount()
end

function Host_GameMonsterManager:broadcast(message, parameter)
    Host.broadcast({mKey = "GameMonsterManager", mMessage = message, mParameter = parameter})
end

function Host_GameMonsterManager:sendToClient(playerID, message, parameter)
    Host.sendTo(playerID, {mKey = "GameMonsterManager", mMessage = message, mParameter = parameter})
end

function Host_GameMonsterManager:receive(parameter)
end

function Host_GameMonsterManager:isAllDead()
    if self.mMonsterGenerator and self.mMonsterGenerator.mGenerateCount > 0 then
        return false
    end
    for _, monster in pairs(self.mMonsters) do
        if monster:getProperty():cache().mHP > 0 then
            return false
        end
    end
    return true
end

function Host_GameMonsterManager:_updateMonsterCount()
    if self.mMonsterGenerator then
        local count = self.mMonsterGenerator.mGenerateCount or 0
        for _, monster in pairs(self.mMonsters) do
            if monster:getProperty():cache().mHP > 0 then
                count = count + 1
            end
        end

        self.mProperty:safeWrite("mMonsterCount", count)
    end
end

function Host_GameMonsterManager:getProperty()
    return self.mProperty
end

function Host_GameMonsterManager:_createMonster(parameter)
    local ret =
        new(
        Host_GameMonster,
        {
            mConfigIndex = parameter.mConfigIndex,
            mRoad = parameter.mRoad,
            mLevel = GameCompute.computeMonsterLevel(Host_Game.singleton():getProperty():cache().mLevel)
        }
    )
    self.mMonsters[#self.mMonsters + 1] = ret
    self:broadcast("CreateMonster", {mID = ret:getID()})
    return ret
end

function Host_GameMonsterManager:_updateMonsters(deltaTime)
    for _, monster in pairs(self.mMonsters) do
        monster:update(deltaTime)
    end
end

function Host_GameMonsterManager:_generateMonsters(deltaTime)
    if self.mMonsterGenerator then
        local monsters = self.mMonsterGenerator:generate(deltaTime)
        for _, monster in pairs(monsters) do
            self:_createMonster(monster)
        end
    end
end
-----------------------------------------------------------------------------------------Host_GameEffectManager-----------------------------------------------------------------------------------
function Host_GameEffectManager:construction(parameter)
end

function Host_GameEffectManager:destruction()
end

function Host_GameEffectManager:update()
end

function Host_GameEffectManager:broadcast(message, parameter)
    Host.broadcast({mKey = "GameEffectManager", mMessage = message, mParameter = parameter})
end

function Host_GameEffectManager:monsterDead(monster)
    local monster_info = {}
    monster_info.mPosition = monster.mEntity:getPosition() + vector3d:new(0, 0.5, 0)
    local player_infos = {}
    local total_money = monLootGold(monster.mProperty:cache().mLevel)
    for player_id, damage in pairs(monster.mDamaged) do
        local player = Host_Game.singleton():getPlayerManager():getPlayerByID(player_id)
        if player then
            local player_info = {}
            player_info.mPosition = GetEntityById(player_id):getPosition() + vector3d:new(0, 0.5, 0)
            player_info.mMoney = total_money * damage / monster:getProperty():cache().mInitHP
            player_infos[#player_infos + 1] = player_info
        end
    end
    self:broadcast("MonsterDead", {mMonsterInfo = monster_info, mPlayerInfos = player_infos})
end
-----------------------------------------------------------------------------------------Host_GameTerrain-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------Host_GameTerrain-----------------------------------------------------------------------------------
function Host_GameTerrain:construction(parameter)
    local x, y, z = GetHomePosition()
    x, y, z = ConvertToBlockIndex(x, y + 0.5, z)
    y = y - 1
    self.mHomePosition = parameter.mHomePosition or {x, y, z}
    self.mTemplate = parameter.mTemplate
    self.mTemplateResource = parameter.mTemplateResource
    self.mRoads = {}
    self.mTowerPoints = {}
    self.mCommandQueue = CommandQueueManager.singleton():createQueue()
end

function Host_GameTerrain:destruction()
    CommandQueueManager.singleton():destroyQueue(self.mCommandQueue)
    self:restoreTemplate()
end

function Host_GameTerrain:update()
end

function Host_GameTerrain:applyTemplate(callback)
    if self.mTemplate then
        if self.mTemplate.mBlocks then
            local monster_points = {}
            local offset = {self.mHomePosition[1] + 1, self.mHomePosition[2] + 1, self.mHomePosition[3] + 1}
            for _, block in pairs(self.mTemplate.mBlocks) do
                if block[4] == GameConfig.mMonsterPointBlockID then
                    monster_points[#monster_points + 1] = {
                        block[1] + offset[1],
                        block[2] + offset[2],
                        block[3] + offset[3]
                    }
                elseif block[4] == GameConfig.mProtectedPointBlockID then
                    self.mProtectPoint = {block[1] + offset[1], block[2] + offset[2], block[3] + offset[3]}
                elseif block[4] == GameConfig.mTowerPointBlockID then
                    self.mTowerPoints[#self.mTowerPoints+1] = {block[1] + offset[1], block[2] + offset[2], block[3] + offset[3]}
                end
                setBlock(block[1] + offset[1], block[2] + offset[2], block[3] + offset[3], block[4], block[5])
            end
            for _, point in pairs(monster_points) do
                self:_calculateRoad(point)
                restoreBlock(point[1],point[2] + 1,point[3])
                setBlock(point[1],point[2] + 1,point[3],0)
            end
        end
        if callback then
            self.mCommandQueue:post(
                new(
                    Command_Callback,
                    {
                        mDebug = "Host_GameTerrain:applyTemplate",
                        mExecutingCallback = function(command)
                            command.mTimer = command.mTimer or new(Timer)
                            if command.mTimer:total() > 1 then
                                delete(command.mTimer)
                                command.mState = Command.EState.Finish
                                callback()
                            end
                        end
                    }
                )
            )
        end
    elseif self.mTemplateResource then
        GetResourceModel(
            self.mTemplateResource,
            function(path)
                self.mTemplate = LoadTemplate(path)
                self:applyTemplate(callback)
            end
        )
    end
end

function Host_GameTerrain:restoreTemplate()
    if self.mTemplate then
        if self.mTemplate.mBlocks then
            local offset = {self.mHomePosition[1] + 1, self.mHomePosition[2] + 1, self.mHomePosition[3] + 1}
            for _, block in pairs(self.mTemplate.mBlocks) do
                restoreBlock(block[1] + offset[1], block[2] + offset[2], block[3] + offset[3])
            end
        end
    end
end

function Host_GameTerrain:getMonsterRoads()
    return self.mRoads
end

function Host_GameTerrain:getProtectPoint()
    return self.mProtectPoint
end

function Host_GameTerrain:_calculateRoad(monsterPoint)
    local road = {}
    local road_block_id = GetBlockId(monsterPoint[1], monsterPoint[2] + 1, monsterPoint[3])
    setBlock(monsterPoint[1], monsterPoint[2] + 1, monsterPoint[3],0)
    local function _checkRoad(point,fromDir)
        if monsterPoint == point  or GetBlockId(point[1],point[2],point[3]) == road_block_id then
            road[#road + 1] = {point[1],point[2]+1,point[3]}
        else
            return
        end
        if fromDir ~= "x" then
            _checkRoad({point[1] + 1,point[2],point[3]},"-x")
        end
        if fromDir ~= "-x" then
            _checkRoad({point[1] - 1,point[2],point[3]},"x")
        end
        if fromDir ~= "z" then
            _checkRoad({point[1],point[2],point[3] + 1},"-z")
        end
        if fromDir ~= "-z" then
            _checkRoad({point[1],point[2],point[3] - 1},"z")
        end
    end
    _checkRoad(monsterPoint)
    road[#road+1] = {self.mProtectPoint[1],self.mProtectPoint[2]+1,self.mProtectPoint[3]}
    self.mRoads[#self.mRoads + 1] = road
end
-----------------------------------------------------------------------------------------Host_GameMonsterGenerator-----------------------------------------------------------------------------------
function Host_GameMonsterGenerator:construction(parameter)
    self.mRoads = parameter.mRoads
    self.mGenerateSpeed = parameter.mGenerateSpeed
    self.mGenerateCount = parameter.mGenerateCount
    self.mGenerateTime = 0
end

function Host_GameMonsterGenerator:destruction()
end

function Host_GameMonsterGenerator:generate(deltaTime)
    self.mGenerateTime = self.mGenerateTime + deltaTime
    local generate_time = math.floor(self.mGenerateTime)
    local need_generate_count = math.min(self.mGenerateCount, math.floor(generate_time * self.mGenerateSpeed))
    if need_generate_count > 0 then
        self.mGenerateTime = self.mGenerateTime - generate_time
    end
    self.mGenerateCount = self.mGenerateCount - need_generate_count

    local monster_library = {}
    for i, config in pairs(GameConfig.mMonsterLibrary) do
        if config.mLevelEnable and config.mLevelEnable(Host_Game.singleton():getProperty():cache().mLevel) then
            monster_library[#monster_library + 1] = i
        elseif config.mLevelDisable and not config.mLevelDisable(Host_Game.singleton():getProperty():cache().mLevel) then
            monster_library[#monster_library + 1] = i
        elseif not config.mLevelEnable and not config.mLevelDisable then
            monster_library[#monster_library + 1] = i
        end
    end

    local ret = {}
    for i = 1, need_generate_count do
        local config_index = monster_library[math.random(1, #monster_library)]
        ret[#ret + 1] = {mConfigIndex = config_index, mRoad = self.mRoads[math.random(1, #self.mRoads)]}
    end
    return ret
end
-----------------------------------------------------------------------------------------Host_GamePlayer-----------------------------------------------------------------------------------
function Host_GamePlayer:construction(parameter)
    echo("devilwalk", "Host_GamePlayer:construction")
    self.mPlayerID = parameter.mEntityWatcher.id
    self.mProperty = new(GamePlayerProperty, {mPlayerID = self.mPlayerID})
    self.mConfigIndex = parameter.mConfigIndex

    self.mProperty:safeWrite("mConfigIndex", self.mConfigIndex)
    self.mProperty:safeWrite("mMoney", 100)
    self.mProperty:safeWrite("mKill", 0)
    Host.addListener(self:_getSendKey(), self)
end

function Host_GamePlayer:destruction()
    self.mProperty:safeWrite("mConfigIndex")
    self.mProperty:safeWrite("mMoney")
    self.mProperty:safeWrite("mKill")
    delete(self.mProperty)
    Host.removeListener(self:_getSendKey(), self)
end

function Host_GamePlayer:sendToClient(message, parameter)
    Host.sendTo(self.mPlayerID, {mKey = self:_getSendKey(), mMessage = message, mParameter = parameter})
end

function Host_GamePlayer:receive(parameter)
end

function Host_GamePlayer:getID()
    return self.mPlayerID
end

function Host_GamePlayer:getProperty()
    return self.mProperty
end

function Host_GamePlayer:initializeProperty(propertyName)
    if propertyName then
        if propertyName == "mGameMoney" then
            self.mProperty:safeWrite("mGameMoney", 100)
        end
    else
        self.mProperty:safeWrite("mGameMoney", 100)
    end
end

function Host_GamePlayer:setPosition(position)
    SetEntityBlockPos(self.mPlayerID, position[1], position[2], position[3])
end

function Host_GamePlayer:addMoney(money)
    self:sendToClient("AddMoney", {mMoney = money})
end

function Host_GamePlayer:_getSendKey()
    return "GamePlayer/" .. tostring(self.mPlayerID)
end
-----------------------------------------------------------------------------------------Host_GameMonster-----------------------------------------------------------------------------------
Host_GameMonster.mNameIndex = 1
function Host_GameMonster:construction(parameter)
    self.mConfigIndex = parameter.mConfigIndex
    self.mID = Host_GameMonster.mNameIndex
    Host_GameMonster.mNameIndex = Host_GameMonster.mNameIndex + 1
    local client_key = EntityCustomManager.singleton():createEntity(
        {mX = parameter.mRoad[1][1]
        ,mY = parameter.mRoad[1][2]
        ,mZ = parameter.mRoad[1][3]
        ,mModel = {mFile = self:getConfig().mModel.mFile,mResource = self:getConfig().mModel.mResource,mScaling = self:getConfig().mModel.mScaling,mFacing = self:getConfig().mModel.mFacing}
        },function(hostKey)
            self.mProperty:safeWrite("mEntityHostKey", hostKey)
            self.mEntity:setAnimationID(1)
            for _,point in pairs(parameter.mRoad) do
                self.mEntity:moveToBlock(point[1],point[2],point[3],"addition")
            end
        end)
    self.mEntity = EntityCustomManager.singleton():getEntityByClientKey(client_key)
    self.mProperty = new(GameMonsterProperty, {mID = self.mID})
    self.mProperty:safeWrite("mConfigIndex", parameter.mConfigIndex)
    self.mProperty:safeWrite("mLevel", parameter.mLevel)
    self.mProperty:safeWrite("mInitHP", GameCompute.computeMonsterHP(self.mProperty:cache().mLevel))
    self.mProperty:safeWrite("mHP", GameCompute.computeMonsterHP(self.mProperty:cache().mLevel))

    Host.addListener(self:_getSendKey(), self)
end

function Host_GameMonster:destruction()
    self.mProperty:safeWrite("mEntityHostKey")
    self.mProperty:safeWrite("mConfigIndex")
    self.mProperty:safeWrite("mLevel")
    self.mProperty:safeWrite("mInitHP")
    self.mProperty:safeWrite("mHP")
    delete(self.mProperty)
    if self.mEntity then
        EntityCustomManager.singleton():destroyEntity(self.mEntity.mClientKey)
    end
    Host.removeListener(self:_getSendKey(), self)
end

function Host_GameMonster:update()
    if self.mEntity then
        if not next(self.mEntity.mTargets) then
            Host_Game.singleton():getProtecter():onHit()
            self.mProperty:safeWrite("mHP",0)
            EntityCustomManager.singleton():destroyEntity(self.mEntity.mClientKey)
            self.mEntity = nil
        end
    end
end

function Host_GameMonster:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
    else
        if parameter.mMessage == "PropertyChange" then
            self:_propertyChange(parameter._from, parameter.mParameter)
        end
    end
end

function Host_GameMonster:getID()
    return self.mID
end

function Host_GameMonster:getEntity()
    return self.mEntity
end

function Host_GameMonster:getProperty()
    return self.mProperty
end

function Host_GameMonster:getConfig()
    return GameConfig.mMonsterLibrary[self.mConfigIndex]
end

function Host_GameMonster:_getSendKey()
    return "GameMonster/" .. tostring(self.mID)
end

function Host_GameMonster:_propertyChange(playerID, change)
    if change.mHPSubtract then
        sub_stract = math.min(change.mHPSubtract, self.mProperty:cache().mHP)
        self.mDamaged = self.mDamaged or {}
        self.mDamaged[playerID] = self.mDamaged[playerID] or 0
        self.mDamaged[playerID] = self.mDamaged[playerID] + sub_stract
        self.mProperty:safeWrite("mHP", self.mProperty:cache().mHP - sub_stract)
    end

    self:_checkDead(playerID)
end

function Host_GameMonster:_checkDead(lastHitPlayerID)
    if self.mProperty:cache().mHP <= 0 and self.mEntity then
        Host_Game.singleton():getEffectManager():monsterDead(self)
        EntityCustomManager.singleton():destroyEntity(self.mEntity.mClientKey)
        self.mEntity = nil
        if self.mDamaged then
            local total_money = monLootGold(self.mProperty:cache().mLevel)
            for player_id, damage in pairs(self.mDamaged) do
                local player = Host_Game.singleton():getPlayerManager():getPlayerByID(player_id)
                if player then
                    local money = total_money * damage / self.mProperty:cache().mInitHP
                    player:addMoney(money)
                end
            end
            self.mDamaged = nil
        end
        local player = Host_Game.singleton():getPlayerManager():getPlayerByID(lastHitPlayerID)
        player:getProperty():safeWrite("mKill", player:getProperty():cache().mKill or 0 + 1)
    end
end
-----------------------------------------------------------------------------------------Host_GameProtecter-----------------------------------------------------------------------------------
function Host_GameProtecter:construction(parameter)
    self.mProperty = new(GameProtecterProperty)
    local client_key = EntityCustomManager.singleton():createEntity(
        {mX = 19200
        ,mY = 10
        ,mZ = 19200
        ,mModel = {mFile = GameConfig.mProtecter.mModel.mFile,mResource = GameConfig.mProtecter.mModel.mResource}
        },function(hostKey)
            self.mProperty:safeWrite("mEntityHostKey", hostKey)
            self.mEntity:setAnimationID(1)
        end)
    self.mEntity = EntityCustomManager.singleton():getEntityByClientKey(client_key)
end

function Host_GameProtecter:destruction()
    EntityCustomManager.singleton():destroyEntity(self.mEntity.mClientKey)
    self.mEntity = nil
    self.mProperty:safeWrite("mHP")
end

function Host_GameProtecter:getProperty()
    return self.mProperty
end

function Host_GameProtecter:_getSendKey()
    return "GameProtecter"
end

function Host_GameProtecter:setScene(scene)
    if scene and scene.mTerrain then
        local x,y,z = ConvertToRealPosition(scene.mTerrain:getProtectPoint()[1],scene.mTerrain:getProtectPoint()[2] + 1,scene.mTerrain:getProtectPoint()[3])
        self:_setPosition({x,y,z})
    else
        self:_setPosition()
    end
    self.mProperty:safeWrite("mHP",GameConfig.mProtecter.mHP)
end

function Host_GameProtecter:onHit()
    self.mProperty:safeWrite("mHP",math.max(self.mProperty:cache().mHP - 1,0))
end

function Host_GameProtecter:_setPosition(pos)
    if self.mProperty:cache().mEntityHostKey then
        if pos then
            self.mEntity:setPosition(pos[1],pos[2],pos[3])
        else
            self.mEntity:setPosition(0,0,0)
        end
    else
        CommandQueueManager.singleton():post(new(Command_Callback,{mDebug = "Host_GameProtecter:setScene",mExecuteCallback = function(command)
            self:_setPosition(scene)
            command.mState = Command.EState.Finish
        end}))
    end
end
-----------------------------------------------------------------------------------------Client_Game-----------------------------------------------------------------------------------
function Client_Game.singleton(construct)
    if construct and not Client_Game.msInstance then
        Client_Game.msInstance = new(Client_Game)
        Client_Game.msInstance:initialize()
    end
    return Client_Game.msInstance
end

function Client_Game:construction()
    self.mProperty = new(GameProperty)
    self.mPlayerManager = new(Client_GamePlayerManager)
    self.mMonsterManager = new(Client_GameMonsterManager)
    self.mEffectManager = new(Client_GameEffectManager)
    self.mProtecter = new(Client_GameProtecter)

    self.mProperty:addPropertyListener(
        "mLevel",
        self,
        function(_, value)
        end
    )
    self.mProperty:addPropertyListener(
        "mState",
        self,
        function(_, value)
        end
    )
    self.mProperty:addPropertyListener(
        "mSafeHouseLeftTime",
        self,
        function(_, value)
        end
    )
    self.mProperty:addPropertyListener(
        "mWavePrepareLeftTime",
        self,
        function(_, value)
        end
    )
    self.mProperty:addPropertyListener(
        "mFightLeftTime",
        self,
        function(_, value)
        end
    )
    self.mProperty:addPropertyListener(
        "mSwitchLevel",
        self,
        function(_, value)
            if value then
                Tip("下一关将切换为关卡" .. tostring(value), 5000, "255 255 0", "SwitchLevel")
            end
        end
    )
    self.mProperty:addPropertyListener(
        "mSwitchLevelAgree",
        self,
        function(_, value)
        end
    )
    self.mProperty:addPropertyListener(
        "mSwitchLevelDisagree",
        self,
        function(_, value)
        end
    )
    Client.addListener("Game", self)
end

function Client_Game:destruction()
    delete(self.mProtecter)
    self.mProtecter = nil
    delete(self.mMonsterManager)
    self.mMonsterManager = nil
    delete(self.mPlayerManager)
    self.mPlayerManager = nil
    delete(self.mEffectManager)
    self.mEffectManager = nil
    self.mProperty:removePropertyListener("mLevel")
    self.mProperty:removePropertyListener("mState")
    self.mProperty:removePropertyListener("mSafeHouseLeftTime")
    self.mProperty:removePropertyListener("mWavePrepareLeftTime")
    self.mProperty:removePropertyListener("mFightLeftTime")
    self.mProperty:removePropertyListener("mSwitchLevel")
    self.mProperty:removePropertyListener("mSwitchLevelAgree")
    self.mProperty:removePropertyListener("mSwitchLevelDisagree")
    delete(self.mProperty)
    self.mProperty = nil
    Client.removeListener("Game", self)
    Client_Game.msInstance = nil
end

function Client_Game:initialize()
    self.mPlayerManager:initialize()
    self.mMonsterManager:initialize()
    self.mEffectManager:initialize()
end

function Client_Game:update(deltaTime)
    self.mPlayerManager:update(deltaTime)
    self.mMonsterManager:update(deltaTime)
    self.mEffectManager:update(deltaTime)
end

function Client_Game:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if self.mResponseCallback[message] then
            self.mResponseCallback[message](parameter.mParameter)
            self.mResponseCallback[message] = nil
        end
    else
        if parameter.mMessage == "FightSuccess" then
            CommandQueueManager.singleton():post(
                new(
                    Command_Callback,
                    {
                        mDebug = "Client_Game:receive/FightSuccess",
                        mTimeOutProcess = function()
                        end,
                        mExecutingCallback = function(command)
                            command.mTimer = command.mTimer or new(Timer)
                            Tip(
                                "战斗胜利，通关奖励：￥" ..
                                    tostring(math.floor(parameter.mParameter.mAddMoney)) .."(人数加成+"..GameCompute.computeMatchSuccessPlayerPlusMoney(self.mProperty:cache().mLevel,#self.mPlayerManager.mPlayers)..
                                        ")，" .. tostring(math.floor(5 - command.mTimer:total())) .. "秒后返回安全屋",
                                1400,
                                "255 255 0",
                                "notice"
                            )
                            if command.mTimer:total() >= 5 then
                                command.mState = Command.EState.Finish
                            end
                        end
                    }
                )
            )
        elseif parameter.mMessage == "FightFail" then
            CommandQueueManager.singleton():post(
                new(
                    Command_Callback,
                    {
                        mDebug = "Client_Game:receive/FightFail",
                        mTimeOutProcess = function()
                        end,
                        mExecutingCallback = function(command)
                            command.mTimer = command.mTimer or new(Timer)
                            Tip(
                                "全体阵亡，" .. tostring(math.floor(5 - command.mTimer:total())) .. "秒后返回安全屋重新开始",
                                1400,
                                "255 255 0",
                                "notice"
                            )
                            if command.mTimer:total() >= 5 then
                                command.mState = Command.EState.Finish
                            end
                        end
                    }
                )
            )
        elseif parameter.mMessage == "SwitchLevel" then
            local nickname = tostring(parameter.mParameter.mRequester)
            if GetEntityById(parameter.mParameter.mRequester) then
                nickname = GetEntityById(parameter.mParameter.mRequester).nickname
            end
            setUiValue("voteLevel_background", "visible", true)
            CommandQueueManager.singleton():post(
                new(
                    Command_Callback,
                    {
                        mDebug = "SwitchLevelTimer",
                        mExecutingCallback = function(command)
                            command.mTimer = command.mTimer or new(Timer)
                            setUiValue(
                                "voteTimeLeft",
                                "text",
                                "剩余时间：" .. tostring(math.floor(GameConfig.mSwitchLevelTime - command.mTimer:total())) .. "秒"
                            )
                            setUiValue(
                                "agree_text",
                                "text",
                                "(" .. tostring(self.mProperty:cache().mSwitchLevelAgree or 0) .. "票)"
                            )
                            setUiValue(
                                "disagree_text",
                                "text",
                                "(" .. tostring(self.mProperty:cache().mSwitchLevelDisagree or 0) .. "票)"
                            )
                            if command.mTimer:total() > GameConfig.mSwitchLevelTime then
                                setUiValue("voteLevel_background", "visible", false)
                                command.mState = Command.EState.Finish
                            end
                        end
                    }
                )
            )
            setUiValue(
                "voteLevel_text",
                "text",
                nickname .. " 想切换到关卡等级" .. tostring(parameter.mParameter.mLevel) .. "，是否同意？"
            )
            if parameter.mParameter.mRequester ~= GetPlayerId() then
                setUiValue(
                    "agree_button",
                    "enabled",
                    true
                )
                setUiValue(
                    "disagree_button",
                    "enabled",
                    true
                )
                setUiValue(
                    "agree_button",
                    "onclickCallback",
                    function()
                        self:sendToHost(
                            "SwitchLevelAnswer",
                            {mResult = true, mRequester = parameter.mParameter.mRequester}
                        )
                        setUiValue(
                            "agree_button",
                            "enabled",
                            false
                        )
                        setUiValue(
                            "disagree_button",
                            "enabled",
                            false
                        )
                    end
                )
                setUiValue(
                    "disagree_button",
                    "onclickCallback",
                    function()
                        self:sendToHost(
                            "SwitchLevelAnswer",
                            {mResult = false, mRequester = parameter.mParameter.mRequester}
                        )
                        setUiValue(
                            "agree_button",
                            "enabled",
                            false
                        )
                        setUiValue(
                            "disagree_button",
                            "enabled",
                            false
                        )
                    end
                )
            else
                self:sendToHost("SwitchLevelAnswer", {mResult = true, mRequester = parameter.mParameter.mRequester})
                setUiValue("agree_text","font_color","255 255 0")
                setUiValue(
                    "agree_button",
                    "enabled",
                    false
                )
                setUiValue(
                    "disagree_button",
                    "enabled",
                    false
                )
            end
        end
    end
end

function Client_Game:broadcast(message, parameter)
    Client.broadcast("Game", {mMessage = message, mParameter = parameter})
end

function Client_Game:sendToHost(message, parameter)
    Client.sendToHost("Game", {mMessage = message, mParameter = parameter})
end

function Client_Game:requestToHost(message, parameter, callback)
    self.mResponseCallback = self.mResponseCallback or {}
    self.mResponseCallback[message] = callback
    self:sendToHost(message, parameter)
end

function Client_Game:onHit(weapon, result)
    self.mPlayerManager:onHit(weapon, result)
    self.mMonsterManager:onHit(weapon, result)
end

function Client_Game:switchLevel(level)
    if self.mSwitchLeveling then
        UI.messageBox("请等待上次请求结束...")
        return
    end
    self.mSwitchLeveling = true
    self:requestToHost(
        "SwitchLevelRequest",
        {mLevel = level},
        function(parameter)
            self.mSwitchLeveling = nil
            if not parameter.mResult then
                UI.messageBox("请求被拒绝")
            end
        end
    )
end

function Client_Game:getPlayerManager()
    return self.mPlayerManager
end

function Client_Game:getMonsterManager()
    return self.mMonsterManager
end

function Client_Game:getEffectManager()
    return self.mEffectManager
end

function Client_Game:getProperty()
    return self.mProperty
end
-----------------------------------------------------------------------------------------Client_GamePlayerManager-----------------------------------------------------------------------------------
function Client_GamePlayerManager:construction()
    self.mPlayers = {}

    PlayerManager.addEventListener(
        "PlayerEntityCreate",
        "Client_GamePlayerManager",
        function(inst, parameter)
            echo("devilwalk","Client_GamePlayerManager:construction:PlayerEntityCreate:"..tostring(parameter.mPlayerID))
            self:_createPlayer(parameter.mPlayerID)
        end,
        self
    )
    PlayerManager.addEventListener(
        "PlayerRemoved",
        "Client_GamePlayerManager",
        function(inst, parameter)
            echo("devilwalk","Client_GamePlayerManager:construction:PlayerRemoved:"..tostring(parameter.mPlayerID))
            self:_destroyPlayer(parameter.mPlayerID)
        end,
        self
    )
    Client.addListener("GamePlayerManager", self)
end

function Client_GamePlayerManager:destruction()
    self:reset()
    PlayerManager.removeEventListener("PlayerEntityCreate","Client_GamePlayerManager")
    PlayerManager.removeEventListener("PlayerRemoved","Client_GamePlayerManager")
    Client.removeListener("GamePlayerManager", self)
end

function Client_GamePlayerManager:initialize()
    for id, player in pairs(PlayerManager.mPlayers) do
        self:_createPlayer(id)
    end
end

function Client_GamePlayerManager:reset()
    for _, player in pairs(self.mPlayers) do
        delete(player)
    end
    self.mPlayers = {}
end

function Client_GamePlayerManager:update()
    for _, player in pairs(self.mPlayers) do
        player:update()
    end
end

function Client_GamePlayerManager:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
    else
        if parameter.mMessage == "Reset" then
            self:reset()
        end
    end
end

function Client_GamePlayerManager:sendToHost(message, parameter)
    Client.sendToHost("GamePlayerManager", {mMessage = message, mParameter = parameter})
end

function Client_GamePlayerManager:getPlayerByID(playerID)
    playerID = playerID or GetPlayerId()
    for _, player in pairs(self.mPlayers) do
        if player:getID() == playerID then
            return player
        end
    end
end

function Client_GamePlayerManager:onHit(weapon, result)
    for _, player in pairs(self.mPlayers) do
        player:onHit(weapon, result)
    end
end

function Client_GamePlayerManager:getPlayersSortByFightLevel()
    local players = clone(self.mPlayers)
    table.sort(
        players,
        function(a, b)
            if
                a:getProperty():cache().mHPLevel and a:getProperty():cache().mAttackValueLevel and
                    a:getProperty():cache().mAttackTimeLevel and
                    b:getProperty():cache().mHPLevel and
                    b:getProperty():cache().mAttackValueLevel and
                    b:getProperty():cache().mAttackTimeLevel
             then
                return GameCompute.computePlayerFightLevel(
                    a:getProperty():cache().mHPLevel,
                    a:getProperty():cache().mAttackValueLevel,
                    a:getProperty():cache().mAttackTimeLevel
                ) >
                    GameCompute.computePlayerFightLevel(
                        b:getProperty():cache().mHPLevel,
                        b:getProperty():cache().mAttackValueLevel,
                        b:getProperty():cache().mAttackTimeLevel
                    )
            else
                return false
            end
        end
    )
    return players
end

function Client_GamePlayerManager:_createPlayer(playerID)
    local ret = new(Client_GamePlayer, {mPlayerID = playerID})
    self.mPlayers[#self.mPlayers + 1] = ret
    return ret
end

function Client_GamePlayerManager:_destroyPlayer(playerID)
    for i, player in pairs(self.mPlayers) do
        if player:getID() == playerID then
            delete(player)
            table.remove(self.mPlayers, i)
            return
        end
    end
end
-----------------------------------------------------------------------------------------Client_GameMonsterManager-----------------------------------------------------------------------------------
function Client_GameMonsterManager:construction()
    self.mMonsters = {}
    self.mProperty = new(GameMonsterManagerProperty)

    self.mProperty:addPropertyListener(
        "mMonsterCount",
        self,
        function(_, value)
        end
    )
    Client.addListener("GameMonsterManager", self)
end

function Client_GameMonsterManager:destruction()
    self:reset()
    self.mProperty:removePropertyListener("mMonsterCount")
    delete(self.mProperty)
    Client.removeListener("GameMonsterManager", self)
end

function Client_GameMonsterManager:initialize()
end

function Client_GameMonsterManager:update(deltaTime)
    for _, monster in pairs(self.mMonsters) do
        monster:update()
    end
end

function Client_GameMonsterManager:reset()
    for _, monster in pairs(self.mMonsters) do
        delete(monster)
    end
    self.mMonsters = {}
end

function Client_GameMonsterManager:sendToHost(message, parameter)
    Client.sendToHost("GameMonsterManager", {mMessage = message, mParameter = parameter})
end

function Client_GameMonsterManager:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
    else
        if parameter.mMessage == "CreateMonster" then
            self:_createMonster(parameter.mParameter.mID)
        elseif parameter.mMessage == "Reset" then
            self:reset()
        end
    end
end

function Client_GameMonsterManager:onHit(weapon, result)
    if result.entity then
        for _, monster in pairs(self.mMonsters) do
            if EntityCustomManager.singleton():getEntityByHostKey(monster:getProperty():cache().mEntityHostKey) and result.entity.entityId == EntityCustomManager.singleton():getEntityByHostKey(monster:getProperty():cache().mEntityHostKey).mEntity.entityId then
                monster:onHit(weapon)
                break
            end
        end
    end
end

function Client_GameMonsterManager:getProperty()
    return self.mProperty
end

function Client_GameMonsterManager:_createMonster(id)
    local ret = new(Client_GameMonster, {mID = id})
    self.mMonsters[#self.mMonsters + 1] = ret
    return ret
end

function Client_GameMonsterManager:_destroyMonster(id)
    for i, monster in pairs(self.mMonsters) do
        if monster:getID() == id then
            delete(monster)
            table.remove(self.mMonsters, i)
            break
        end
    end
end
-----------------------------------------------------------------------------------------Client_GameEffectManager-----------------------------------------------------------------------------------
function Client_GameEffectManager:construction(parameter)
    self.mEffectManager = new(GameEffectManager)

    Client.addListener("GameEffectManager", self)
end

function Client_GameEffectManager:destruction()
    delete(self.mEffectManager)
    self.mEffectManager = nil

    Client.removeListener("GameEffectManager", self)
end

function Client_GameEffectManager:initialize()
end

function Client_GameEffectManager:receive(parameter)
    if parameter.mMessage == "MonsterDead" then
        self.mEffectManager:createMonsterDead(parameter.mParameter.mMonsterInfo, parameter.mParameter.mPlayerInfos)
    end
end

function Client_GameEffectManager:update()
    self.mEffectManager:update()
end
-----------------------------------------------------------------------------------------Client_GamePlayer-----------------------------------------------------------------------------------
function Client_GamePlayer:construction(parameter)
    self.mPlayerID = parameter.mPlayerID
    self.mProperty = new(GamePlayerProperty, {mPlayerID = self.mPlayerID})
    self.mHeadOnUIs = {}
    self.mNextHeadOnUIID = 1
    if self.mPlayerID == GetPlayerId() then
        local saved_data = getSavedData()
        saved_data.mHPLevel = saved_data.mHPLevel or 1
        saved_data.mAttackValueLevel = saved_data.mAttackValueLevel or 1
        saved_data.mAttackTimeLevel = saved_data.mAttackTimeLevel or 1
        saved_data.mMoney = saved_data.mMoney or 0
        saved_data.mKill = saved_data.mKill or 0
        self.mProperty:safeWrite("mHPLevel", saved_data.mHPLevel)
        self.mProperty:safeWrite("mAttackValueLevel", saved_data.mAttackValueLevel)
        self.mProperty:safeWrite("mAttackTimeLevel", saved_data.mAttackTimeLevel)
        self.mProperty:safeWrite("mMoney", saved_data.mMoney)
        self.mProperty:safeWrite("mKill", saved_data.mKill)

        initUi()

        InputManager.addListener(
            self,
            function(_, event)
                if event.event_type == "keyPressEvent" then
                    if event.keyname == "DIK_U" then
                        setUiValue("upgrade_background", "visible", not getUiValue("upgrade_background", "visible"))
                    elseif event.keyname == "DIK_TAB" then
                        setUiValue("ranking_background", "visible", not getUiValue("ranking_background", "visible"))
                    elseif event.keyname == "DIK_L" then
                        setUiValue(
                            "chooseLevel_background",
                            "visible",
                            not getUiValue("chooseLevel_background", "visible")
                        )
                    end
                elseif event.event_type == "mouseReleaseEvent" and event.mouse_button == "left" then
                    local pick_result = Pick(false, true, true, false, false)
                    if pick_result and pick_result.block_id and pick_result.block_id == GameConfig.mTowerPointBlockID then
                    end
                end
            end
        )
        Client_Game.singleton():getProperty():addPropertyListener(
            "mState",
            self,
            function(_, value)
                if value == "Fight" then
                    setUiValue("upgrade_background", "visible", false)
                    setUiValue("levelInfo_background", "visible", true)
                elseif value == "SafeHouse" then
                    setUiValue("upgrade_background", "visible", true)
                    setUiValue("levelInfo_background", "visible", false)
                end
            end
        )
        Client_Game.singleton():getProperty():addPropertyListener(
            "mSafeHouseLeftTime",
            self,
            function(_, value)
                if value then
                    Tip("请抓紧时间升级您的战斗力，离开始下一关卡还有" .. tostring(math.floor(value)) .. "秒", 1400, "255 255 0", "notice")
                end
            end
        )
        self.mProperty:addPropertyListener(
            "mAttackTimeLevel",
            self,
            function()
            end
        )
    else
        self.mProperty:addPropertyListener(
            "mAttackTimeLevel",
            self,
            function()
            end
        )
    end
    self.mProperty:addPropertyListener(
        "mHPLevel",
        self,
        function()
        end
    )
    self.mProperty:addPropertyListener(
        "mAttackValueLevel",
        self,
        function()
        end
    )
    self.mProperty:addPropertyListener(
        "mHP",
        self,
        function(_, value)
            if value then
                self:_updateBloodUI()
            end
        end
    )
    self.mProperty:addPropertyListener(
        "mMoney",
        self,
        function(_, value)
        end
    )
    self.mProperty:addPropertyListener(
        "mKill",
        self,
        function(_, value)
        end
    )

    Client.addListener(self:_getSendKey(), self)
end

function Client_GamePlayer:destruction()
    self.mProperty:removePropertyListener("mHPLevel", self)
    self.mProperty:removePropertyListener("mAttackValueLevel", self)
    self.mProperty:removePropertyListener("mAttackTimeLevel", self)
    self.mProperty:removePropertyListener("mHP", self)
    self.mProperty:removePropertyListener("mMoney", self)
    delete(self.mProperty)
    if self.mBloodUI then
        self.mBloodUI:destroy()
        self.mBloodUI = nil
    end
    for _,ui in pairs(self.mHeadOnUIs) do
        ui:destroy()
    end
    self.mHeadOnUIs = nil
    if self.mPlayerID == GetPlayerId() then
        uninitUi()
        InputManager.removeListener(self)
    end
    Client.removeListener(self:_getSendKey(), self)
end

function Client_GamePlayer:update()
    if self.mPlayerID == GetPlayerId() then
    end
end

function Client_GamePlayer:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
    else
        if parameter.mMessage == "AddMoney" then
            local saved_data = getSavedData()
            saved_data.mMoney = saved_data.mMoney + parameter.mParameter.mMoney
            self.mProperty:safeWrite("mMoney", saved_data.mMoney)
            if GetEntityHeadOnObject(self.mPlayerID, "AddMoney/" .. tostring(self.mPlayerID)) then
                local ui =
                    GetEntityHeadOnObject(self.mPlayerID, "AddMoney/" .. tostring(self.mPlayerID)):createChild(
                    {
                        type = "text",
                        font_type = "微软雅黑",
                        font_color = "255 225 0",
                        font_size = 50,
                        align = "_ct",
                        y = -80,
                        x = -80,
                        height = 50,
                        width = 300,
                        visible = true,
                        text = "+￥" .. tostring(processFloat(parameter.mParameter.mMoney, 2))
                    }
                )
                local ui_id = self:_generateNextHeadOnUIID()
                self.mHeadOnUIs[ui_id] = ui
                CommandQueueManager.singleton():post(
                    new(
                        Command_Callback,
                        {
                            mDebug = "Client_GamePlayer:AddMoney/UI",
                            mExecutingCallback = function(command)
                                command.mTimer = command.mTimer or new(Timer)
                                if command.mTimer:total() > 0.8 then
                                    ui:destroy()
                                    self.mHeadOnUIs[ui_id] = nil
                                    command.mState = Command.EState.Finish
                                else
                                    ui.y = -80 - 150 * command.mTimer:total()
                                end
                            end
                        }
                    )
                )
            end
        elseif parameter.mMessage == "OnHit" then
            if GetEntityHeadOnObject(self.mPlayerID, "OnHit/" .. tostring(self.mPlayerID)) then
                local ui =
                    GetEntityHeadOnObject(self.mPlayerID, "OnHit/" .. tostring(self.mPlayerID)):createChild(
                    {
                        type = "text",
                        font_type = "微软雅黑",
                        font_color = "255 0 0",
                        font_size = 50,
                        align = "_ct",
                        y = -60,
                        x = -80,
                        height = 50,
                        width = 200,
                        visible = true,
                        text = "-" .. tostring(parameter.mParameter.mValue)
                    }
                )
                local ui_id = self:_generateNextHeadOnUIID()
                self.mHeadOnUIs[ui_id] = ui
                CommandQueueManager.singleton():post(
                    new(
                        Command_Callback,
                        {
                            mDebug = "Client_GamePlayer:OnHit/UI",
                            mExecutingCallback = function(command)
                                command.mTimer = command.mTimer or new(Timer)
                                if command.mTimer:total() > 0.8 then
                                    ui:destroy()
                                    self.mHeadOnUIs[ui_id] = nil
                                    command.mState = Command.EState.Finish
                                else
                                    ui.y = -60 - 150 * command.mTimer:total()
                                end
                            end
                        }
                    )
                )
            end
        end
    end
end

function Client_GamePlayer:sendToHost(message, parameter)
    Client.sendToHost(self:_getSendKey(), {mMessage = message, mParameter = parameter})
end

function Client_GamePlayer:onHit(weapon, result)
    if self.mPlayerID == GetPlayerId() then
        local x, y, z = GetPlayer():GetBlockPos()
        local src_position =
            GetPlayer():getPosition() + vector3d:new(0, 0.5, 0) + vector3d:new(GetEntityDirection(self.mPlayerID)) * 0.5
        local target_position
        local track_bullet = {
            mType = "Ray",
            mTime = 1,
            mSpeed = 100,
            mSrcPosition = src_position,
            mModelFacing = GetPlayer():GetFacing() - 1.57
        }
        if result.entity then
            target_position = result.entity:getPosition() + vector3d:new(0, 0.1, 0)
        elseif result.blockX and result.blockY and result.blockZ then
            target_position = {}
            target_position[1], target_position[2], target_position[3] =
                ConvertToRealPosition(result.blockX, result.blockY, result.blockZ)
        else
            target_position = src_position + vector3d:new(GetEntityDirection(self.mPlayerID)) * 100
        end
        local dir = target_position - src_position
        local length = dir:length()
        track_bullet.mTime = length / track_bullet.mSpeed
        track_bullet.mDirection = dir:normalize()
        local track_hit = {
            mType = "Point",
            mTime = 0.1,
            mSrcPosition = target_position - track_bullet.mDirection,
            mModel = {mFile = GameConfig.mHitEffect.mModel.mFile, mResource = GameConfig.mHitEffect.mModel.mResource,mScaling = GameConfig.mHitEffect.mModel.mScaling}
        }
        local function create_track_entity()
            if track_bullet.mModel and track_hit.mModel then
                EntityCustomManager.singleton():createTrackEntity({track_bullet, track_hit})
            end
        end
        GetResourceModel(
            GameConfig.mBullet.mModel.mResource,
            function(path, err)
                track_bullet.mModel = {mFile = path}
                create_track_entity()
            end
        )
    end
end

function Client_GamePlayer:getID()
    return self.mPlayerID
end

function Client_GamePlayer:getProperty()
    return self.mProperty
end

function Client_GamePlayer:getEntity()
    return GetEntityById(self.mPlayerID)
end

function Client_GamePlayer:_getSendKey()
    return "GamePlayer/" .. tostring(self.mPlayerID)
end

function Client_GamePlayer:_updateBloodUI()
    if not self.mBloodUI and GetEntityHeadOnObject(self.mPlayerID, "Blood/" .. tostring(self.mPlayerID)) then
        self.mBloodUI =
            GetEntityHeadOnObject(self.mPlayerID, "Blood/" .. tostring(self.mPlayerID)):createChild(
            {
                ui_name = "background",
                type = "container",
                color = "0 255 0",
                align = "_ct",
                y = -50,
                x = -150,
                height = 20,
                width = 200,
                visible = true
            }
        )
    end
    if self.mProperty:cache().mHP and self.mProperty:cache().mHPLevel and self.mBloodUI then
        self.mBloodUI.width =
            200 * self.mProperty:cache().mHP / GameCompute.computePlayerHP(self.mProperty:cache().mHPLevel)
    end
end

function Client_GamePlayer:_generateNextHeadOnUIID()
    local ret = self.mNextHeadOnUIID
    self.mNextHeadOnUIID = self.mNextHeadOnUIID + 1
    return ret
end
-----------------------------------------------------------------------------------------Client_GameMonster-----------------------------------------------------------------------------------
function Client_GameMonster:construction(parameter)
    self.mCommandQueue = CommandQueueManager.singleton():createQueue()
    self.mID = parameter.mID
    self.mProperty = new(GameMonsterProperty, {mID = self.mID})
    self.mHeadOnUIs = {}
    self.mNextHeadOnUIID = 1

    self.mProperty:addPropertyListener(
        "mEntityHostKey",
        self,
        function(_, value)
            self:_updateBloodUI()
        end
    )
    self.mProperty:addPropertyListener(
        "mLevel",
        self,
        function()
        end
    )
    self.mProperty:addPropertyListener(
        "mHP",
        self,
        function(_, value)
            self:_updateBloodUI()
        end
    )
    self.mProperty:addPropertyListener(
        "mConfigIndex",
        self,
        function(_, value)
            self:_updateBloodUI()
        end
    )
    Client.addListener(self:_getSendKey(), self)
end

function Client_GameMonster:destruction()
    self.mProperty:removePropertyListener("mEntityHostKey", self)
    self.mProperty:removePropertyListener("mLevel", self)
    self.mProperty:removePropertyListener("mHP", self)
    self.mProperty:removePropertyListener("mConfigIndex", self)
    if self.mBloodUI then
        self.mBloodUI:destroy()
        self.mBloodUI = nil
    end
    if self.mNameUI then
        self.mNameUI:destroy()
        self.mNameUI = nil
    end
    for _,ui in pairs(self.mHeadOnUIs) do
        ui:destroy()
    end
    self.mHeadOnUIs = nil
    delete(self.mProperty)
    CommandQueueManager.singleton():destroyQueue(self.mCommandQueue)
    Client.removeListener(self:_getSendKey(), self)
end

function Client_GameMonster:update()
end

function Client_GameMonster:sendToHost(message, parameter)
    Client.sendToHost(self:_getSendKey(), {mMessage = message, mParameter = parameter})
end

function Client_GameMonster:receive(parameter)
end

function Client_GameMonster:getID()
    return self.mID
end

function Client_GameMonster:getProperty()
    return self.mProperty
end

function Client_GameMonster:getConfig()
    if self.mProperty:cache().mConfigIndex then
        return GameConfig.mMonsterLibrary[self.mProperty:cache().mConfigIndex]
    end
end

function Client_GameMonster:onHit(weapon)
    local hit_value =
        GameCompute.computePlayerAttackValue(
        Client_Game.singleton():getPlayerManager():getPlayerByID():getProperty():cache().mAttackValueLevel
    )
    if
    EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey) and EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey).mEntity and
    EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey).mEntity:GetInnerObject() and
            GetEntityHeadOnObject(
                EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey).mEntity.entityId,
                "OnHit/" .. tostring(EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey).mEntity.entityId)
            )
     then
        local ui =
            GetEntityHeadOnObject(
                EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey).mEntity.entityId,
            "OnHit/" .. tostring(EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey).mEntity.entityId)
        ):createChild(
            {
                ui_name = "background",
                type = "text",
                font_type = "微软雅黑",
                font_color = "255 0 0",
                font_size = 50,
                align = "_ct",
                y = -100,
                x = -80,
                height = 50,
                width = 200,
                visible = true,
                text = "-" .. tostring(hit_value)
            }
        )
        local ui_id = self:_generateNextHeadOnUIID()
        self.mHeadOnUIs[ui_id] = ui
        CommandQueueManager.singleton():post(
            new(
                Command_Callback,
                {
                    mDebug = "Client_GameMonster:onHit/UI",
                    mExecutingCallback = function(command)
                        command.mTimer = command.mTimer or new(Timer)
                        if command.mTimer:total() > 0.5 then
                            ui:destroy()
                            self.mHeadOnUIs[ui_id] = nil
                            command.mState = Command.EState.Finish
                        else
                            ui.y = -100 - 150 * command.mTimer:total()
                        end
                    end
                }
            )
        )
    end
    local property_change = {}
    property_change.mHPSubtract = hit_value
    self:sendToHost("PropertyChange", property_change)
end

function Client_GameMonster:_getSendKey()
    return "GameMonster/" .. tostring(self.mID)
end

function Client_GameMonster:_updateBloodUI()
    if self:getProperty():cache().mEntityHostKey then
        local entity = EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey)
        if
        entity and entity.mEntity and entity.mEntity.entityId and
        entity.mEntity:GetInnerObject() and
                GetEntityHeadOnObject(
                    entity.mEntity.entityId,
                    "Blood/" .. tostring(entity.mEntity.entityId)
                )
        then
            self.mUIEntityID = entity.mEntity.entityId
            if not self.mBloodUI then
                self.mBloodUI =
                    GetEntityHeadOnObject(
                        entity.mEntity.entityId,
                    "Blood/" .. tostring(entity.mEntity.entityId)
                ):createChild(
                    {
                        ui_name = "background",
                        type = "container",
                        color = "255 0 0",
                        align = "_ct",
                        y = -100,
                        x = -130,
                        height = 20,
                        width = 200,
                        visible = true
                    }
                )
            end
            if not self.mNameUI then
                self.mNameUI =
                    GetEntityHeadOnObject(
                        entity.mEntity.entityId,
                    "Name/" .. tostring(entity.mEntity.entityId)
                ):createChild(
                    {
                        ui_name = "background",
                        type = "text",
                        font_type = "微软雅黑",
                        font_color = "0 255 0",
                        font_size = 25,
                        align = "_ct",
                        y = -150,
                        x = -130,
                        height = 50,
                        width = 200,
                        visible = true
                    }
                )
            end
        end
    end
    if self.mBloodUI and self.mNameUI then
        if self.mProperty:cache().mHP and self.mProperty:cache().mLevel then
            self.mBloodUI.width =
                200 * self.mProperty:cache().mHP / GameCompute.computeMonsterHP(self.mProperty:cache().mLevel)
        end
        if self:getConfig() and self.mProperty:cache().mLevel then
            self.mNameUI.text = "Lv" .. tostring(self.mProperty:cache().mLevel) .. " " .. self:getConfig().mName
        end
    else
        self.mCommandQueue:post(
            new(
                Command_Callback,
                {
                    mDebug = "Client_GameMonster:_updateBloodUI",
                    mExecuteCallback = function(command)
                        self:_updateBloodUI()
                        command.mState = Command.EState.Finish
                    end
                }
            )
        )
    end
end

function Client_GameMonster:_generateNextHeadOnUIID()
    local ret = self.mNextHeadOnUIID
    self.mNextHeadOnUIID = self.mNextHeadOnUIID + 1
    return ret
end
-----------------------------------------------------------------------------------------Client_GameProtecter-----------------------------------------------------------------------------------
function Client_GameProtecter:construction(parameter)
    self.mCommandQueue = CommandQueueManager.singleton():createQueue()
    self.mProperty = new(GameProtecterProperty)
    self.mHeadOnUIs = {}
    self.mNextHeadOnUIID = 1

    self.mProperty:addPropertyListener(
        "mEntityHostKey",
        self,
        function(_, value)
            self:_updateBloodUI()
        end
    )
    self.mProperty:addPropertyListener(
        "mHP",
        self,
        function(_, value)
            self:_updateBloodUI()
        end
    )
    Client.addListener(self:_getSendKey(), self)
end

function Client_GameProtecter:destruction()
    delete(self.mProperty)
    self.mProperty = nil
    CommandQueueManager.singleton():destroyQueue(self.mCommandQueue)
    self.mCommandQueue = nil
end

function Client_GameProtecter:getProperty()
    return self.mProperty
end

function Client_GameProtecter:_getSendKey()
    return "GameProtecter"
end

function Client_GameProtecter:_updateBloodUI()
    if self:getProperty():cache().mEntityHostKey then
        local entity = EntityCustomManager.singleton():getEntityByHostKey(self:getProperty():cache().mEntityHostKey)
        if
        entity and entity.mEntity and entity.mEntity.entityId and
        entity.mEntity:GetInnerObject() and
                GetEntityHeadOnObject(
                    entity.mEntity.entityId,
                    "Blood/" .. tostring(entity.mEntity.entityId)
                )
        then
            self.mUIEntityID = entity.mEntity.entityId
            if not self.mBloodUI then
                self.mBloodUI =
                    GetEntityHeadOnObject(
                        entity.mEntity.entityId,
                    "Blood/" .. tostring(entity.mEntity.entityId)
                ):createChild(
                    {
                        ui_name = "background",
                        type = "container",
                        color = "255 0 0",
                        align = "_ct",
                        y = -100,
                        x = -130,
                        height = 20,
                        width = 200,
                        visible = true
                    }
                )
            end
            if not self.mNameUI then
                self.mNameUI =
                    GetEntityHeadOnObject(
                        entity.mEntity.entityId,
                    "Name/" .. tostring(entity.mEntity.entityId)
                ):createChild(
                    {
                        ui_name = "background",
                        type = "text",
                        font_type = "微软雅黑",
                        font_color = "0 255 0",
                        font_size = 25,
                        align = "_ct",
                        y = -150,
                        x = -130,
                        height = 50,
                        width = 200,
                        visible = true
                    }
                )
            end
        end
    end
    if self.mBloodUI and self.mNameUI then
        if self.mProperty:cache().mHP then
            self.mBloodUI.width =
                200 * self.mProperty:cache().mHP / GameConfig.mProtecter.mHP
        end
        self.mNameUI.text = "又粗又大又黑又长"
    else
        self.mCommandQueue:post(
            new(
                Command_Callback,
                {
                    mDebug = "Client_GameProtecter:_updateBloodUI",
                    mExecuteCallback = function(command)
                        self:_updateBloodUI()
                        command.mState = Command.EState.Finish
                    end
                }
            )
        )
    end
end

function Client_GameProtecter:_generateNextHeadOnUIID()
    local ret = self.mNextHeadOnUIID
    self.mNextHeadOnUIID = self.mNextHeadOnUIID + 1
    return ret
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 入口
function main()
    Framework.singleton(true)
    Client_Game.singleton(true)
    SendTo("host", {mMessage = "CheckHost"})
end

function clear()
    for i = 1, 9 do
        SetItemStackToInventory(i, {})
    end

    delete(Client_Game.singleton())
    if Host_Game.singleton() then
        delete(Host_Game.singleton())
        Host.broadcast({mMessage = "Clear"})
    end
    delete(Framework.singleton())
end

-- 获取输入
function handleInput(event)
    if Framework.singleton() then
        Framework.singleton():handleInput(event)
    end
end

function receiveMsg(parameter)
    if parameter.mMessage == "CheckHost" then
        if not Host_Game.singleton() then
            new(Host_Game)
        end
    elseif parameter.mMessage == "Clear" then
        clear()
    end
    if Framework.singleton() then
        Framework.singleton():receiveMsg(parameter)
    end
end

function update()
    if Framework.singleton() then
        Framework.singleton():update()
    end
    local delta_time = Timer.global():delta()
    if Host_Game.singleton() then
        Host_Game.singleton():update(delta_time)
    end
    if Client_Game.singleton() then
        Client_Game.singleton():update(delta_time)
    end
end
