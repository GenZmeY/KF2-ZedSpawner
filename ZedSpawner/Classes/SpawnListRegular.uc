class SpawnListRegular extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

struct S_SpawnEntryCfg
{
	var int     Wave;
	var String  ZedClass;
	var int     RelativeStart;
	var int     Delay;
	var int     Probability;
	var int     SpawnCountBase;
	var int     SingleSpawnLimit;
};

var public config Array<S_SpawnEntryCfg> Spawn;

delegate int SpawnListSort(S_SpawnEntryCfg A, S_SpawnEntryCfg B)
{
	return A.Wave > B.Wave ? -1 : 0;
}

public static function InitConfig(int Version, int LatestVersion, KFGI_Access KFGIA)
{
	switch (Version)
	{
		case `NO_CONFIG:
			ApplyDefault(KFGIA);
			
		default: break;
	}
	
	if (LatestVersion != Version)
	{
		StaticSaveConfig();
	}
}

private static function ApplyDefault(KFGI_Access KFGIA)
{
	local S_SpawnEntryCfg               SpawnEntry;
	local Array<class<KFPawn_Monster> > KFPM_Zeds;
	local class<KFPawn_Monster>         KFPMC;
	
	default.Spawn.Length = 0;
	
	SpawnEntry.Wave                = 0;
	SpawnEntry.SpawnCountBase      = 2;
	SpawnEntry.SingleSpawnLimit    = 1;
	SpawnEntry.RelativeStart       = 25;
	SpawnEntry.Delay               = 60;
	SpawnEntry.Probability         = 100;

	KFPM_Zeds = KFGIA.GetAIClassList();
	foreach KFPM_Zeds(KFPMC)
	{
		++SpawnEntry.Wave;
		SpawnEntry.ZedClass = "KFGameContent." $ String(KFPMC);
		default.Spawn.AddItem(SpawnEntry);
	}
}

public static function Array<S_SpawnEntry> Load(E_LogLevel LogLevel)
{
	local Array<S_SpawnEntry> SpawnList;
	local S_SpawnEntryCfg     SpawnEntryCfg;
	local S_SpawnEntry        SpawnEntry;
	local int                 Line;
	local bool                Errors;
	
	`ZS_Info("Load spawn list:");
	foreach default.Spawn(SpawnEntryCfg, Line)
	{
		Errors = false;
		
		SpawnEntry.Wave = SpawnEntryCfg.Wave;
		if (SpawnEntryCfg.Wave <= 0 || SpawnEntryCfg.Wave > 255)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Wave" @ "(" $ SpawnEntryCfg.ZedClass $ ")" @ "must be greater than 0 and less than 256");
			Errors = true;
		}
		
		SpawnEntry.ZedClass = class<KFPawn_Monster>(DynamicLoadObject(SpawnEntryCfg.ZedClass, class'Class'));
		if (SpawnEntry.ZedClass == None)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Can't load zed class:" @ SpawnEntryCfg.ZedClass);
			Errors = true;
		}
		
		SpawnEntry.RelativeStartDefault = SpawnEntryCfg.RelativeStart / 100.f;
		if (SpawnEntryCfg.RelativeStart < 0 || SpawnEntryCfg.RelativeStart > 100)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "RelativeStart" @ "(" $ SpawnEntryCfg.RelativeStart $ ")" @ "must be greater than or equal 0 and less than or equal 100");
			Errors = true;
		}
		
		SpawnEntry.DelayDefault = SpawnEntryCfg.Delay;
		if (SpawnEntryCfg.Delay <= 0)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Delay" @ "(" $ SpawnEntryCfg.Delay $ ")" @ "must be greater than 0");
			Errors = true;
		}
		
		SpawnEntry.Probability = SpawnEntryCfg.Probability / 100.f;
		if (SpawnEntryCfg.Probability <= 0 || SpawnEntryCfg.Probability > 100)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "Probability" @ "(" $ SpawnEntryCfg.Probability $ ")" @ "must be greater than 0 and less than or equal 100");
			Errors = true;
		}
		
		SpawnEntry.SpawnCountBase = SpawnEntryCfg.SpawnCountBase;
		if (SpawnEntry.SpawnCountBase <= 0)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "SpawnCountBase" @ "(" $ SpawnEntryCfg.SpawnCountBase $ ")" @ "must be greater than 0");
			Errors = true;
		}
		
		SpawnEntry.SingleSpawnLimitDefault = SpawnEntryCfg.SingleSpawnLimit;
		if (SpawnEntry.SingleSpawnLimit < 0)
		{
			`ZS_Warn("[" $ Line + 1 $ "]" @ "SingleSpawnLimit" @ "(" $ SpawnEntryCfg.SingleSpawnLimit $ ")" @ "must be equal or greater than 0");
			Errors = true;
		}

		if (!Errors)
		{
			SpawnList.AddItem(SpawnEntry);
			`ZS_Debug("[" $ Line + 1 $ "]" @ "Loaded successfully: (w" $ SpawnEntryCfg.Wave $ ")" @ SpawnEntryCfg.ZedClass);
		}
	}
	
	default.Spawn.Sort(SpawnListSort);
	
	if (SpawnList.Length == default.Spawn.Length)
	{
		`ZS_Info("Regular spawn list loaded successfully (" $ default.Spawn.Length @ "entries)");
	}
	else
	{
		`ZS_Info("Regular spawn list: loaded" @ SpawnList.Length @ "of" @ default.Spawn.Length @ "entries");
	}
	
	return SpawnList;
}

defaultproperties
{

}
