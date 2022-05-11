class SpawnList extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

struct S_SpawnEntryCfg
{
	var int     Wave;
	var String  ZedClass;
	var int     RelativeDelay;
	var int     Delay;
	var int     Probability;
	var int     SpawnAtOnce;
	var int     MaxSpawns;
	var bool    bSpawnAtPlayerStart;
};

var config Array<S_SpawnEntryCfg> Spawn;

public static function InitConfig()
{
	local S_SpawnEntryCfg SpawnEntry;
	
	default.Spawn.Length = 0;
	
	SpawnEntry.Wave                = 1;
	SpawnEntry.ZedClass            = "SomePackage.SomeZedClass1";
	SpawnEntry.SpawnAtOnce         = 1;
	SpawnEntry.MaxSpawns           = 1;
	SpawnEntry.RelativeDelay       = 0;
	SpawnEntry.Delay               = 60;
	SpawnEntry.Probability         = 100;
	SpawnEntry.bSpawnAtPlayerStart = false;
	default.Spawn.AddItem(SpawnEntry);
	
	SpawnEntry.Wave                = 2;
	SpawnEntry.ZedClass            = "SomePackage.SomeZedClass2";
	SpawnEntry.SpawnAtOnce         = 2;
	SpawnEntry.MaxSpawns           = 4;
	SpawnEntry.RelativeDelay       = 0;
	SpawnEntry.Delay               = 30;
	SpawnEntry.Probability         = 50;
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
	
	`ZS_Info("Load spawn list:", LogLevel);
	foreach default.Spawn(SpawnEntryCfg, Line)
	{
		Errors = false;
		
		SpawnEntry.ZedClass = class<KFPawn_Monster>(DynamicLoadObject(SpawnEntryCfg.ZedClass, class'Class'));
		if (SpawnEntry.ZedClass == None)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Can't load zed class:" @ SpawnEntryCfg.ZedClass, LogLevel);
			Errors = true;
		}
		
		SpawnEntry.Wave = SpawnEntryCfg.Wave;
		if (SpawnEntryCfg.Wave <= 0 || SpawnEntryCfg.Wave > 255)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Wave" @ "(" $ SpawnEntryCfg.ZedClass $ ")" @ "must be greater than 0 and less than 256", LogLevel);
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
