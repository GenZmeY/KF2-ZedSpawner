class Config_SpawnManager_WaveInfo extends Object
	abstract
	config(ZedSpawnManager);

var const class<KFAISpawnManager> DefSpawnManager;
var const byte   Difficulty;
var const byte   Wave;

struct Unit
{
	var int    Num;
	var String ZedClass;
};

struct Squad
{
	var ESquadType  MinVolumeType;
	var Array<Unit> Units;
};

var config bool         bRecycleWave;
var config int          MaxAI;
var config Array<Squad> Squads;
var config Array<Squad> SquadsSpecial;
var config Array<Squad> SquadsEvent;

public static function InitConfig(KFGI_Access KFGIA)
{
	local KFAIWaveInfo   KFAIWI;
	local KFAISpawnSquad KFAISS;
	local AISquadElement AISE;
	local Squad          S;
	local Unit           U;
	
	KFAIWI = default.DefSpawnManager.default.DifficultyWaveSettings[default.Difficulty].Waves[default.Wave];
	
	default.bRecycleWave = KFAIWI.bRecycleWave;
	default.MaxAI        = KFAIWI.MaxAI;
	
	default.Squads.Length = 0;
	foreach KFAIWI.Squads(KFAISS)
	{
		S.MinVolumeType = KFAISS.MinVolumeType;
		foreach KFAISS.MonsterList(AISE)
		{
			U.ZedClass = GetPawnClassString(KFGIA, AISE);
			U.Num      = AISE.Num;
			S.Units.AddItem(U);
		}
		default.Squads.AddItem(S);
	}
	
	default.SquadsSpecial.Length = 0;
	foreach KFAIWI.SpecialSquads(KFAISS)
	{
		S.MinVolumeType = KFAISS.MinVolumeType;
		foreach KFAISS.MonsterList(AISE)
		{
			U.ZedClass = GetPawnClassString(KFGIA, AISE);
			U.Num      = AISE.Num;
			S.Units.AddItem(U);
		}
		default.SquadsSpecial.AddItem(S);
	}
	
	default.SquadsEvent.Length = 0;
	foreach KFAIWI.EventSquads(KFAISS)
	{
		S.MinVolumeType = KFAISS.MinVolumeType;
		foreach KFAISS.MonsterList(AISE)
		{
			U.ZedClass = GetPawnClassString(KFGIA, AISE);
			U.Num      = AISE.Num;
			S.Units.AddItem(U);
		}
		default.SquadsEvent.AddItem(S);
	}
	
	StaticSaveConfig();
}

private static function String GetPawnClassString(KFGI_Access KFGIA, AISquadElement AISE)
{
	local class<KFPawn_Monster> KFPMC;
	
	KFPMC = KFGIA.AITypePawn(AISE.Type);
	if (KFPMC == None)
		KFPMC = AISE.CustomClass;
	
	return "KFGameContent." $ String(KFPMC);
}

public static function AIWaveInfo Load(E_LogLevel LogLevel, KFGI_Access KFGIA)
{
	local class<KFPawn_Monster> KFPMC;
	local AIWaveInfo       AIWI;
	local AISpawnSquad     AISS;
	local S_AISquadElement AISE;
	local Squad            S;
	local Unit             U;
	
	AIWI = new class'AIWaveInfo';
	
	AIWI.bRecycleWave = default.bRecycleWave;
	AIWI.MaxAI        = default.MaxAI;
	
	foreach default.Squads(S)
	{
		AISS = new class'AISpawnSquad';
		AISS.MinVolumeType = S.MinVolumeType;
		foreach S.Units(U)
		{
			KFPMC = class<KFPawn_Monster>(DynamicLoadObject(U.ZedClass, class'Class'));
			if (KFPMC == None)
			{
				`ZS_Warn("Can't load zed class:" @ U.ZedClass);
				continue;
			}
			
			if (!KFGIA.IsOriginalAI(KFPMC, AISE.Type))
				AISE.CustomClass = KFPMC;
			
			AISE.Num = AISE.Num;
			
			AISS.MonsterList.AddItem(AISE);
		}
		AIWI.Squads.AddItem(AISS);
	}
	
	foreach default.SquadsSpecial(S)
	{
		AISS = new class'AISpawnSquad';
		AISS.MinVolumeType = S.MinVolumeType;
		foreach S.Units(U)
		{
			KFPMC = class<KFPawn_Monster>(DynamicLoadObject(U.ZedClass, class'Class'));
			if (KFPMC == None)
			{
				`ZS_Warn("Can't load zed class:" @ U.ZedClass);
				continue;
			}
			
			if (!KFGIA.IsOriginalAI(KFPMC, AISE.Type))
				AISE.CustomClass = KFPMC;
			
			AISE.Num = AISE.Num;
			
			AISS.MonsterList.AddItem(AISE);
		}
		AIWI.SpecialSquads.AddItem(AISS);
	}
	
	foreach default.SquadsEvent(S)
	{
		AISS = new class'AISpawnSquad';
		AISS.MinVolumeType = S.MinVolumeType;
		foreach S.Units(U)
		{
			KFPMC = class<KFPawn_Monster>(DynamicLoadObject(U.ZedClass, class'Class'));
			if (KFPMC == None)
			{
				`ZS_Warn("Can't load zed class:" @ U.ZedClass);
				continue;
			}
			
			if (!KFGIA.IsOriginalAI(KFPMC, AISE.Type))
				AISE.CustomClass = KFPMC;
			
			AISE.Num = AISE.Num;
			
			AISS.MonsterList.AddItem(AISE);
		}
		AIWI.EventSquads.AddItem(AISS);
	}
	
	return AIWI;
}

defaultproperties
{
	DefSpawnManager    = class'KFAISpawnManager'
	Difficulty         = 255
	Wave               = 255
}
