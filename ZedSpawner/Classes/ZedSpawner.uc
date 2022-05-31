class ZedSpawner extends Info
	config(ZedSpawner);

const LatestVersion = 1;

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
	var byte  Wave;
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

var private config int        Version;
var private config E_LogLevel LogLevel;

var private Array<S_SpawnEntry> SpawnListR;
var private Array<S_SpawnEntry> SpawnListBW;
var private Array<S_SpawnEntry> SpawnListSW;

var private bool NoFreeSpawnSlots;
var private bool UseRegularSpawnList;
var private bool UseBossSpawnList;
var private bool UseSpecialSpawnList;

var private KFGameInfo_Survival KFGIS;
var private KFGameInfo_Endless  KFGIE;
var private KFGI_Access         KFGIA;

var private int CurrentWave;
var private int SpecialWave;
var private int CurrentCycle;
var private int CycleWaveShift;
var private int CycleWaveSize;
var private int WaveTotalAI;

var private class<KFPawn_Monster>         CurrentBossClass;
var private Array<class<KFPawn_Monster> > BossClassCache;
var private Array<class<KFPawn_Monster> > CustomZeds;

var private String SpawnTimerLastMessage;
var private String SpawnListsComment;

delegate bool WaveCondition(S_SpawnEntry SE);

