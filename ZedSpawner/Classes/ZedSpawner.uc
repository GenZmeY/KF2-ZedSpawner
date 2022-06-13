class ZedSpawner extends Info
	config(ZedSpawner);

const LatestVersion = 3;

const CfgSpawn              = class'Spawn';
const CfgSpawnAtPlayerStart = class'SpawnAtPlayerStart';
const CfgSpawnListRW        = class'SpawnListRegular';
const CfgSpawnListBW        = class'SpawnListBossWaves';
const CfgSpawnListSW        = class'SpawnListSpecialWaves';

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
	var byte   Wave;
	var int    SpawnCountBase;
	var int    SingleSpawnLimitDefault;
	var int    SingleSpawnLimit;
	var float  Probability;
	var float  RelativeStartDefault;
	var float  RelativeStart;
	var int    DelayDefault;
	var float  Delay;
	var int    PawnsLeft;
	var int    PawnsTotal;
	var bool   ForceSpawn;
	var String ZedNameFiller;
};

var private config int        Version;
var private config E_LogLevel LogLevel;
var private config float      Tickrate;

var private float dt;

var private Array<S_SpawnEntry> SpawnListRW;
var private Array<S_SpawnEntry> SpawnListBW;
var private Array<S_SpawnEntry> SpawnListSW;
var private Array<S_SpawnEntry> SpawnListCurrent;

var private bool NoFreeSpawnSlots;
var private bool UseRegularSpawnList;
var private bool UseBossSpawnList;
var private bool UseSpecialSpawnList;
var private bool GlobalSpawnAtPlayerStart;

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
var private Array<class<KFPawn_Monster> > CustomZeds;
var private Array<class<KFPawn_Monster> > SpawnAtPlayerStartZeds;

var private bool   SpawnActive;
var private String SpawnListsComment;

var private Array<ZedSpawnerRepLink> RepLinks;

public simulated function bool SafeDestroy()
{
	return (bPendingDelete || bDeleteMe || Destroy());
}

