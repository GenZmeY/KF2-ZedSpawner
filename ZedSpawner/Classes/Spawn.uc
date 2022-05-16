class Spawn extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

var config bool  bCyclicalSpawn;
var config bool  bShadowSpawn;

var config float ZedTotalMultiplier;
var config float SpawnTotalPlayerMultiplier;
var config float SpawnTotalCycleMultiplier;

var config float SingleSpawnLimitMultiplier;
var config float SingleSpawnLimitPlayerMultiplier;
var config float SingleSpawnLimitCycleMultiplier;

var config int   AliveSpawnLimit;

public static function InitConfig()
{
	default.bCyclicalSpawn = true;
	default.bShadowSpawn = true;
	default.ZedTotalMultiplier = 1.0;
	default.SpawnTotalPlayerMultiplier = 0.75;
	default.SpawnTotalCycleMultiplier = 0.75;
	default.SingleSpawnLimitPlayerMultiplier = 0.75;
	default.SingleSpawnLimitCycleMultiplier = 0.75;
	default.AliveSpawnLimit = 0;

	StaticSaveConfig();
}

public static function bool Load(E_LogLevel LogLevel)
{
	local bool Errors;
	
	if (default.ZedTotalMultiplier <= 0.f)
	{
		`ZS_Error("ZedTotalMultiplier" @ "(" $ default.ZedTotalMultiplier $ ")" @ "must be greater than 0.0", LogLevel);
		Errors = true;
	}
	
	if (default.SpawnTotalPlayerMultiplier < 0.f)
	{
		`ZS_Error("SpawnTotalPlayerMultiplier" @ "(" $ default.SpawnTotalPlayerMultiplier $ ")" @ "must be greater than or equal 0.0", LogLevel);
		Errors = true;
	}
	
	if (default.SpawnTotalCycleMultiplier < 0.f)
	{
		`ZS_Error("SpawnTotalCycleMultiplier" @ "(" $ default.SpawnTotalCycleMultiplier $ ")" @ "must be greater than or equal 0.0", LogLevel);
		Errors = true;
	}
	
	if (default.SingleSpawnLimitPlayerMultiplier < 0.f)
	{
		`ZS_Error("SingleSpawnLimitPlayerMultiplier" @ "(" $ default.SingleSpawnLimitPlayerMultiplier $ ")" @ "must be greater than or equal 0.0", LogLevel);
		Errors = true;
	}
	
	if (default.SingleSpawnLimitCycleMultiplier < 0.f)
	{
		`ZS_Error("SingleSpawnLimitCycleMultiplier" @ "(" $ default.SingleSpawnLimitCycleMultiplier $ ")" @ "must be greater than or equal 0.0", LogLevel);
		Errors = true;
	}
	
	if (default.AliveSpawnLimit < 0)
	{
		`ZS_Error("AliveSpawnLimit" @ "(" $ default.AliveSpawnLimit $ ")" @ "must be greater than or equal 0", LogLevel);
		Errors = true;
	}
	
	return !Errors;
}

defaultproperties
{

}
