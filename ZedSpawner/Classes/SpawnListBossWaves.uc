class SpawnListBossWaves extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

struct S_SpawnEntryCfg
{
	var String  BossClass;
	var String  ZedClass;
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
	
	SpawnEntry.BossClass           = "KFGameContent.KFPawn_ZedFleshpoundKing";
	SpawnEntry.ZedClass            = "SomePackage.SomeFleshpoundClass";
	SpawnEntry.SpawnAtOnce         = 1;
	SpawnEntry.MaxSpawns           = 1;
	SpawnEntry.Delay               = 60;
	SpawnEntry.Probability         = 1;
	SpawnEntry.bSpawnAtPlayerStart = false;
	default.Spawn.AddItem(SpawnEntry);
	
	StaticSaveConfig();
}

public static function Array<S_SpawnEntry> Load(E_LogLevel LogLevel)
{
	local Array<S_SpawnEntry> SpawnList;
	local S_SpawnEntryCfg     SpawnEntryCfg;
	local S_SpawnEntry        SpawnEntry;
	local int                 Line;
	local bool                Errors;
	
	`ZS_Info("Load boss waves spawn list:", LogLevel);
	foreach default.Spawn(SpawnEntryCfg, Line)
	{
		Errors = false;
		
		SpawnEntry.BossClass = class<KFPawn_Monster>(DynamicLoadObject(SpawnEntryCfg.BossClass, class'Class'));
		if (SpawnEntry.BossClass == None)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Can't load boss class:" @ SpawnEntryCfg.BossClass, LogLevel);
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
		
		SpawnEntry.RelativeDelayDefault = 0.f;
		
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
			`ZS_Info("[" $ Line + 1 $ "]" @ "Loaded successfully:" @ SpawnEntryCfg.BossClass @ SpawnEntryCfg.ZedClass, LogLevel);
		}
	}
	
	return SpawnList;
}

defaultproperties
{

}