public event PreBeginPlay()
{
	`ZS_Trace(`Location);
	
	if (WorldInfo.NetMode == NM_Client)
	{
		`ZS_Fatal("NetMode == NM_Client, Destroy...");
		SafeDestroy();
		return;
	}
	
	Super.PreBeginPlay();
}

public event PostBeginPlay()
{
	`ZS_Trace(`Location);
	
	if (bPendingDelete || bDeleteMe) return;
	
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
	CfgSpawnAtPlayerStart.static.InitConfig(Version, LatestVersion);
	CfgSpawnListRW.static.InitConfig(Version, LatestVersion, KFGIA);
	CfgSpawnListBW.static.InitConfig(Version, LatestVersion, KFGIA);
	CfgSpawnListSW.static.InitConfig(Version, LatestVersion);
	
	switch (Version)
	{
		case `NO_CONFIG:
			`ZS_Info("Config created");
			
		case 1:
			Tickrate = 1.0f;
			
		case 2:

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
	local String CurrentMap;
	
	`ZS_Trace(`Location);
	
	KFGIS = KFGameInfo_Survival(WorldInfo.Game);
	if (KFGIS == None)
	{
		`ZS_Fatal("Incompatible gamemode:" @ WorldInfo.Game $ ". Destroy...");
		SafeDestroy();
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
	
	if (Tickrate <= 0)
	{
		`ZS_Error("Spawner tickrate must be positive (current value:" @ Tickrate $ ")");
	}
	
	if (!CfgSpawn.static.Load(LogLevel) || Tickrate <= 0)
	{
		`ZS_Fatal("Wrong settings, Destroy...");
		SafeDestroy();
		return;
	}
	
	dt = 1 / Tickrate;
	`ZS_Info("Spawner tickrate:" @ Tickrate @ "(update every" @ dt $ "s)");

	SpawnListRW = CfgSpawnListRW.static.Load(LogLevel);
	SpawnListBW = CfgSpawnListBW.static.Load(LogLevel);
	SpawnListSW = CfgSpawnListSW.static.Load(KFGIE, LogLevel);
	SpawnAtPlayerStartZeds = CfgSpawnAtPlayerStart.static.Load(LogLevel);
	
	CurrentMap = String(WorldInfo.GetPackageName());
	GlobalSpawnAtPlayerStart = (CfgSpawnAtPlayerStart.default.Map.Find(CurrentMap) != INDEX_NONE);
	`ZS_Info("GlobalSpawnAtPlayerStart:" @ GlobalSpawnAtPlayerStart $ GlobalSpawnAtPlayerStart ? "(" $ CurrentMap $ ")" : "");
	
	CurrentWave = INDEX_NONE;
	SpecialWave = INDEX_NONE;
	CurrentCycle = 1;
	
	if (CfgSpawn.default.bCyclicalSpawn)
	{
		CycleWaveSize = 0;
		CycleWaveShift = MaxInt;
		foreach SpawnListRW(SE)
		{
			CycleWaveShift = Min(CycleWaveShift, SE.Wave);
			CycleWaveSize  = Max(CycleWaveSize, SE.Wave);
		}
		CycleWaveSize = CycleWaveSize - CycleWaveShift + 1;
	}
	
	PreloadContent();
	
	SetTimer(dt, true, nameof(SpawnTimer));
}

private function PreloadContent()
{
	local class<KFPawn_Monster> PawnClass;
	
	ExtractCustomZedsFromSpawnList(SpawnListRW, CustomZeds);
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

private function SpawnTimer()
{
	local S_SpawnEntry SE;
	local int          Index;
	local float        Threshold;
	
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
	
	if (SpawnListCurrent.Length == 0)
	{
		SpawnTimerLogger(true, "No spawn list for this wave");
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

	Threshold = 1.0f - (float(KFGIS.MyKFGRI.AIRemaining) / float(WaveTotalAI));
	foreach SpawnListCurrent(SE, Index)
	{
		if (NoFreeSpawnSlots)
		{
			break;
		}
		
		if (SE.RelativeStart != 0.0f && SE.RelativeStart > Threshold)
		{
			continue;
		}
		
		if (SE.Delay > 0.0f)
		{
			SpawnListCurrent[Index].Delay -= dt;
			continue;
		}
		
		if (SE.PawnsLeft > 0)
		{
			SpawnEntry(SpawnListCurrent, Index);
		}
	}
}

private function SetupWave()
{
	local Array<String> SpawnListNames;
	local int           WaveTotalAIDef;
	local byte          BaseWave;
	local String        WaveTypeInfo;
	local S_SpawnEntry  SE;
	local EAIType       SWType;
	
	`ZS_Trace(`Location);
	
	if (CfgSpawn.default.bCyclicalSpawn && KFGIS.WaveNum > 1 && KFGIS.WaveNum == CycleWaveShift + CycleWaveSize * CurrentCycle)
	{
		CurrentCycle++;
		`ZS_Info("Spawn cycle started:" @ CurrentCycle);
	}
	
	CurrentWave = KFGIS.WaveNum;
	
	if (KFGIE != None)
	{
		if (KFGameReplicationInfo_Endless(KFGIE.GameReplicationInfo).CurrentWeeklyMode != INDEX_NONE)
		{
			WaveTypeInfo = "Weekly:" @ KFGameReplicationInfo_Endless(KFGIE.GameReplicationInfo).CurrentWeeklyMode;
		}
		
		SpecialWave = KFGameReplicationInfo_Endless(KFGIE.GameReplicationInfo).CurrentSpecialMode;
		if (SpecialWave != INDEX_NONE)
		{
			SWType = EAIType(SpecialWave);
			WaveTypeInfo = "Special:" @ SWType;
		}
	}
	
	if (KFGIS.MyKFGRI.IsBossWave())
	{
		CurrentBossClass = KFGIA.BossAITypePawn(EBossAIType(KFGIS.MyKFGRI.BossIndex));
		if (CurrentBossClass == None)
		{
			`ZS_Error("Can't determine boss class. Boss index:" @ KFGIS.MyKFGRI.BossIndex);
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
	
	NoFreeSpawnSlots    = false;
	UseBossSpawnList    = KFGIS.MyKFGRI.IsBossWave();
	UseSpecialSpawnList = (SpecialWave != INDEX_NONE);
	UseRegularSpawnList = ((!UseSpecialSpawnList && !UseBossSpawnList)
	|| (UseSpecialSpawnList && !CfgSpawnListSW.default.bStopRegularSpawn)
	|| (UseBossSpawnList && !CfgSpawnListBW.default.bStopRegularSpawn));

	SpawnListCurrent.Length = 0;
	if (UseRegularSpawnList)
	{
		SpawnListNames.AddItem("regular");
		BaseWave = KFGIS.WaveNum - CycleWaveSize * (CurrentCycle - 1);
		foreach SpawnListRW(SE)
			if (SE.Wave == BaseWave)
				SpawnListCurrent.AddItem(SE);
			else if (SE.Wave > BaseWave)
				break;
	}
	
	if (UseSpecialSpawnList)
	{
		SpawnListNames.AddItem("special");
		foreach SpawnListSW(SE)
			if (SE.Wave == SpecialWave)
				SpawnListCurrent.AddItem(SE);
	}
	
	if (UseBossSpawnList)
	{
		SpawnListNames.AddItem("boss");
		foreach SpawnListBW(SE)
			if (SE.BossClass == CurrentBossClass)
				SpawnListCurrent.AddItem(SE);
	}
	
	JoinArray(SpawnListNames, SpawnListsComment, ", ");
	AdjustSpawnList(SpawnListCurrent);
	
	if (WaveTypeInfo != "")
	{
		WaveTypeInfo = "(" $ WaveTypeInfo $ ")";
	}
	
	`ZS_Info("Wave" @ CurrentWave @ WaveTypeInfo);
}

private function AdjustSpawnList(out Array<S_SpawnEntry> List)
{
	local S_SpawnEntry SE;
	local int Index;
	local float Cycle, Players;
	local float B, TM, TCM, TPM;
	local float L, LM, LCM, LPM;
	local float PawnTotalF, PawnLimitF;
	local int ZedNameMaxLength;
	
	`ZS_Trace(`Location);
	
	Cycle   = float(CurrentCycle);
	Players = float(PlayerCount());
	
	TM  = CfgSpawn.default.ZedTotalMultiplier;
	TCM = CfgSpawn.default.SpawnTotalCycleMultiplier;
	TPM = CfgSpawn.default.SpawnTotalPlayerMultiplier;
		
	LM  = CfgSpawn.default.SingleSpawnLimitMultiplier;
	LCM = CfgSpawn.default.SingleSpawnLimitCycleMultiplier;
	LPM = CfgSpawn.default.SingleSpawnLimitPlayerMultiplier;

	ZedNameMaxLength = 0;
	foreach List(SE, Index)
	{
		ZedNameMaxLength = Max(ZedNameMaxLength, Len(String(SE.ZedClass)));
		if (KFGIS.MyKFGRI.IsBossWave())
		{
			List[Index].RelativeStart = 0.f;
			List[Index].Delay = float(SE.DelayDefault);
		}
		else
		{
			List[Index].RelativeStart = SE.RelativeStartDefault;
			if (List[Index].RelativeStart == 0.f)
				List[Index].Delay = float(SE.DelayDefault);
			else
				List[Index].Delay = 0.0f;
		}
		
		B = float(SE.SpawnCountBase);
		L = float(SE.SingleSpawnLimitDefault);
	
		PawnTotalF = B * (TM + TCM * (Cycle - 1.0f) + TPM * (Players - 1.0f));
		PawnLimitF = L * (LM + LCM * (Cycle - 1.0f) + LPM * (Players - 1.0f));
		
		List[Index].ForceSpawn       = false;
		List[Index].PawnsTotal       = Max(Round(PawnTotalF), 1);
		List[Index].SingleSpawnLimit = Max(Round(PawnLimitF), 1);
		List[Index].PawnsLeft        = List[Index].PawnsTotal;
	}
	
	foreach List(SE, Index)
	{
		List[Index].ZedNameFiller = "";
		while (Len(String(SE.ZedClass)) + Len(List[Index].ZedNameFiller) < ZedNameMaxLength)
			List[Index].ZedNameFiller @= "";
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
	
	if (SpawnActive == Stop)
	{
		`ZS_Info(Message);
		SpawnActive = !Stop;
	}
}

private function SpawnEntry(out Array<S_SpawnEntry> SpawnList, int Index)
{
	local S_SpawnEntry SE;
	local int FreeSpawnSlots, PawnCount, Spawned;
	local String Action, Comment, NextSpawn;
	local bool SpawnAtPlayerStart;
	
	`ZS_Trace(`Location);
	
	SE = SpawnList[Index];
	
	SpawnList[Index].Delay = float(SE.DelayDefault);
	if (FRand() <= SE.Probability || SE.ForceSpawn)
	{
		if (SE.SingleSpawnLimit == 0 || SE.PawnsLeft < SE.SingleSpawnLimit)
		{
			PawnCount = SE.PawnsLeft;
		}
		else
		{
			PawnCount = SE.SingleSpawnLimit;
		}
		
		if (CfgSpawn.default.bShadowSpawn && !KFGIS.MyKFGRI.IsBossWave())
		{
			FreeSpawnSlots = KFGIS.MyKFGRI.AIRemaining - KFGIS.AIAliveCount;
			if (FreeSpawnSlots == 0)
			{
				NoFreeSpawnSlots = true;
				SpawnList[Index].PawnsLeft = 0;
				return;
			}
			else if (PawnCount > FreeSpawnSlots)
			{
				PawnCount = FreeSpawnSlots;
			}
		}
		
		SpawnAtPlayerStart = (GlobalSpawnAtPlayerStart || (SpawnAtPlayerStartZeds.Find(SE.ZedClass) != INDEX_NONE));
		
		Spawned = SpawnZed(SE.ZedClass, PawnCount, SpawnAtPlayerStart);
		if (Spawned == INDEX_NONE)
		{
			SpawnList[Index].Delay = 5.0f;
			SpawnList[Index].ForceSpawn = true;
			Action  = "Skip spawn";
			Comment = "no free spawn volume, try to spawn it again in" @ Round(SpawnList[Index].Delay) @ "seconds...";
			SpawnLog(SE, Action, Comment);
			return;
		}
		else if (Spawned == 0)
		{
			Action  = "Spawn failed";
		}
		else
		{
			SpawnList[Index].ForceSpawn = false;
			Action  = "Spawned";
			Comment = "x" $ Spawned;
		}
	}
	else
	{
		Action  = "Skip spawn";
		Comment = "due to" @ Round(SE.Probability * 100) $ "%" @ "probability";
		Spawned = SE.SingleSpawnLimit;
	}

	SpawnList[Index].PawnsLeft -= Spawned;
	if (SpawnList[Index].PawnsLeft > 0)
	{
		NextSpawn = "next after" @ SE.DelayDefault $ "sec," @ "pawns left:" @ SpawnList[Index].PawnsLeft;
	}
	SpawnLog(SE, Action, Comment, NextSpawn);
}

private function SpawnLog(S_SpawnEntry SE, String Action, optional String Comment, optional String NextSpawn)
{
	if (Comment   != "") Comment   = ":" @ Comment;
	if (NextSpawn != "") NextSpawn = "(" $ NextSpawn $ ")";
	
	`ZS_Info(String(SE.ZedClass) $ SE.ZedNameFiller @ ">" @ Action $ Comment @ NextSpawn);
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

private function int SpawnZed(class<KFPawn_Monster> ZedClass, int PawnCount, optional bool SpawnAtPlayerStart = false)
{
	local Array<class<KFPawn_Monster> > CustomSquad;
	local ESquadType PrevDesiredSquadType;
	local Vector SpawnLocation, PlayerStart;
	local KFSpawnVolume SpawnVolume;
	local KFPawn_Monster KFPM;
	local Controller C;
	local int Failed, Spawned;
	local int Index;
	
	`ZS_Trace(`Location);
	
	PlayerStart = PlayerStartLocation();
	if (SpawnAtPlayerStart)
	{
		SpawnLocation = PlayerStart;
		SpawnLocation.Y += 64;
		SpawnLocation.Z += 64;
	}
	else
	{
		for (Index = 0; Index < PawnCount; Index++)
		{
			CustomSquad.AddItem(ZedClass);
		}
		
		PrevDesiredSquadType = KFGIS.SpawnManager.DesiredSquadType;
		KFGIS.SpawnManager.SetDesiredSquadTypeForZedList(CustomSquad);
		SpawnVolume = KFGIS.SpawnManager.GetBestSpawnVolume(CustomSquad);
		KFGIS.SpawnManager.DesiredSquadType = PrevDesiredSquadType;

		if (SpawnVolume == None)
		{
			return INDEX_NONE;
		}
		
		SpawnVolume.VolumeChosenCount++;
		
		SpawnLocation = SpawnVolume.Location;
		if (SpawnLocation == PlayerStart)
		{
			return INDEX_NONE;
		}
		
		SpawnLocation.Z += 10;
	}

	Spawned = 0; Failed = 0;
	while (Failed + Spawned < PawnCount)
	{
		KFPM = Spawn(ZedClass,,, SpawnLocation, rot(0,0,1),, true);
		if (KFPM == None)
		{
			`ZS_Error("Can't spawn" @ ZedClass);
			Failed++;
			continue;
		}
		
		C = KFPM.Spawn(KFPM.ControllerClass);
		if (C == None)
		{
			`ZS_Error("Can't spawn controller for" @ ZedClass $ ". Destroy this" @ KFPM $ "...");
			KFPM.Destroy();
			Failed++;
			continue;
		}
		C.Possess(KFPM, false);
		Spawned++;
	}
	
	if (Spawned > 0)
	{
		KFGIS.SpawnManager.LastAISpawnVolume = SpawnVolume;
	}
	
	if (CfgSpawn.default.bShadowSpawn && !KFGIS.MyKFGRI.IsBossWave())
	{
		KFGIS.NumAIFinishedSpawning += Spawned;
		KFGIS.NumAISpawnsQueued     += Spawned;
	}
	
	KFGIS.UpdateAIRemaining();
	
	return Spawned;
}

public function NotifyLogin(Controller C)
{
	`ZS_Trace(`Location);

	CreateRepLink(C);
}

public function NotifyLogout(Controller C)
{
	`ZS_Trace(`Location);

	DestroyRepLink(C);
}

public function CreateRepLink(Controller C)
{
	local ZedSpawnerRepLink RepLink;
	
	`ZS_Trace(`Location);
	
	if (C == None) return;
	
	RepLink = Spawn(class'ZedSpawnerRepLink', C);
	RepLink.LogLevel = LogLevel;
	RepLink.CustomZeds = CustomZeds;
	RepLink.ZS = Self;
	
	RepLinks.AddItem(RepLink);
	
	RepLink.ServerSync();
}

public function bool DestroyRepLink(Controller C)
{
	local int i;
	
	`ZS_Trace(`Location);
	
	if (C == None) return false;
	
	for (i = RepLinks.Length - 1; i >= 0; --i)
	{
		if (RepLinks[i].Owner == C)
		{
			RepLinks[i].SafeDestroy();
			RepLinks.Remove(i, 1);
			return true;
		}
	}
	
	return false;
}

DefaultProperties
{

}