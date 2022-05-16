class ZedSpawner extends Info
	config(ZedSpawner);

const dt = 1;

const CfgSpawn        = class'Spawn';
const CfgSpawnListR   = class'SpawnListRegular';
const CfgSpawnListBW  = class'SpawnListBossWaves';
const CfgSpawnListSW  = class'SpawnListSpecialWaves';

enum E_LogLevel
{
	LL_WrongLevel,
	LL_Fatal,
	LL_Error,
	LL_Warning,
	LL_Info,
	LL_Debug,
	LL_Trace,
	LL_All
};

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

public function bool WaveConditionRegular(S_SpawnEntry SE)
{
	`ZS_Trace(`Location, LogLevel);
	
	return (SE.Wave == KFGIS.WaveNum - CycleWaveSize * (CurrentCycle - 1));
}

public function bool WaveConditionBoss(S_SpawnEntry SE)
{
	local KFPawn_Monster KFPM;
	local int Index;
	
	`ZS_Trace(`Location, LogLevel);
	
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
	`ZS_Trace(`Location, LogLevel);
	
	return (SE.Wave == SpecialWave);
}

event PostBeginPlay()
{
	`ZS_Trace(`Location, LogLevel);
	
	Super.PostBeginPlay();
	
	if (WorldInfo.NetMode == NM_Client)
	{
		Destroy();
		return;
	}
	
	Init();
}

private function Init()
{
	local S_SpawnEntry SE;
	
	`ZS_Trace(`Location, LogLevel);
	
	if (!bConfigInitialized)
	{
		bConfigInitialized = true;
		LogLevel = LL_Info;
		SaveConfig();
		CfgSpawn.static.InitConfig();
		CfgSpawnListR.static.InitConfig();
		CfgSpawnListBW.static.InitConfig();
		CfgSpawnListSW.static.InitConfig();
		`ZS_Info("Config initialized.", LogLevel);
	}

	if (LogLevel == LL_WrongLevel)
	{
		LogLevel = LL_Info;
		`ZS_Warn("Wrong 'LogLevel', return to default value", LogLevel);
		SaveConfig();
	}
	
	`ZS_Log("LogLevel:" @ LogLevel);
	
	if (!CfgSpawn.static.Load(LogLevel))
	{
		`ZS_Fatal("Wrong settings, Destroy...", LogLevel);
		Destroy();
		return;
	}

	CurrentWave = INDEX_NONE;
	KFGIS = KFGameInfo_Survival(WorldInfo.Game);
	if (KFGIS == None)
	{
		`ZS_Fatal("Incompatible gamemode:" @ WorldInfo.Game $ ". Destroy...", LogLevel);
		Destroy();
		return;
	}
	
	KFGIA = new(KFGIS) class'KFGI_Access';
	
	KFGIE = KFGameInfo_Endless(KFGIS);
	
	SpawnListR  = CfgSpawnListR.static.Load(LogLevel);
	SpawnListBW = CfgSpawnListBW.static.Load(LogLevel);
	SpawnListSW = CfgSpawnListSW.static.Load(KFGIE, LogLevel);
	
	SpecialWave = INDEX_NONE;
	CurrentCycle = 1;
	CycleWaveSize = 0;
	CycleWaveShift = MaxInt;
	foreach SpawnListR(SE)
	{
		if (CustomZeds.Find(SE.ZedClass) == INDEX_NONE
		&&  KFGIA.IsCustomZed(SE.ZedClass))
		{
			`ZS_Debug("Add custom zed:" @ SE.ZedClass, LogLevel);
			CustomZeds.AddItem(SE.ZedClass);
			SE.ZedClass.static.PreloadContent();
		}
		
		CycleWaveShift = Min(CycleWaveShift, SE.Wave);
		CycleWaveSize  = Max(CycleWaveSize, SE.Wave);
	}
	CycleWaveSize = CycleWaveSize - CycleWaveShift + 1;
	
	foreach SpawnListBW(SE)
	{
		if (CustomZeds.Find(SE.ZedClass) == INDEX_NONE
		&&  KFGIA.IsCustomZed(SE.ZedClass))
		{
			`ZS_Debug("Add custom zed:" @ SE.ZedClass, LogLevel);
			CustomZeds.AddItem(SE.ZedClass);
			SE.ZedClass.static.PreloadContent();
		}
		
		if (BossClassCache.Find(SE.BossClass) == INDEX_NONE)
			BossClassCache.AddItem(SE.BossClass);
	}
	
	foreach SpawnListSW(SE)
	{
		if (CustomZeds.Find(SE.ZedClass) == INDEX_NONE
		&&  KFGIA.IsCustomZed(SE.ZedClass))
		{
			`ZS_Debug("Add custom zed:" @ SE.ZedClass, LogLevel);
			CustomZeds.AddItem(SE.ZedClass);
			SE.ZedClass.static.PreloadContent();
		}
	}
	
	SetTimer(float(dt), true, nameof(SpawnTimer));
}

