class ZedSpawner extends Info
	config(ZedSpawner);

const dt = 1;

const CfgSpawn         = class'Config_Spawner';
const CfgSpawnListR    = class'Config_SpawnListRegular';
const CfgSpawnListBW   = class'Config_SpawnListBossWaves';
const CfgSpawnListSW   = class'Config_SpawnListSpecialWaves';
const CfgSpawnManagerE = class'Config_SpawnManager_Endless';
const CfgSpawnManagerS = class'Config_SpawnManager_Short';
const CfgSpawnManagerN = class'Config_SpawnManager_Normal';
const CfgSpawnManagerL = class'Config_SpawnManager_Long';

const SpawnManagerS    = class'AISpawnManager_Short';
const SpawnManagerN    = class'AISpawnManager_Normal';
const SpawnManagerL    = class'AISpawnManager_Long';
const SpawnManagerE    = class'AISpawnManager_Endless';

struct S_SpawnEntry
{
	var class<KFPawn_Monster> BossClass;
	var class<KFPawn_Monster> ZedClass;
	var int   Wave;
	var int   SpawnCountBase;
	var int   SingleSpawnLimitDefault;
	var int   SingleSpawnLimit;
	var float Probability;
	var float RelativeStartDefault;
	var float RelativeStart;
	var int   DelayDefault;
	var int   Delay;
	var int   SpawnsLeft;
	var int   SpawnsTotal;
	var bool  SpawnAtPlayerStart;
};

var config bool       bConfigInitialized;
var config E_LogLevel LogLevel;

var private Array<S_SpawnEntry> SpawnListR;
var private Array<S_SpawnEntry> SpawnListBW;
var private Array<S_SpawnEntry> SpawnListSW;

var private KFGameInfo_Survival KFGIS;
var private KFGameInfo_Endless  KFGIE;

var private KFGI_Access KFGIA;

var private int CurrentWave;
var private int CurrentCycle;
var private int CycleWaveShift;
var private int CycleWaveSize;

var private int WaveTotalAI;
var private class<KFPawn_Monster> CurrentBossClass;
var private int SpecialWave;

var private String SpawnTimerLastMessage;

var private Array<class<KFPawn_Monster> > BossClassCache;
var private Array<class<KFPawn_Monster> > CustomZeds;

delegate bool WaveCondition(S_SpawnEntry SE);

event PreBeginPlay()
{
	`ZS_Trace(`Location);
	
	Super.PreBeginPlay();
	
	PreInit();
}

event PostBeginPlay()
{
	`ZS_Trace(`Location);
	
	if (bPendingDelete) return;
	
	Super.PostBeginPlay();
	
	PostInit();
}

