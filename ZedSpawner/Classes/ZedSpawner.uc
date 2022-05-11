class ZedSpawner extends Info
	config(ZedSpawner);

var const int dt;

var const class<Spawn>                 CfgSpawn;
var const class<SpawnList>             CfgSpawnList;
var const class<SpawnListBossWaves>    CfgSpawnListBW;
var const class<SpawnListSpecialWaves> CfgSpawnListSW;

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
	var int   SpawnAtOnce;
	var float Probability;
	var float RelativeDelayDefault;
	var float RelativeDelay;
	var int   DelayDefault;
	var int   Delay;
	var int   SpawnsDone;
	var int   MaxSpawns;
	var bool  SpawnAtPlayerStart;
};

var config bool       bConfigInitialized;
var config E_LogLevel LogLevel;

var private Array<S_SpawnEntry> SpawnList;
var private Array<S_SpawnEntry> SpawnListBW;
var private Array<S_SpawnEntry> SpawnListSW;

var private KFGameInfo_Survival KFGIS;
var private KFGameInfo_Endless  KFGIE;

var private int CurrentWave;
var private int CurrentCycle;
var private int CycleWaveShift;
var private int CycleWaveSize;

var private int WaveTotalAI;
var private class<KFPawn_Monster> CurrentBossClass;

var private String SpawnTimerLastMessage;

var private Array<class<KFPawn_Monster> > BossClassCache;

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
	local S_SpawnEntry SpawnEntry;
	
	`ZS_Trace(`Location, LogLevel);
	
	if (!bConfigInitialized)
	{
		bConfigInitialized = true;
		LogLevel = LL_Info;
		SaveConfig();
		CfgSpawn.static.InitConfig();
		CfgSpawnList.static.InitConfig();
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
	
	KFGIE = KFGameInfo_Endless(KFGIS);
	
	SpawnList = CfgSpawnList.static.Load(LogLevel);
	SpawnListBW = CfgSpawnListBW.static.Load(LogLevel);
	SpawnListSW = CfgSpawnListSW.static.Load(KFGIE, LogLevel);
	
	foreach SpawnListBW(SpawnEntry)
		BossClassCache.AddItem(SpawnEntry.BossClass);
	
	CurrentCycle = 1;
	CycleWaveSize = 0;
	CycleWaveShift = MaxInt;
	foreach SpawnList(SpawnEntry)
	{
		CycleWaveShift = Min(CycleWaveShift, SpawnEntry.Wave);
		CycleWaveSize  = Max(CycleWaveSize, SpawnEntry.Wave);
	}
	CycleWaveSize = CycleWaveSize - CycleWaveShift + 1;

	SetTimer(float(dt), true, nameof(SpawnTimer));
}

