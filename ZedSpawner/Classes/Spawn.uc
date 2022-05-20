class Spawn extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

var public config bool  bCyclicalSpawn;
var public config bool  bShadowSpawn;
var public config float ZedTotalMultiplier;
var public config float SpawnTotalPlayerMultiplier;
var public config float SpawnTotalCycleMultiplier;
var public config float SingleSpawnLimitMultiplier;
var public config float SingleSpawnLimitPlayerMultiplier;
var public config float SingleSpawnLimitCycleMultiplier;
var public config int   AliveSpawnLimit;

public static function InitConfig(int Version, int LatestVersion)
{
	switch (Version)
	{
		case `NO_CONFIG:
			ApplyDefault();
			
		default: break;
	}
	
	if (LatestVersion != Version)
	{
		StaticSaveConfig();
	}
}

private static function ApplyDefault()
{
	default.bCyclicalSpawn                   = true;
	default.bShadowSpawn                     = true;
	default.ZedTotalMultiplier               = 1.0;
	default.SpawnTotalPlayerMultiplier       = 0.75;
	default.SpawnTotalCycleMultiplier        = 0.75;
	default.SingleSpawnLimitMultiplier       = 1.0;
	default.SingleSpawnLimitPlayerMultiplier = 0.75;
	default.SingleSpawnLimitCycleMultiplier  = 0.75;
	default.AliveSpawnLimit                  = 0;
}

public static function bool Load(E_LogLevel LogLevel)
{
	local bool Errors;
	
	if (default.ZedTotalMultiplier <= 0.f)
	{
		`ZS_Error("ZedTotalMultiplier" @ "(" $ default.ZedTotalMultiplier $ ")" @ "must be greater than 0.0");
		Errors = true;
	}
	
	if (default.SpawnTotalPlayerMultiplier < 0.f)
	{
		`ZS_Error("SpawnTotalPlayerMultiplier" @ "(" $ default.SpawnTotalPlayerMultiplier $ ")" @ "must be greater than or equal 0.0");
		Errors = true;
	}
	
	if (default.SpawnTotalCycleMultiplier < 0.f)
	{
		`ZS_Error("SpawnTotalCycleMultiplier" @ "(" $ default.SpawnTotalCycleMultiplier $ ")" @ "must be greater than or equal 0.0");
		Errors = true;
	}
	
	if (default.SingleSpawnLimitPlayerMultiplier < 0.f)
	{
		`ZS_Error("SingleSpawnLimitPlayerMultiplier" @ "(" $ default.SingleSpawnLimitPlayerMultiplier $ ")" @ "must be greater than or equal 0.0");
		Errors = true;
	}
	
	if (default.SingleSpawnLimitCycleMultiplier < 0.f)
	{
		`ZS_Error("SingleSpawnLimitCycleMultiplier" @ "(" $ default.SingleSpawnLimitCycleMultiplier $ ")" @ "must be greater than or equal 0.0");
		Errors = true;
	}
	
	if (default.AliveSpawnLimit < 0)
	{
		`ZS_Error("AliveSpawnLimit" @ "(" $ default.AliveSpawnLimit $ ")" @ "must be greater than or equal 0");
		Errors = true;
	}
	
	return !Errors;
}

defaultproperties
{

}