private function PreInit()
{
	`ZS_Trace(`Location);
	
	if (WorldInfo.NetMode == NM_Client)
	{
		`ZS_Fatal("NetMode == NM_Client, Destroy...");
		Destroy();
		return;
	}
	
	if (!bConfigInitialized)
	{
		bConfigInitialized = true;
		LogLevel = LL_Info;
		SaveConfig();
		CfgSpawn.static.InitConfig();
		CfgSpawnListR.static.InitConfig();
		CfgSpawnListBW.static.InitConfig();
		CfgSpawnListSW.static.InitConfig();
		CfgSpawnManagerS.static.InitConfig();
		CfgSpawnManagerN.static.InitConfig();
		CfgSpawnManagerL.static.InitConfig();
		CfgSpawnManagerE.static.InitConfig();
		`ZS_Info("Config initialized.");
	}
	
	CfgSpawnManagerS.static.InitConfig();
	CfgSpawnManagerN.static.InitConfig();
	CfgSpawnManagerL.static.InitConfig();
	CfgSpawnManagerE.static.InitConfig();

	if (LogLevel == LL_WrongLevel)
	{
		LogLevel = LL_Info;
		`ZS_Warn("Wrong 'LogLevel', return to default value");
		SaveConfig();
	}
	
	`ZS_Log("LogLevel:" @ LogLevel);
	
	if (!CfgSpawn.static.Load(LogLevel))
	{
		`ZS_Fatal("Wrong settings, Destroy...");
		Destroy();
		return;
	}
}

private function PostInit()
{
	local S_SpawnEntry SE;
	local bool NeedInitSM;
	
	`ZS_Trace(`Location);
	
	CurrentWave = INDEX_NONE;
	KFGIS = KFGameInfo_Survival(WorldInfo.Game);
	if (KFGIS == None)
	{
		`ZS_Fatal("Incompatible gamemode:" @ WorldInfo.Game $ ". Destroy...");
		Destroy();
		return;
	}
	
	KFGIA = new(KFGIS) class'KFGI_Access';
	KFGIE = KFGameInfo_Endless(KFGIS);
	
	SpawnListR  = CfgSpawnListR.static.Load(LogLevel);
	SpawnListBW = CfgSpawnListBW.static.Load(LogLevel);
	SpawnListSW = CfgSpawnListSW.static.Load(KFGIE, LogLevel);
	
	CfgSpawnManagerE.static.Load(LogLevel);
	CfgSpawnManagerS.static.Load(LogLevel);
	CfgSpawnManagerN.static.Load(LogLevel);
	CfgSpawnManagerL.static.Load(LogLevel);
	
	SpecialWave = INDEX_NONE;
	CurrentCycle = 1;
	CycleWaveSize = 0;
	CycleWaveShift = MaxInt;
	foreach SpawnListR(SE)
	{
		CycleWaveShift = Min(CycleWaveShift, SE.Wave);
		CycleWaveSize  = Max(CycleWaveSize, SE.Wave);
	}
	CycleWaveSize = CycleWaveSize - CycleWaveShift + 1;
	
	foreach SpawnListBW(SE)
		if (BossClassCache.Find(SE.BossClass) == INDEX_NONE)
			BossClassCache.AddItem(SE.BossClass);
	
	if (true)
	{
		NeedInitSM = (KFGIS.SpawnManager != None);
		KFGIS.SpawnManagerClasses.Length = 0;
		if (KFGIE != None)
		{
			KFGIE.SpawnManagerClasses.AddItem(SpawnManagerE);
		}
		else
		{
			KFGIS.SpawnManagerClasses.AddItem(SpawnManagerS);
			KFGIS.SpawnManagerClasses.AddItem(SpawnManagerN);
			KFGIS.SpawnManagerClasses.AddItem(SpawnManagerL);
		}
		
		if (NeedInitSM)
		{
			KFGIS.InitSpawnManager();
		}
		
		`ZS_Info("SpawnManager replaced");
	}
	
	PreparePreloadContent();
	
	if (SpawnListSW.Length > 0 || SpawnListBW.Length > 0 || SpawnListR.Length > 0)
	{
		SetTimer(float(dt), true, nameof(SpawnTimer));
	}
	else
	{
		`ZS_Info("Spawn timer disabled (no spawn lists)", LogLevel);
	}
}

private function PreparePreloadContent()
{
	local class<KFPawn_Monster> PawnClass;
	
	ExtractCustomZedsFromSpawnList(SpawnListR,  CustomZeds);
	ExtractCustomZedsFromSpawnList(SpawnListBW, CustomZeds);
	ExtractCustomZedsFromSpawnList(SpawnListSW, CustomZeds);
	ExtractCustomZedsFromSpawnManager(AISpawnManager(KFGIS.SpawnManager), CustomZeds);
	
	foreach CustomZeds(PawnClass)
		PawnClass.static.PreloadContent();
}

private function ExtractCustomZedsFromSpawnList(Array<S_SpawnEntry> SpawnList, out Array<class<KFPawn_Monster> > Out)
{
	local S_SpawnEntry SE;
	
	foreach SpawnList(SE)
	{
		if (Out.Find(SE.ZedClass) == INDEX_NONE
		&&  KFGIA.IsCustomZed(SE.ZedClass))
		{
			`ZS_Debug("Add custom zed:" @ SE.ZedClass);
			Out.AddItem(SE.ZedClass);
		}
	}
}

private function ExtractCustomZedsFromSpawnManager(AISpawnManager SpawnManager, out Array<class<KFPawn_Monster> > Out)
{
	// TODO
}

private function PreloadContent(Array<class<KFPawn_Monster> > Pawns)
{
	local class<KFPawn_Monster> KFPM;
	foreach Pawns(KFPM) KFPM.static.PreloadContent();
}

public function bool WaveConditionRegular(S_SpawnEntry SE)
{
	`ZS_Trace(`Location);
	
	return (SE.Wave == KFGIS.WaveNum - CycleWaveSize * (CurrentCycle - 1));
}

public function bool WaveConditionBoss(S_SpawnEntry SE)
{
	local KFPawn_Monster KFPM;
	local int Index;
	
	`ZS_Trace(`Location);
	
	if (CurrentBossClass == None)
	{
		foreach WorldInfo.AllPawns(class'KFPawn_Monster', KFPM)
		{
			Index = BossClassCache.Find(KFPM.class);
			if (Index != INDEX_NONE)
			{
				CurrentBossClass = BossClassCache[Index];
				break;
			}
		}
	}
	
	if (CurrentBossClass == None)
	{
		return false;
	}
	
	return (SE.BossClass == CurrentBossClass);
}

public function bool WaveConditionSpecial(S_SpawnEntry SE)
{
	`ZS_Trace(`Location);
	
	return (SE.Wave == SpecialWave);
}

private function SpawnTimer()
{
	`ZS_Trace(`Location);
	
	if (KFGIS.WaveNum != 0 && CurrentWave < KFGIS.WaveNum)
	{
		SetupWave();
	}
	
	if (!KFGIS.IsWaveActive())
	{
		SpawnTimerLogger(true, "wave is not active");
		return;
	}
	
	if (CfgSpawn.default.AliveSpawnLimit > 0 && KFGIS.AIAliveCount >= CfgSpawn.default.AliveSpawnLimit)
	{
		SpawnTimerLogger(true, "alive spawn limit reached");
		return;
	}
		
	if (!KFGIS.MyKFGRI.IsBossWave() && CfgSpawn.default.bShadowSpawn && KFGIS.MyKFGRI.AIRemaining <= KFGIS.AIAliveCount)
	{
		SpawnTimerLogger(true, "shadow spawn is active and no free spawn slots");
		return;
	}

	SpawnTimerLogger(false);

	if ((SpecialWave == INDEX_NONE && !KFGIS.MyKFGRI.IsBossWave())
	|| (SpecialWave  != INDEX_NONE && !CfgSpawnListSW.default.bStopRegularSpawn)
	|| (KFGIS.MyKFGRI.IsBossWave() && !CfgSpawnListBW.default.bStopRegularSpawn))
	{
		SpawnZeds(SpawnListR, WaveConditionRegular);
	}
	
	if (SpecialWave != INDEX_NONE)
	{
		SpawnZeds(SpawnListSW, WaveConditionSpecial);
	}
	
	if (KFGIS.MyKFGRI.IsBossWave())
	{
		SpawnZeds(SpawnListBW, WaveConditionBoss);
	}
}

private function SetupWave()
{
	local int WaveTotalAIDef;
	
	`ZS_Trace(`Location);
	
	CurrentWave = KFGIS.WaveNum;
	
	if (!KFGIS.MyKFGRI.IsBossWave())
	{
		WaveTotalAIDef = KFGIS.SpawnManager.WaveTotalAI;
		KFGIS.SpawnManager.WaveTotalAI *= CfgSpawn.default.ZedTotalMultiplier;
		WaveTotalAI = KFGIS.SpawnManager.WaveTotalAI;
		KFGIS.MyKFGRI.WaveTotalAICount = KFGIS.SpawnManager.WaveTotalAI;
		KFGIS.MyKFGRI.AIRemaining = KFGIS.SpawnManager.WaveTotalAI; 
			
		if (WaveTotalAIDef != KFGIS.SpawnManager.WaveTotalAI)
		{
			`ZS_Info("increase WaveTotalAI from" @ WaveTotalAIDef @ "to" @ WaveTotalAI @ "due to ZedTotalMultiplier" @ "(" $ CfgSpawn.default.ZedTotalMultiplier $ ")");
		}
	}
	
	if (CfgSpawn.default.bCyclicalSpawn && KFGIS.WaveNum > 1 && KFGIS.WaveNum == CycleWaveShift + CycleWaveSize * CurrentCycle)
	{
		CurrentCycle++;
		`ZS_Info("Next spawn cycle started:" @ CurrentCycle);
	}
	
	ResetSpawnList(SpawnListR);
	ResetSpawnList(SpawnListSW);
	ResetSpawnList(SpawnListBW);
	
	CurrentBossClass = None;
	
	if (KFGIE != None)
	{
		SpecialWave = KFGameReplicationInfo_Endless(KFGIE.GameReplicationInfo).CurrentSpecialMode;
	}
}

private function ResetSpawnList(out Array<S_SpawnEntry> List)
{
	local S_SpawnEntry SE;
	local int Index;
	local float Cycle, Players;
	local float MSB, MSC, MSP;
	local float MLB, MLC, MLP;
	
	`ZS_Trace(`Location);
	
	Cycle   = float(CurrentCycle);
	Players = float(PlayerCount());
	
	MSB = CfgSpawn.default.ZedTotalMultiplier;
	MSC = CfgSpawn.default.SpawnTotalCycleMultiplier;
	MSP = CfgSpawn.default.SpawnTotalPlayerMultiplier;
		
	MLB = CfgSpawn.default.SingleSpawnLimitMultiplier;
	MLC = CfgSpawn.default.SingleSpawnLimitCycleMultiplier;
	MLP = CfgSpawn.default.SingleSpawnLimitPlayerMultiplier;
	
	foreach List(SE, Index)
	{
		if (KFGIS.MyKFGRI.IsBossWave())
		{
			List[Index].RelativeStart = 0.f;
			List[Index].Delay = SE.DelayDefault;
		}
		else
		{
			List[Index].RelativeStart = SE.RelativeStartDefault;
			if (SE.RelativeStart == 0.f)
				List[Index].Delay = SE.DelayDefault;
			else
				List[Index].Delay = 0;
		}

		List[Index].SpawnsTotal = Round(SE.SpawnCountBase *	(MSB + MSC * (Cycle - 1.0f) + MSP * (Players - 1.0f)));
		List[Index].SpawnsLeft  = List[Index].SpawnsTotal;
		
		List[Index].SingleSpawnLimit = Round(SE.SingleSpawnLimitDefault * (MLB + MLC * (Cycle - 1.0f) + MLP * (Players - 1.0f)));
		
		`ZS_Debug(SE.ZedClass @ "SpawnsTotal:" @ List[Index].SpawnsTotal @ "SingleSpawnLimit:" @ List[Index].SingleSpawnLimit);
	}
}

private function SpawnTimerLogger(bool Stop, optional String Reason)
{
	local String Message;
	
	`ZS_Trace(`Location);
	
	if (Stop)
		Message = "Stop spawn";
	else
		Message = "Start spawn";
	
	if (Reason != "")
		Message @= "(" $ Reason $ ")";
	
	if (Message != SpawnTimerLastMessage)
	{
		`ZS_Info(Message);
		SpawnTimerLastMessage = Message;
	}
}

private function SpawnZeds(out Array<S_SpawnEntry> SpawnList, delegate<WaveCondition> Condition)
{
	local S_SpawnEntry SE;
	local int Index;
	
	`ZS_Trace(`Location);

	foreach SpawnList(SE, Index)
	{
		if (Condition(SE))
		{
			if (!ReadyToStart(SE)) continue;
			
			if (ReadyToSpawn(SE))
				SpawnEntry(SpawnListR, Index);
			else
				SpawnListR[Index].Delay -= dt;
		}
	}
}

private function bool ReadyToStart(S_SpawnEntry SE)
{
	`ZS_Trace(`Location);
	
	if (SE.RelativeStart == 0.f)
	{
		return true;
	}
	else
	{
		return (SE.RelativeStart <= 1.0f - (float(KFGIS.MyKFGRI.AIRemaining) / float(WaveTotalAI)));
	}
}

private function bool ReadyToSpawn(S_SpawnEntry SE)
{
	`ZS_Trace(`Location);
	
	return SE.Delay <= 0 && SE.SpawnsLeft > 0;
}

private function SpawnEntry(out Array<S_SpawnEntry> SpawnList, int Index)
{
	local S_SpawnEntry SE;
	local int FreeSpawnSlots, SpawnCount, Spawned;
	local String Message;
	
	`ZS_Trace(`Location);
	
	SE = SpawnList[Index];
	
	SpawnList[Index].Delay = SE.DelayDefault;
	if (FRand() <= SE.Probability)
	{
		if (SE.SingleSpawnLimit == 0 || SE.SpawnsLeft < SE.SingleSpawnLimit)
			SpawnCount = SE.SpawnsLeft;
		else
			SpawnCount = SE.SingleSpawnLimit;
		
		if (CfgSpawn.default.bShadowSpawn && !KFGIS.MyKFGRI.IsBossWave())
		{
			FreeSpawnSlots = KFGIS.MyKFGRI.AIRemaining - KFGIS.AIAliveCount;
			if (SpawnCount > FreeSpawnSlots)
			{
				`ZS_Info("Not enough free slots to spawn, will spawn" @ FreeSpawnSlots @ "instead of" @ SpawnCount);
				SpawnCount = FreeSpawnSlots;
			}
		}
		
		Spawned = SpawnZed(SE.ZedClass, SpawnCount, SE.SpawnAtPlayerStart);
		Message = "Spawned:" @ SE.ZedClass @ "x" $ Spawned;
	}
	else
	{
		Message = "Skip spawn" @ SE.ZedClass @ "due to probability:" @ SE.Probability * 100 $ "%";
		Spawned = SE.SingleSpawnLimit;
	}

	SpawnList[Index].SpawnsLeft -= Spawned;
	if (SpawnList[Index].SpawnsLeft > 0)
	{
		Message @= "(Next spawn after" @ SE.DelayDefault $ "sec," @ "spawns left:" @ SpawnList[Index].SpawnsLeft $ ")";
	}
	`ZS_Info(Message);
}

private function int PlayerCount()
{
	local PlayerController PC;
	local int HumanPlayers;
	local KFOnlineGameSettings KFGameSettings;
	
	`ZS_Trace(`Location);
	
	if (KFGIS.PlayfabInter != None && KFGIS.PlayfabInter.GetGameSettings() != None)
	{
		KFGameSettings = KFOnlineGameSettings(KFGIS.PlayfabInter.GetGameSettings());
		HumanPlayers = KFGameSettings.NumPublicConnections - KFGameSettings.NumOpenPublicConnections;
	}
	else
	{
		HumanPlayers = 0;
		foreach WorldInfo.AllControllers(class'PlayerController', PC)
			if (PC.bIsPlayer
			&&  PC.PlayerReplicationInfo != None
			&& !PC.PlayerReplicationInfo.bOnlySpectator
			&& !PC.PlayerReplicationInfo.bBot)
				HumanPlayers++;
	}

	return HumanPlayers;
}

private function Vector PlayerStartLocation()
{
	local PlayerController PC;
	
	`ZS_Trace(`Location);
	
	foreach WorldInfo.AllControllers(class'PlayerController', PC)
		return KFGIS.FindPlayerStart(PC, 0).Location;
	
	return KFGIS.FindPlayerStart(None, 0).Location;
}

private function int SpawnZed(class<KFPawn_Monster> ZedClass, int SpawnCount, bool SpawnAtPlayerStart)
{
	local Array<class<KFPawn_Monster> > CustomSquad;
	local Vector SpawnLocation;
	local KFPawn_Monster KFPM;
	local Controller C;
	local int SpawnFailed;
	local int Index;
	
	`ZS_Trace(`Location);
	
	for (Index = 0; Index < SpawnCount; Index++)
		CustomSquad.AddItem(ZedClass);
					
	if (SpawnAtPlayerStart)
	{
		SpawnLocation = PlayerStartLocation();
		SpawnLocation.Y += 64;
		SpawnLocation.Z += 64;
	}
	else
	{
		SpawnLocation = KFGIS.SpawnManager.GetBestSpawnVolume(CustomSquad).Location;
		SpawnLocation.Z += 10;
	}
	
	SpawnFailed = 0;
	for (Index = 0; Index < SpawnCount; Index++)
	{
		KFPM = Spawn(ZedClass,,, SpawnLocation, rot(0,0,1),, true);
		if (KFPM == None)
		{
			`ZS_Error("Can't spawn" @ ZedClass);
			SpawnFailed++;
			continue;
		}
		
		C = KFPM.Spawn(KFPM.ControllerClass);
		if (C == None)
		{
			`ZS_Error("Can't spawn controller for" @ ZedClass $ ". Destroy this KFPawn...");
			KFPM.Destroy();
			SpawnFailed++;
			continue;
		}
		C.Possess(KFPM, false);
	}

	if (CfgSpawn.default.bShadowSpawn && !KFGIS.MyKFGRI.IsBossWave())
	{
		KFGIS.MyKFGRI.AIRemaining -= (SpawnCount - SpawnFailed);
	}
	
	KFGIS.RefreshMonsterAliveCount();

	return SpawnCount - SpawnFailed;
}

public function NotifyLogin(Controller C)
{
	local ZedSpawnerRepLink RepLink;
	
	`ZS_Trace(`Location);
	
	RepLink = Spawn(class'ZedSpawnerRepLink', C);
	RepLink.LogLevel = LogLevel;
	RepLink.CustomZeds = CustomZeds;
	RepLink.ServerSync();
}

public function NotifyLogout(Controller C)
{
	`ZS_Trace(`Location);
	
	return;
}

DefaultProperties
{

}