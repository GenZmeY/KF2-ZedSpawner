class SpawnListSpecialWaves extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

struct S_SpawnEntryCfg
{
	var EAIType Wave;
	var String  ZedClass;
	var int     RelativeStart;
	var int     Delay;
	var int     Probability;
	var int     SpawnCountBase;
	var int     SingleSpawnLimit;
};

var public  config bool bStopRegularSpawn;
var private config Array<S_SpawnEntryCfg> Spawn;

public static function InitConfig(int Version, int LatestVersion, E_LogLevel LogLevel)
{
	`Log_TraceStatic();

	switch (Version)
	{
		case `NO_CONFIG:
			ApplyDefault(LogLevel);

		default: break;
	}

	if (LatestVersion != Version)
	{
		StaticSaveConfig();
	}
}

private static function ApplyDefault(E_LogLevel LogLevel)
{
	local S_SpawnEntryCfg SpawnEntry;
	local EAIType         AIType;

	`Log_TraceStatic();

	default.bStopRegularSpawn = true;
	default.Spawn.Length = 0;
	SpawnEntry.ZedClass            = "SomePackage.SomeClass";
	SpawnEntry.SpawnCountBase      = 2;
	SpawnEntry.SingleSpawnLimit    = 1;
	SpawnEntry.RelativeStart       = 0;
	SpawnEntry.Delay               = 60;
	SpawnEntry.Probability         = 100;
	foreach class'KFGameInfo_Endless'.default.SpecialWaveTypes(AIType)
	{
		SpawnEntry.Wave = AIType;
		default.Spawn.AddItem(SpawnEntry);
	}
}

public static function Array<S_SpawnEntry> Load(KFGameInfo_Endless KFGIE, E_LogLevel LogLevel)
{
	local Array<S_SpawnEntry> SpawnList;
	local S_SpawnEntryCfg     SpawnEntryCfg;
	local S_SpawnEntry        SpawnEntry;
	local int                 Line;
	local bool                Errors;

	`Log_TraceStatic();

	if (KFGIE == None)
	{
		`Log_Info("Not Endless mode, skip loading special waves");
		return SpawnList;
	}

	`Log_Info("Load special waves spawn list:");
	foreach default.Spawn(SpawnEntryCfg, Line)
	{
		Errors = false;

		SpawnEntry.Wave = SpawnEntryCfg.Wave;
		if (KFGIE.SpecialWaveTypes.Find(EAIType(SpawnEntryCfg.Wave)) == INDEX_NONE)
		{
			`Log_Warn("[" $ Line + 1 $ "]" @ "Unknown special wave:" @ SpawnEntryCfg.Wave);
			Errors = true;
		}

		SpawnEntry.ZedClass = class<KFPawn_Monster>(DynamicLoadObject(SpawnEntryCfg.ZedClass, class'Class'));
		if (SpawnEntry.ZedClass == None)
		{
			`Log_Warn("[" $ Line + 1 $ "]" @ "Can't load zed class:" @ SpawnEntryCfg.ZedClass);
			Errors = true;
		}

		SpawnEntry.RelativeStartDefault = SpawnEntryCfg.RelativeStart / 100.f;
		if (SpawnEntryCfg.RelativeStart < 0 || SpawnEntryCfg.RelativeStart > 100)
		{
			`Log_Warn("[" $ Line + 1 $ "]" @ "RelativeStart" @ "(" $ SpawnEntryCfg.RelativeStart $ ")" @ "must be greater than or equal 0 and less than or equal 100");
			Errors = true;
		}

		SpawnEntry.DelayDefault = SpawnEntryCfg.Delay;
		if (SpawnEntryCfg.Delay <= 0)
		{
			`Log_Warn("[" $ Line + 1 $ "]" @ "Delay" @ "(" $ SpawnEntryCfg.Delay $ ")" @ "must be greater than 0");
			Errors = true;
		}

		SpawnEntry.Probability = SpawnEntryCfg.Probability / 100.f;
		if (SpawnEntryCfg.Probability <= 0 || SpawnEntryCfg.Probability > 100)
		{
			`Log_Warn("[" $ Line + 1 $ "]" @ "Probability" @ "(" $ SpawnEntryCfg.Probability $ ")" @ "must be greater than 0 and less than or equal 100");
			Errors = true;
		}

		SpawnEntry.SpawnCountBase = SpawnEntryCfg.SpawnCountBase;
		if (SpawnEntry.SpawnCountBase <= 0)
		{
			`Log_Warn("[" $ Line + 1 $ "]" @ "SpawnCountBase" @ "(" $ SpawnEntryCfg.SpawnCountBase $ ")" @ "must be greater than 0");
			Errors = true;
		}

		SpawnEntry.SingleSpawnLimitDefault = SpawnEntryCfg.SingleSpawnLimit;
		if (SpawnEntry.SingleSpawnLimit < 0)
		{
			`Log_Warn("[" $ Line + 1 $ "]" @ "SingleSpawnLimit" @ "(" $ SpawnEntryCfg.SingleSpawnLimit $ ")" @ "must be equal or greater than 0");
			Errors = true;
		}

		if (!Errors)
		{
			SpawnList.AddItem(SpawnEntry);
			`Log_Debug("[" $ Line + 1 $ "]" @ "Loaded successfully: (" $ SpawnEntryCfg.Wave $ ")" @ SpawnEntryCfg.ZedClass);
		}
	}

	if (SpawnList.Length == default.Spawn.Length)
	{
		`Log_Info("Special spawn list loaded successfully (" $ default.Spawn.Length @ "entries)");
	}
	else
	{
		`Log_Info("Special spawn list: loaded" @ SpawnList.Length @ "of" @ default.Spawn.Length @ "entries");
	}

	return SpawnList;
}

defaultproperties
{

}