public event PreBeginPlay()
{
	`ZS_Trace(`Location);
	
	if (WorldInfo.NetMode == NM_Client)
	{
		`ZS_Fatal("NetMode == NM_Client, Destroy...");
		Destroy();
		return;
	}
	
	Super.PreBeginPlay();
}

public event PostBeginPlay()
{
	`ZS_Trace(`Location);
	
	if (bPendingDelete) return;
	
	Super.PostBeginPlay();
	
	Init();
}

private function InitConfig()
{
	if (Version == `NO_CONFIG)
	{
		LogLevel = LL_Info;
		SaveConfig();
	}
	
	CfgSpawn.static.InitConfig(Version, LatestVersion);
	CfgSpawnListR.static.InitConfig(Version, LatestVersion, KFGIA);
	CfgSpawnListBW.static.InitConfig(Version, LatestVersion, KFGIA);
	CfgSpawnListSW.static.InitConfig(Version, LatestVersion);
	
	switch (Version)
	{
		case `NO_CONFIG:
			`ZS_Info("Config created");

		case MaxInt:
			`ZS_Info("Config updated to version"@LatestVersion);
			break;
			
		case LatestVersion:
			`ZS_Info("Config is up-to-date");
			break;
			
		default:
			`ZS_Warn("The config version is higher than the current version (are you using an old mutator?)");
			`ZS_Warn("Config version is" @ Version @ "but current version is" @ LatestVersion);
			`ZS_Warn("The config version will be changed to" @ LatestVersion);
			break;
	}

	if (LatestVersion != Version)
	{
		Version = LatestVersion;
		SaveConfig();
	}
}

private function Init()
{
	local S_SpawnEntry SE;
	
	`ZS_Trace(`Location);
	
	KFGIS = KFGameInfo_Survival(WorldInfo.Game);
	if (KFGIS == None)
	{
		`ZS_Fatal("Incompatible gamemode:" @ WorldInfo.Game $ ". Destroy...");
		Destroy();
		return;
	}
	
	KFGIA = new(KFGIS) class'KFGI_Access';
	KFGIE = KFGameInfo_Endless(KFGIS);
	
	InitConfig();

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

	SpawnListR  = CfgSpawnListR.static.Load(LogLevel);
	SpawnListBW = CfgSpawnListBW.static.Load(LogLevel);
	SpawnListSW = CfgSpawnListSW.static.Load(KFGIE, LogLevel);
	
	CurrentWave = INDEX_NONE;
	SpecialWave = INDEX_NONE;
	CurrentCycle = 1;
	
	if (CfgSpawn.default.bCyclicalSpawn)
	{
		CycleWaveSize = 0;
		CycleWaveShift = MaxInt;
		foreach SpawnListR(SE)
		{
			CycleWaveShift = Min(CycleWaveShift, SE.Wave);
			CycleWaveSize  = Max(CycleWaveSize, SE.Wave);
		}
		CycleWaveSize = CycleWaveSize - CycleWaveShift + 1;
	}
	
	CreateBossCache();
	PreloadContent();
	
	SetTimer(float(dt), true, nameof(SpawnTimer));
}

private function CreateBossCache()
{
	local S_SpawnEntry SE;
	
	foreach SpawnListBW(SE)
		if (BossClassCache.Find(SE.BossClass) == INDEX_NONE)
			BossClassCache.AddItem(SE.BossClass);
}

private function PreloadContent()
{
	local class<KFPawn_Monster> PawnClass;
	
	ExtractCustomZedsFromSpawnList(SpawnListR,  CustomZeds);
	ExtractCustomZedsFromSpawnList(SpawnListBW, CustomZeds);
	ExtractCustomZedsFromSpawnList(SpawnListSW, CustomZeds);
	
	foreach CustomZeds(PawnClass)
	{
		`ZS_Info("Preload content:" @ PawnClass);
		PawnClass.static.PreloadContent();
	}
}

private function ExtractCustomZedsFromSpawnList(Array<S_SpawnEntry> SpawnList, out Array<class<KFPawn_Monster> > Out)
{
	local S_SpawnEntry SE;
	
	foreach SpawnList(SE)
	{
		if (Out.Find(SE.ZedClass) == INDEX_NONE
		&&  KFGIA.IsCustomZed(SE.ZedClass))
		{
			Out.AddItem(SE.ZedClass);
		}
	}
}

public function bool WaveConditionRegular(S_SpawnEntry SE)
{
	`ZS_Trace(`Location);
	
	return (SE.Wave == KFGIS.WaveNum - CycleWaveSize * (CurrentCycle - 1));
}

public function bool WaveConditionBoss(S_SpawnEntry SE)
{
	`ZS_Trace(`Location);
	
	if (CurrentBossClass == None)
		return false;
	else
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
	
	if (!KFGIS.MyKFGRI.IsBossWave() && CfgSpawn.default.bShadowSpawn)
	{
		if (NoFreeSpawnSlots || KFGIS.MyKFGRI.AIRemaining <= KFGIS.AIAliveCount)
		{
			NoFreeSpawnSlots = true;
			SpawnTimerLogger(true, "no free spawn slots");
			return;
		}
	}
	
	SpawnTimerLogger(false, SpawnListsComment);

	if (UseRegularSpawnList) SpawnZeds(SpawnListR,  WaveConditionRegular);
	if (UseSpecialSpawnList) SpawnZeds(SpawnListSW, WaveConditionSpecial);
	if (UseBossSpawnList)    SpawnZeds(SpawnListBW, WaveConditionBoss);
}

private function SetupWave()
{
	local Array<String> SpawnListNames;
	local int           WaveTotalAIDef;
	local String        WaveTypeInfo;
	
	`ZS_Trace(`Location);
	
	if (CfgSpawn.default.bCyclicalSpawn && KFGIS.WaveNum > 1 && KFGIS.WaveNum == CycleWaveShift + CycleWaveSize * CurrentCycle)
	{
		CurrentCycle++;
		`ZS_Info("Spawn cycle started:" @ CurrentCycle);
	}
	
	CurrentWave = KFGIS.WaveNum;
	
	if (KFGIE != None)
	{
		SpecialWave = KFGameReplicationInfo_Endless(KFGIE.GameReplicationInfo).CurrentSpecialMode;
		if (SpecialWave != INDEX_NONE)
		{
			WaveTypeInfo = "Special:" @ EAIType(SpecialWave);
		}
	}
	
	if (KFGIS.MyKFGRI.IsBossWave())
	{
		CurrentBossClass = KFGIA.BossAITypePawn(EBossAIType(KFGIS.MyKFGRI.BossIndex));
		if (CurrentBossClass == None)
		{
			`ZS_Error("Can't determine boss class:" @ CurrentBossClass);
		}
		else
		{
			WaveTypeInfo = "Boss:" @ CurrentBossClass;
		}
	}
	else
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
		
		CurrentBossClass = None;
	}
	
	ResetSpawnList(SpawnListR);
	ResetSpawnList(SpawnListSW);
	ResetSpawnList(SpawnListBW);
	
	NoFreeSpawnSlots    = false;
	UseBossSpawnList    = KFGIS.MyKFGRI.IsBossWave();
	UseSpecialSpawnList = (SpecialWave != INDEX_NONE);
	UseRegularSpawnList = ((!UseSpecialSpawnList && !UseBossSpawnList)
	|| (UseSpecialSpawnList && !CfgSpawnListSW.default.bStopRegularSpawn)
	|| (UseBossSpawnList && !CfgSpawnListBW.default.bStopRegularSpawn));
	
	if (UseRegularSpawnList) SpawnListNames.AddItem("regular");
	if (UseSpecialSpawnList) SpawnListNames.AddItem("special");
	if (UseBossSpawnList)    SpawnListNames.AddItem("boss");
	JoinArray(SpawnListNames, SpawnListsComment, ", ");
	
	if (WaveTypeInfo != "")
	{
		WaveTypeInfo = "(" $ WaveTypeInfo $ ")";
	}
	
	`ZS_Info("Wave" @ CurrentWave @ WaveTypeInfo);
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
	}
}

private function SpawnTimerLogger(bool Stop, optional String Comment)
{
	local String Message;
	
	`ZS_Trace(`Location);
	
	if (Stop)
		Message = "Stop spawn";
	else
		Message = "Start spawn";
	
	if (Comment != "")
		Message @= "(" $ Comment $ ")";
	
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
			if (!ReadyToStart(SE))
			{
				continue;
			}
			
			if (SE.Delay > 0)
			{
				SpawnList[Index].Delay -= dt;
				continue;
			}
			
			if (SE.SpawnsLeft > 0)
			{
				SpawnEntry(SpawnList, Index);
			}
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
			if (FreeSpawnSlots == 0)
			{
				NoFreeSpawnSlots = true;
				SpawnList[Index].SpawnsLeft = 0;
				return;
			}
			else if (SpawnCount > FreeSpawnSlots)
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
	local int SpawnFailed, Spawned;
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
	
	Spawned = (SpawnCount - SpawnFailed);

	if (CfgSpawn.default.bShadowSpawn && !KFGIS.MyKFGRI.IsBossWave())
	{
		KFGIS.NumAIFinishedSpawning += Spawned;
		KFGIS.NumAISpawnsQueued += Spawned;
	}
	
	KFGIS.UpdateAIRemaining();
	
	return Spawned;
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