class SpawnListSpecialWaves extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

struct S_SpawnEntryCfg
{
	var EAIType Wave;
	var String  ZedClass;
	var int     RelativeDelay;
	var int     Delay;
	var int     Probability;
	var int     SpawnAtOnce;
	var int     MaxSpawns;
	var bool    bSpawnAtPlayerStart;
};

var config bool bStopRegularSpawn;
var config Array<S_SpawnEntryCfg> Spawn;

public static function InitConfig()
{
	local S_SpawnEntryCfg SpawnEntry;
	
	default.bStopRegularSpawn = true;
	
	default.Spawn.Length = 0;
	
	SpawnEntry.Wave                = AT_Husk;
	SpawnEntry.ZedClass            = "SomePackage.SomeHuskClass";
	SpawnEntry.SpawnAtOnce         = 1;
	SpawnEntry.MaxSpawns           = 1;
	SpawnEntry.RelativeDelay       = 0;
	SpawnEntry.Delay               = 60;
	SpawnEntry.Probability         = 1;
	SpawnEntry.bSpawnAtPlayerStart = false;
	default.Spawn.AddItem(SpawnEntry);
	
	StaticSaveConfig();
}

public static function Array<S_SpawnEntry> Load(KFGameInfo_Endless KFGIE, E_LogLevel LogLevel)
{
	local Array<S_SpawnEntry> SpawnList;
	local S_SpawnEntryCfg     SpawnEntryCfg;
	local S_SpawnEntry        SpawnEntry;
	local int                 Line;
	local bool                Errors;
	
	if (KFGIE == None)
	{
		`ZS_Info("Not Endless mode, skip loading special waves", LogLevel);
		return SpawnList;
	}
	
	`ZS_Info("Load special waves spawn list:", LogLevel);
	foreach default.Spawn(SpawnEntryCfg, Line)
	{
		Errors = false;
		
		SpawnEntry.Wave = SpawnEntryCfg.Wave;
		if (KFGIE.SpecialWaveTypes.Find(EAIType(SpawnEntryCfg.Wave)) == INDEX_NONE)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Unknown special wave:" @ SpawnEntryCfg.Wave, LogLevel);
			Errors = true;
		}
		
		SpawnEntry.ZedClass = class<KFPawn_Monster>(DynamicLoadObject(SpawnEntryCfg.ZedClass, class'Class'));
		if (SpawnEntry.ZedClass == None)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Can't load zed class:" @ SpawnEntryCfg.ZedClass, LogLevel);
			Errors = true;
		}
		
		SpawnEntry.SpawnAtOnce = SpawnEntryCfg.SpawnAtOnce;
		if (SpawnEntry.SpawnAtOnce <= 0)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "SpawnAtOnce" @ "(" $ SpawnEntryCfg.SpawnAtOnce $ ")" @ "must be greater than 0", LogLevel);
			Errors = true;
		}
		
		SpawnEntry.Probability = SpawnEntryCfg.Probability / 100.f;
		if (SpawnEntryCfg.Probability <= 0 || SpawnEntryCfg.Probability > 100)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Probability" @ "(" $ SpawnEntryCfg.Probability $ ")" @ "must be greater than 0 and less than or equal 100", LogLevel);
			Errors = true;
		}
		
		SpawnEntry.RelativeDelayDefault = SpawnEntryCfg.RelativeDelay / 100.f;
		if (SpawnEntryCfg.RelativeDelay < 0 || SpawnEntryCfg.RelativeDelay > 100)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "RelativeDelay" @ "(" $ SpawnEntryCfg.RelativeDelay $ ")" @ "must be greater than or equal 0 and less than or equal 100", LogLevel);
			Errors = true;
		}
		
		SpawnEntry.DelayDefault = SpawnEntryCfg.Delay;
		if (SpawnEntryCfg.Delay <= 0)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Delay" @ "(" $ SpawnEntryCfg.Delay $ ")" @ "must be greater than 0", LogLevel);
			Errors = true;
		}
		
		SpawnEntry.MaxSpawns = SpawnEntryCfg.MaxSpawns;
		if (SpawnEntryCfg.Delay <= 0)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "MaxSpawns" @ "(" $ SpawnEntryCfg.MaxSpawns $ ")" @ "must be greater than 0", LogLevel);
			Errors = true;
		}
		
		SpawnEntry.SpawnAtPlayerStart = SpawnEntryCfg.bSpawnAtPlayerStart;
		
		if (!Errors)
		{
			SpawnList.AddItem(SpawnEntry);
			`ZS_Info("[" $ Line + 1 $ "]" @ "Loaded successfully:" @ SpawnEntryCfg.Wave @ SpawnEntryCfg.ZedClass, LogLevel);
		}
	}
	
	return SpawnList;
}

defaultproperties
{

}
