class Spawn extends Object
	dependson(ZedSpawner)
	config(ZedSpawner);

var config bool  bCyclicalSpawn;
var config bool  bShadowSpawn;
var config float ZedMultiplier;
var config float PlayerMultiplier;
var config float CycleMultiplier;
var config int   AliveSpawnLimit;

public static function InitConfig()
{
	default.bCyclicalSpawn = true;
	default.bShadowSpawn = true;
	default.ZedMultiplier = 1.0;
	default.PlayerMultiplier = 0.25;
	default.CycleMultiplier = 0.25;
	default.AliveSpawnLimit = 0;

	StaticSaveConfig();
}

public static function bool Load(E_LogLevel LogLevel)
{
	local bool Errors;
	
	if (default.ZedMultiplier <= 0.f)
	{
		`ZS_Error("ZedMultiplier" @ "(" $ default.ZedMultiplier $ ")" @ "must be greater than 0.0", LogLevel);
		Errors = true;
	}
	
	if (default.PlayerMultiplier < 0.f)
	{
		`ZS_Error("PlayerMultiplier" @ "(" $ default.PlayerMultiplier $ ")" @ "must be greater than or equal 0.0", LogLevel);
		Errors = true;
	}
	
	if (default.CycleMultiplier < 0.f)
	{
		`ZS_Error("CycleMultiplier" @ "(" $ default.CycleMultiplier $ ")" @ "must be greater than or equal 0.0", LogLevel);
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