private function SpawnTimer()
{
	local int WaveTotalAIDef;
	local int SpecialWave;

	`ZS_Trace(`Location, LogLevel);
	
	if (CurrentWave < KFGIS.WaveNum)
	{
		CurrentWave = KFGIS.WaveNum;
		
		if (!KFGIS.MyKFGRI.IsBossWave())
		{
			WaveTotalAIDef = KFGIS.SpawnManager.WaveTotalAI;
			KFGIS.SpawnManager.WaveTotalAI *= CfgSpawn.default.ZedMultiplier;
			WaveTotalAI = KFGIS.SpawnManager.WaveTotalAI;
			KFGIS.MyKFGRI.WaveTotalAICount = KFGIS.SpawnManager.WaveTotalAI;
			KFGIS.MyKFGRI.AIRemaining = KFGIS.SpawnManager.WaveTotalAI; 
			
			if (WaveTotalAIDef != KFGIS.SpawnManager.WaveTotalAI)
			{
				`ZS_Info("increase WaveTotalAI from" @ WaveTotalAIDef @ "to" @ WaveTotalAI @ "due to ZedMultiplier" @ "(" $ CfgSpawn.default.ZedMultiplier $ ")", LogLevel);
			}
		}
		
		if (CfgSpawn.default.bCyclicalSpawn && KFGIS.WaveNum > 1 && KFGIS.WaveNum == CycleWaveShift + CycleWaveSize * CurrentCycle)
		{
			CurrentCycle++;
			`ZS_Info("Next spawn cycle started:" @ CurrentCycle, LogLevel);
		}
		
		ResetSpawnList(SpawnList);
		ResetSpawnList(SpawnListSW);
		ResetSpawnList(SpawnListBW);
		
		CurrentBossClass = None;
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

	SpecialWave = INDEX_NONE;
	if (KFGIE != None)
	{
		SpecialWave = KFGameReplicationInfo_Endless(KFGIE.GameReplicationInfo).CurrentSpecialMode;
	}

	if ((SpecialWave == INDEX_NONE && !KFGIS.MyKFGRI.IsBossWave())
	|| (SpecialWave  != INDEX_NONE && !CfgSpawnListSW.default.bStopRegularSpawn)
	|| (KFGIS.MyKFGRI.IsBossWave() && !CfgSpawnListBW.default.bStopRegularSpawn))
		SpawnRegularWaveZeds();
	
	if (SpecialWave != INDEX_NONE)
		SpawnSpecialWaveZeds(SpecialWave);
	
	if (KFGIS.MyKFGRI.IsBossWave())
		SpawnBossWaveZeds();
}

private function ResetSpawnList(out Array<S_SpawnEntry> List)
{
	local S_SpawnEntry SpawnEntry;
	local int i;
	
	`ZS_Trace(`Location, LogLevel);
	
	foreach List(SpawnEntry, i)
	{
		List[i].SpawnsDone = 0;
		
		if (KFGIS.MyKFGRI.IsBossWave())
		{
			List[i].RelativeDelay = 0.f;
			List[i].Delay = SpawnEntry.DelayDefault;
		}
		else
		{
			List[i].RelativeDelay = SpawnEntry.RelativeDelayDefault;
			if (SpawnEntry.RelativeDelay == 0.f)
				List[i].Delay = SpawnEntry.DelayDefault;
			else
				List[i].Delay = 0;
		}
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

private function SpawnRegularWaveZeds()
{
	local S_SpawnEntry SpawnEntry;
	local int Spawned, SpawnsLeft, i;
	local String Message;
	
	`ZS_Trace(`Location, LogLevel);

	foreach SpawnList(SpawnEntry, i)
	{
		if (SpawnEntry.Wave == KFGIS.WaveNum - CycleWaveSize * (CurrentCycle - 1))
		{
			SpawnList[i].Delay -= dt;
			if (TimeToSpawn(SpawnEntry))
			{
				SpawnList[i].Delay = SpawnEntry.DelayDefault;
				if (FRand() <= SpawnEntry.Probability)
				{
					Spawned = SpawnZed(SpawnEntry.ZedClass, SpawnEntry.SpawnAtOnce, SpawnEntry.SpawnAtPlayerStart);
					Message = "Spawned:" @ SpawnEntry.ZedClass @ "x" $ Spawned;
				}
				else
				{
					Message = "Skip spawn" @ SpawnEntry.ZedClass @ "due to probability:" @ SpawnEntry.Probability * 100 $ "%";
				}
				
				SpawnList[i].SpawnsDone++;
				SpawnsLeft = SpawnEntry.MaxSpawns - SpawnList[i].SpawnsDone;
				if (SpawnsLeft > 0)
				{
					Message @= "(Next spawn after" @ SpawnEntry.DelayDefault $ "sec," @ "spawns left:" @ SpawnsLeft $ ")";
				}
				`ZS_Info(Message, LogLevel);
			}
		}
	}
}

private function SpawnSpecialWaveZeds(int SpecialWave)
{
	local S_SpawnEntry SpawnEntry;
	local int Spawned, SpawnsLeft, i;
	local String Message;

	`ZS_Trace(`Location, LogLevel);

	foreach SpawnListSW(SpawnEntry, i)
	{
		if (SpawnEntry.Wave == SpecialWave)
		{
			SpawnListSW[i].Delay -= dt;

			if (TimeToSpawn(SpawnEntry))
			{
				SpawnListSW[i].Delay = SpawnEntry.DelayDefault;
				if (FRand() <= SpawnEntry.Probability)
				{
					Spawned = SpawnZed(SpawnEntry.ZedClass, SpawnEntry.SpawnAtOnce, SpawnEntry.SpawnAtPlayerStart);
					Message = "Spawned:" @ SpawnEntry.ZedClass @ "x" $ Spawned;
				}
				else
				{
					Message = "Skip spawn" @ SpawnEntry.ZedClass @ "due to probability:" @ SpawnEntry.Probability * 100 $ "%";
				}
				
				SpawnListSW[i].SpawnsDone++;
				SpawnsLeft = SpawnEntry.MaxSpawns - SpawnListSW[i].SpawnsDone;
				if (SpawnsLeft > 0)
				{
					Message @= "(Next spawn after" @ SpawnEntry.DelayDefault $ "sec," @ "spawns left:" @ SpawnsLeft $ ")";
				}
				`ZS_Info(Message, LogLevel);
			}
		}
	}
}

private function SpawnBossWaveZeds()
{
	local S_SpawnEntry SpawnEntry;
	local KFPawn_Monster KFPM;
	local int Spawned, SpawnsLeft, i;
	local String Message;

	`ZS_Trace(`Location, LogLevel);

	if (CurrentBossClass == None)
	{
		foreach WorldInfo.AllPawns(class'KFPawn_Monster', KFPM)
		{
			i = BossClassCache.Find(KFPM.class);
			if (i != INDEX_NONE)
			{
				CurrentBossClass = BossClassCache[i];
				break;
			}
		}
	}
	
	if (CurrentBossClass == None)
	{
		return;
	}

	foreach SpawnListBW(SpawnEntry, i)
	{
		if (SpawnEntry.BossClass == CurrentBossClass)
		{
			SpawnListBW[i].Delay -= dt;
			if (TimeToSpawn(SpawnEntry))
			{
				SpawnListBW[i].Delay = SpawnEntry.DelayDefault;
				if (FRand() <= SpawnEntry.Probability)
				{
					Spawned = SpawnZed(SpawnEntry.ZedClass, SpawnEntry.SpawnAtOnce, SpawnEntry.SpawnAtPlayerStart);
					Message = "Spawned:" @ SpawnEntry.ZedClass @ "x" $ Spawned;
				}
				else
				{
					Message = "Skip spawn" @ SpawnEntry.ZedClass @ "due to probability:" @ SpawnEntry.Probability * 100 $ "%";
				}
				
				SpawnListBW[i].SpawnsDone++;
				SpawnsLeft = SpawnEntry.MaxSpawns - SpawnListBW[i].SpawnsDone;
				if (SpawnsLeft > 0)
				{
					Message @= "(Next spawn after" @ SpawnEntry.DelayDefault $ "sec," @ "spawns left:" @ SpawnsLeft $ ")";
				}
				`ZS_Info(Message, LogLevel);
			}
		}
	}
}

private function bool TimeToSpawn(S_SpawnEntry SpawnEntry)
{
	local bool DelayReady, DelayRelativeReady;
	
	`ZS_Trace(`Location, LogLevel);
	
	DelayReady = SpawnEntry.Delay <= 0 && SpawnEntry.MaxSpawns >= 0 && SpawnEntry.SpawnsDone < SpawnEntry.MaxSpawns;
	
	if (SpawnEntry.RelativeDelay == 0.f)
	{
		DelayRelativeReady = true;
	}
	else
	{
		DelayRelativeReady = (SpawnEntry.RelativeDelay <= 1.0f - (float(KFGIS.MyKFGRI.AIRemaining) / float(WaveTotalAI)));
	}

	return DelayReady && DelayRelativeReady;
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

private function int SpawnZed(class<KFPawn_Monster> ZedClass, int SpawnAtOnce, bool SpawnAtPlayerStart)
{
	local Array<class<KFPawn_Monster> > CustomSquad;
	local Vector SpawnLocation;
	local KFPawn_Monster KFPM;
	local Controller C;
	local int ModdedSpawnCount;
	local int FreeSpawnSlots;
	local int SpawnFailed;
	local int i;
	
	`ZS_Trace(`Location, LogLevel);
	
	ModdedSpawnCount = Round(float(SpawnAtOnce) * (1.0f + float(CurrentCycle - 1) * CfgSpawn.default.CycleMultiplier + float(PlayerCount() - 1) * CfgSpawn.default.PlayerMultiplier));
	
	if (CfgSpawn.default.bShadowSpawn && !KFGIS.MyKFGRI.IsBossWave())
	{
		FreeSpawnSlots = KFGIS.MyKFGRI.AIRemaining - KFGIS.AIAliveCount;
		if (ModdedSpawnCount > FreeSpawnSlots)
		{
			`ZS_Info("Not enough free slots to spawn, will spawn" @ FreeSpawnSlots @ "instead of" @ ModdedSpawnCount, LogLevel);
			ModdedSpawnCount = FreeSpawnSlots;
		}
	}
	
	for (i = 0; i < ModdedSpawnCount; i++)
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
	for (i = 0; i < ModdedSpawnCount; i++)
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
		KFGIS.MyKFGRI.AIRemaining -= (ModdedSpawnCount - SpawnFailed);
	}
	
	KFGIS.RefreshMonsterAliveCount();

	return ModdedSpawnCount - SpawnFailed;
}

private function PrintSpawnEntry(S_SpawnEntry SE)
{
	`ZS_Debug("BossClass:" @ SE.BossClass, LogLevel);
	`ZS_Debug("ZedClass:" @ SE.ZedClass, LogLevel);
	`ZS_Debug("Wave:" @ SE.Wave, LogLevel);
	`ZS_Debug("SpawnAtOnce:" @ SE.SpawnAtOnce, LogLevel);
	`ZS_Debug("Probability:" @ SE.Probability, LogLevel);
	`ZS_Debug("RelativeDelay:" @ SE.RelativeDelay @ "(" $ SE.RelativeDelayDefault $ ")", LogLevel);
	`ZS_Debug("Delay:" @ SE.Delay @ "(" $ SE.DelayDefault $ ")", LogLevel);
	`ZS_Debug("SpawnsDone:" @ SE.SpawnsDone @ "of" @ SE.MaxSpawns, LogLevel);
	`ZS_Debug("SpawnAtPlayerStart:" @ SE.SpawnAtPlayerStart, LogLevel);
	`ZS_Debug("---------------------", LogLevel);
}

DefaultProperties
{
	dt = 1
	
	CfgSpawn        = class'Spawn'
	CfgSpawnList    = class'SpawnList'
	CfgSpawnListBW  = class'SpawnListBossWaves'
	CfgSpawnListSW  = class'SpawnListSpecialWaves'
}