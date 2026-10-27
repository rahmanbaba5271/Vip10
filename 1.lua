--[[ SERVER CODE DUMPED ]]
--[[ File: BRPlayerCharacterBase.lua (ANTI-BAN FIXED) ]]

local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:ctor() end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then self.STCharacterMovement.bPositiveBlowUp = true end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FinishedState" }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then return end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "") end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "") end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI() end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam() end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState() end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  if self.HandleOnLanded then self:HandleOnLanded(-1) end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState() end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI() end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then GameplayData.RemoveCharacter(self.Object) end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else return false end
end

function BRPlayerCharacterBase:BPOnRecycled() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:BPOnRespawned() if Client then self:ResetMeshRelativeLocationAndRotation() end end
function BRPlayerCharacterBase:ReceiveOnRecycle() if Client then self:ResetMeshRelativeLocationAndRotation() GameplayData.RemoveCharacter(self.Object) end end
function BRPlayerCharacterBase:ReceiveOnSpawn() if Client then self:ResetMeshRelativeLocationAndRotation() GameplayData.AddCharacter(self.Object) end end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false) end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then return end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then return end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then return end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then uCurPlayerState:AddGeneralCount(468, 1, false) end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then return end
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then MedievalCrane:RemoveCharacter(self.Object) end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then return end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) or not Lifter.AddCharacter then return end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then return false end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:DisplayGameTipWithMsgID(48532) end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue() self:HandleNearDeathGiveupRescue() end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then uPlayerState:AddGeneralCount(1613, 1, false) end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then self:MulticastRPC_GmPlayAction(actionId) end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then return end
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then return end
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then return end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  function loadLater() uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0) end
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  if slua.isValid(self.ParachuteComponent) then self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt) end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID) self:SetAttrValue("AreaID", AreaID, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end

function BRPlayerCharacterBase:DoModChangeToBT()
  if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then return false end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ==============================================================================
-- ============================ BẮT ĐẦU LOGIC MOD (ANTI-BAN & MAGIC) ============
-- ==============================================================================

local function Valid(obj) 
    if not obj then return false end 
    if slua and slua.isValid then 
        local ok, v = pcall(slua.isValid, obj) 
        if not ok or not v then return false end 
    end 
    return true 
end

_G.LexusConfig = _G.LexusConfig or { CustomMagicBullet = true }
_G.LexusState = _G.LexusState or { CustomTextData = nil }

-- Magic Bullet Settings (Head High, Body/Legs Low)
_G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {
    MagicHead = 4.5,
    MagicBody = 1.2,
    MagicLegs = 0.8,
}

-- ========================================== 
-- 🛡️ ANTI-BAN & BYPASS SYSTEM (HWID SPOOFER) 🛡️
-- ==========================================
pcall(function()
    -- 1. HWID Spoofer (Randomize Hardware ID to avoid detection)
    local SystemLib = import("KismetSystemLibrary")
    if SystemLib and not _G.Bypass_Hooked then
        _G.Original_GetDeviceId = SystemLib.GetDeviceId
        SystemLib.GetDeviceId = function(...)
            if not _G.FakeHWID_String then
                local chars = "0123456789abcdef"
                local hwid = ""
                math.randomseed(os.time())
                for i = 1, 32 do 
                    hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) 
                end
                _G.FakeHWID_String = hwid
            end
            return _G.FakeHWID_String
        end
        _G.Bypass_Hooked = true
    end

    -- 2. Anti-Cheat Debugger Block (Prevents game from seeing attached debuggers)
    local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
    if SecurityCommonUtils then
        SecurityCommonUtils.IsDebuggerPresent = function() return false end
        SecurityCommonUtils.IsRooted = function() return false end
        SecurityCommonUtils.IsEmulator = function() return false end
    end

    -- 3. Block Integrity Checks
    local HiggsBoson = import("HiggsBoson")
    if HiggsBoson then
        HiggsBoson.IsCheatDetected = function() return false end
    end
end)

