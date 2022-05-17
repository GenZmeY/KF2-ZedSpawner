class Config_SpawnManager extends Object
	config(ZedSpawner);

var const class<KFAISpawnManager> DefSpawnManager;

public static function InitConfig()
{
	local DifficultyWaveInfo DWI;
	local KFAIWaveInfo       KFAIWI;
	local AIWaveInfo         AIWI;
	local int                Diff, Wave;
	
	`ZS_Log("InitConfig:" @ default.DefSpawnManager);
	foreach default.DefSpawnManager.default.DifficultyWaveSettings(DWI, Diff)
	{
		`ZS_Log(" Diff:" @ Diff);
		foreach DWI.Waves(KFAIWI, Wave)
		{
			`ZS_Log("  Wave:" @ Wave);
			AIWI = class'AIWaveInfo'.static.CreateFrom(KFAIWI);
		}
	}
	
	//StaticSaveConfig();
}

public static function bool Load(E_LogLevel LogLevel)
{
	local bool Errors;
	Errors = false;
	return !Errors;
}

defaultproperties
{
	DefSpawnManager = class'KFAISpawnManager'
}
