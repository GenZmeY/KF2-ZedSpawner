// This file is part of Zed Spawner.
// Zed Spawner - a mutator for Killing Floor 2.
//
// Copyright (C) 2022, 2024 GenZmeY (mailto: genzmey@gmail.com)
//
// Zed Spawner is free software: you can redistribute it
// and/or modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// Zed Spawner is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with Zed Spawner. If not, see <https://www.gnu.org/licenses/>.

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
var public config bool  bSmoothSpawn;

public static function InitConfig(int Version, int LatestVersion, E_LogLevel LogLevel)
{
	`Log_TraceStatic();

	switch (Version)
	{
		case `NO_CONFIG:
			ApplyDefault(LogLevel);

		case 3:
			default.bSmoothSpawn = false;

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

	default.bCyclicalSpawn                   = true;
	default.bShadowSpawn                     = true;
	default.bSmoothSpawn                     = true;
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

	`Log_TraceStatic();

	if (default.ZedTotalMultiplier <= 0.f)
	{
		`Log_Error("ZedTotalMultiplier" @ "(" $ default.ZedTotalMultiplier $ ")" @ "must be greater than 0.0");
		Errors = true;
	}

	if (default.SpawnTotalPlayerMultiplier < 0.f)
	{
		`Log_Error("SpawnTotalPlayerMultiplier" @ "(" $ default.SpawnTotalPlayerMultiplier $ ")" @ "must be greater than or equal 0.0");
		Errors = true;
	}

	if (default.SpawnTotalCycleMultiplier < 0.f)
	{
		`Log_Error("SpawnTotalCycleMultiplier" @ "(" $ default.SpawnTotalCycleMultiplier $ ")" @ "must be greater than or equal 0.0");
		Errors = true;
	}

	if (default.SingleSpawnLimitMultiplier <= 0.f)
	{
		`Log_Error("SingleSpawnLimitMultiplier" @ "(" $ default.SingleSpawnLimitMultiplier $ ")" @ "must be greater than 0.0");
		Errors = true;
	}

	if (default.SingleSpawnLimitPlayerMultiplier < 0.f)
	{
		`Log_Error("SingleSpawnLimitPlayerMultiplier" @ "(" $ default.SingleSpawnLimitPlayerMultiplier $ ")" @ "must be greater than or equal 0.0");
		Errors = true;
	}

	if (default.SingleSpawnLimitCycleMultiplier < 0.f)
	{
		`Log_Error("SingleSpawnLimitCycleMultiplier" @ "(" $ default.SingleSpawnLimitCycleMultiplier $ ")" @ "must be greater than or equal 0.0");
		Errors = true;
	}

	if (default.AliveSpawnLimit < 0)
	{
		`Log_Error("AliveSpawnLimit" @ "(" $ default.AliveSpawnLimit $ ")" @ "must be greater than or equal 0");
		Errors = true;
	}

	return !Errors;
}

defaultproperties
{

}
