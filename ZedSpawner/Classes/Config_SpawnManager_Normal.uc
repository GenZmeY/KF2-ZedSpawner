class Config_SpawnManager_Normal extends Config_SpawnManager
	config(ZedSpawner);

public static function bool Load(E_LogLevel LogLevel)
{
	local bool Errors;
	Errors = false;
	return !Errors;
}

defaultproperties
{
	DefSpawnManager = class'KFAISpawnManager_Normal'
}