-- ========================================== 
-- FORCE HEADSHOT HIT LOGIC
-- ==========================================
function _G.InitializeAutoHeadHooks()
    pcall(function()
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end

        local modulesToHook = {
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity"
        }
        
        for _, path in ipairs(modulesToHook) do
            local hitLogic = package.loaded[path]
            if hitLogic then
                if not hitLogic._MBHooked then
                    hitLogic._MBHooked = true
                    
                    local original_GetHitBodyType = hitLogic.GetHitBodyType
                    hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                        if _G.LexusConfig.CustomMagicBullet then return EAvatarDamagePosition.BigHead end
                        if original_GetHitBodyType then return original_GetHitBodyType(self, ImpactResult, InImpactVec) end
                    end

                    local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                    hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                        if _G.LexusConfig.CustomMagicBullet then return EAvatarDamagePosition.BigHead end
                        if original_GetHitBodyTypeByHitPos then return original_GetHitBodyTypeByHitPos(self, InImpactVec) end
                    end
                end
            end
        end
    end)
end

-- ========================================== 
-- MAGIC BULLET (HITBOX EXPANDER)
-- ========================================== 
local _lastMagicHash = "OFF"
local _moddedPhysAssets = {}
local _origHitboxes = {}

local function ProcessMagicBullet()
    local mHead, mBody, mLegs = 1.0, 1.0, 1.0
    local runInject = false
    
    if _G.LexusConfig.CustomMagicBullet then
        runInject = true
        local cData = _G.LexusState.CustomTextData
        mHead = tonumber(cData.MagicHead) or 4.5
        mBody = tonumber(cData.MagicBody) or 1.2
        mLegs = tonumber(cData.MagicLegs) or 0.8
    end

    local currentHash = "M_"..tostring(mHead).."_"..tostring(mBody).."_"..tostring(mLegs)
    if not runInject then currentHash = "OFF" end

    if _lastMagicHash ~= currentHash then
        _lastMagicHash = currentHash
        _moddedPhysAssets = {}
    end

    local BoneScaleMap = {
        ["head"] = mHead, ["neck_01"] = mHead,
        ["pelvis"] = mBody, ["spine_01"] = mBody, ["spine_02"] = mBody, ["spine_03"] = mBody,
        ["thigh_l"] = mLegs, ["thigh_r"] = mLegs, 
        ["calf_l"] = mLegs, ["calf_r"] = mLegs,   
        ["foot_l"] = mLegs, ["foot_r"] = mLegs    
    }

    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not Valid(localPlayer) then return end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then 
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then 
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end 
    end

    local function GetFirstElemSafe(elemArray)
        if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
            if type(elemArray.Get) == "function" then return elemArray:Get(0) end
        elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
            return elemArray[1]
        end
        return nil
    end

    for _, enemy in pairs(allCharacters) do
        if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
            local bIsReallyDead = false
            pcall(function()
                if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
            end)

            if not bIsReallyDead then
                pcall(function()
                    local EnemyMesh = enemy.Mesh
                    if Valid(EnemyMesh) then
                        local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
                        
                        if enemy._MagicBulletHash == currentHash and enemy._MagicTargetID == uniqueID then return end

                        local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
                        if not Valid(PhysicsAsset) and EnemyMesh.SkeletalMesh then PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset end

                        if Valid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                            local PhysAssetName = "DefaultPhys"
                            pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                            
                            if _moddedPhysAssets[PhysAssetName] ~= currentHash then
                                if not _origHitboxes[PhysAssetName] then _origHitboxes[PhysAssetName] = {} end
                                local OrigHitboxData = _origHitboxes[PhysAssetName]

                                local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                                local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or #SkeletalBodySetups
                                local limit = numSetups > 50 and 50 or numSetups

                                for i = 1, limit do 
                                    local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i]
                                    if Valid(BodySetup) then
                                        local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                                        local MatchedBoneKey = nil
                                        for k, _ in pairs(BoneScaleMap) do
                                            if string.find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                                        end

                                        if MatchedBoneKey then
                                            local TargetScale = 1.0 
                                            if runInject then TargetScale = BoneScaleMap[MatchedBoneKey] end
                                            
                                            local AggGeom = BodySetup.AggGeom
                                            local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                                            local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                                            local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems

                                            local BoxElem = GetFirstElemSafe(BoxElems)
                                            local SphereElem = GetFirstElemSafe(SphereElems)
                                            local SphylElem = GetFirstElemSafe(SphylElems)

                                            if not OrigHitboxData[MatchedBoneKey] then
                                                OrigHitboxData[MatchedBoneKey] = { Box = nil, Sphere = nil, Sphyl = nil }
                                                if BoxElem then OrigHitboxData[MatchedBoneKey].Box = { X = BoxElem.X, Y = BoxElem.Y, Z = BoxElem.Z } end
                                                if SphereElem then OrigHitboxData[MatchedBoneKey].Sphere = { Radius = SphereElem.Radius } end
                                                if SphylElem then OrigHitboxData[MatchedBoneKey].Sphyl = { Radius = SphylElem.Radius, Length = SphylElem.Length } end
                                            end

                                            local OrigElemData = OrigHitboxData[MatchedBoneKey]

                                            if OrigElemData.Box and BoxElem then
                                                BoxElem.X = OrigElemData.Box.X * TargetScale
                                                BoxElem.Y = OrigElemData.Box.Y * TargetScale
                                                BoxElem.Z = OrigElemData.Box.Z * TargetScale
                                                if type(BoxElems.Set) == "function" then BoxElems:Set(0, BoxElem) else BoxElems[1] = BoxElem end
                                                if AggGeom then AggGeom.BoxElems = BoxElems; BodySetup.AggGeom = AggGeom else BodySetup.BoxElems = BoxElems end
                                            end

                                            if OrigElemData.Sphere and SphereElem then
                                                SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                                                if type(SphereElems.Set) == "function" then SphereElems:Set(0, SphereElem) else SphereElems[1] = SphereElem end
                                                if AggGeom then AggGeom.SphereElems = SphereElems; BodySetup.AggGeom = AggGeom else BodySetup.SphereElems = SphereElems end
                                            end

                                            if OrigElemData.Sphyl and SphylElem then
                                                SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                                                SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                                                if type(SphylElems.Set) == "function" then SphylElems:Set(0, SphylElem) else SphylElems[1] = SphylElem end
                                                if AggGeom then AggGeom.SphylElems = SphylElems; BodySetup.AggGeom = AggGeom else BodySetup.SphylElems = SphylElems end
                                            end
                                        end
                                    end
                                end
                                _moddedPhysAssets[PhysAssetName] = currentHash
                            end
                            
                            if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                            EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                            
                            enemy._MagicBulletHash = currentHash
                            enemy._MagicTargetID = uniqueID
                        end
                    end
                end)
            end
        end
    end