private function SpawnTimer()
{
	`ZS_Trace(`Location, LogLevel);
	
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
	
	`ZS_Trace(`Location, LogLevel);
	
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
			`ZS_Info("increase WaveTotalAI from" @ WaveTotalAIDef @ "to" @ WaveTotalAI @ "due to ZedTotalMultiplier" @ "(" $ CfgSpawn.default.ZedTotalMultiplier $ ")", LogLevel);
		}
	}
	
	if (CfgSpawn.default.bCyclicalSpawn && KFGIS.WaveNum > 1 && KFGIS.WaveNum == CycleWaveShift + CycleWaveSize * CurrentCycle)
	{
		CurrentCycle++;
		`ZS_Info("Next spawn cycle started:" @ CurrentCycle, LogLevel);
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
	
	`ZS_Trace(`Location, LogLevel);
	
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
		
		`ZS_Debug(SE.ZedClass @ "SpawnsTotal:" @ List[Index].SpawnsTotal @ "SingleSpawnLimit:" @ List[Index].SingleSpawnLimit, LogLevel);
	}
}

private function SpawnTimerLogger(bool Stop, optional String Reason)
{
	local String Message;
	
	`ZS_Trace(`Location, LogLevel);
	
	if (Stop)
		Message = "Stop spawn";
	else
		Message = "Start spawn";
	
	if (Reason != "")
		Message @= "(" $ Reason $ ")";
	
	if (Message != SpawnTimerLastMessage)
	{
		`ZS_Info(Message, LogLevel);
		SpawnTimerLastMessage = Message;
	}
}

private function SpawnZeds(out Array<S_SpawnEntry> SpawnList, delegate<WaveCondition> Condition)
{
	local S_SpawnEntry SE;
	local int Index;
	
	`ZS_Trace(`Location, LogLevel);

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
	`ZS_Trace(`Location, LogLevel);
	
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
	`ZS_Trace(`Location, LogLevel);
	
	return SE.Delay <= 0 && SE.SpawnsLeft > 0;
}

private function SpawnEntry(out Array<S_SpawnEntry> SpawnList, int Index)
{
	local S_SpawnEntry SE;
	local int FreeSpawnSlots, SpawnCount, Spawned;
	local String Message;
	
	`ZS_Trace(`Location, LogLevel);
	
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
				`ZS_Info("Not enough free slots to spawn, will spawn" @ FreeSpawnSlots @ "instead of" @ SpawnCount, LogLevel);
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
	`ZS_Info(Message, LogLevel);
}

private function int PlayerCount()
{
	local PlayerController PC;
	local int HumanPlayers;
	local KFOnlineGameSettings KFGameSettings;
	
	`ZS_Trace(`Location, LogLevel);
	
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
	
	`ZS_Trace(`Location, LogLevel);
	
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
	
	`ZS_Trace(`Location, LogLevel);
	
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
			`ZS_Error("Can't spawn" @ ZedClass, LogLevel);
			SpawnFailed++;
			continue;
		}
		
		C = KFPM.Spawn(KFPM.ControllerClass);
		if (C == None)
		{
			`ZS_Error("Can't spawn controller for" @ ZedClass $ ". Destroy this KFPawn...", LogLevel);
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
	
	`ZS_Trace(`Location, LogLevel);
	
	RepLink = Spawn(class'ZedSpawnerRepLink', C);
	RepLink.LogLevel = LogLevel;
	RepLink.CustomZeds = CustomZeds;
	RepLink.ServerSync();
}

public function NotifyLogout(Controller C)
{
	`ZS_Trace(`Location, LogLevel);
	
	return;
}

DefaultProperties
{

}