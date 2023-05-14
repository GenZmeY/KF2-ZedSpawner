class SpawnAtPlayerStart extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

var private config Array<String> ZedClass;
var public  config Array<String> Map;

public static function InitConfig(int Version, int LatestVersion, E_LogLevel LogLevel)
{
	`Log_TraceStatic();

	switch (Version)
	{
		case `NO_CONFIG:
		case 2:
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
	`Log_TraceStatic();

	default.ZedClass.Length = 0;
	default.ZedClass.AddItem("HL2Monsters.Combine_Strider");
	default.ZedClass.AddItem("HL2Monsters.Combine_Gunship");
	default.ZedClass.AddItem("HL2Monsters.Hunter_Chopper");
	default.ZedClass.AddItem("SomePackage.SomeZedClassYouWantToSpawnAtPlayerStart");

	default.Map.Length = 0;
	default.Map.AddItem("KF-SomeMapNameWhereYouWantSpawnZedsAtPlayerStart");
}

public static function Array<class<KFPawn_Monster> > Load(E_LogLevel LogLevel)
{
	local Array<class<KFPawn_Monster> > ZedList;
	local class<KFPawn_Monster> KFPMC;
	local String ZedClassTmp;
	local int Line;

	`Log_TraceStatic();

	`Log_Info("Load zeds to spawn at player start:");
	foreach default.ZedClass(ZedClassTmp, Line)
	{
		KFPMC = class<KFPawn_Monster>(DynamicLoadObject(ZedClassTmp, class'Class'));
		if (KFPMC == None)
		{
			`Log_Warn("[" $ Line + 1 $ "]" @ "Can't load zed class:" @ ZedClassTmp);
		}
		else
		{
			ZedList.AddItem(KFPMC);
			`Log_Debug("[" $ Line + 1 $ "]" @ "Loaded successfully:" @ ZedClassTmp);
		}
	}

	if (ZedList.Length == default.ZedClass.Length)
	{
		`Log_Info("Spawn at player start list (Zeds) loaded successfully (" $ default.ZedClass.Length @ "entries)");
	}
	else
	{
		`Log_Info("Spawn at player start list (Zeds): loaded" @ ZedList.Length @ "of" @ default.ZedClass.Length @ "entries");
	}

	return ZedList;
}

defaultproperties
{

}