end

-- ========================================== 
-- MAIN LOOP (DELAYED FOR ANTI-BAN)
-- ========================================== 
local function MainLoop()
    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end 
    local pc = GameplayData.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    if not Valid(localPlayer) then return end

    ProcessMagicBullet()
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1 
local myToken = _G.LexusState.LoopToken

local function FastTick() 
    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop) 
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then 
        -- Thêm delay ngẫu nhiên (0.05 - 0.08s) để Anti-cheat không phát hiện vòng lặp đều đặn
        local randomDelay = 0.05 + (math.random() * 0.03)
        ticker.AddTimerOnce(randomDelay, FastTick) 
    end 
end

pcall(function() 
    -- Delay 2.5s khi vừa vào trận để tránh bị scan lúc load map
    require("common.time_ticker").AddTimerOnce(2.5, function()
        if _G.InitializeAutoHeadHooks then _G.InitializeAutoHeadHooks() end
        FastTick()
    end) 
end)

-- ==============================================================================
-- ================= KẾT THÚC LOGIC MOD =========================================
-- ==============================================================================

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildAircraftVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    UnifiedBuildVehicleFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.UnifiedBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    ParachuteSprint = "GameLua.Mod.BaseMod.GamePlay.Feature.Parachute.ParachuteSprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  },
  {
    FPPAnimMonitor = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature"
  }
}, "BRPlayerCharacterBase")
