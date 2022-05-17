class AISpawnManager_Endless extends AISpawnManager
	within KFGameInfo_Endless;

struct S_MacroDifficultyWaveInfo
{
	var Array<S_DifficultyWaveInfo> MacroDifficultyWaveSettings;
};

struct MacroDifficultyWaveInfo
{
	var Array<DifficultyWaveInfo> MacroDifficultyWaveSettings;
};

var protected Array<MacroDifficultyWaveInfo> DifficultyWaves;
var protected Array<S_MacroDifficultyWaveInfo> V_DifficultyWaves;

public function SetupNextWave(byte NextWaveIndex, int TimeToNextWaveBuffer = 0)
{
	`ZS_Trace(`Location);
	
	Super.SetupNextWave(NextWaveIndex % WaveSettings.Waves.length, TimeToNextWaveBuffer);
}

public function GetAvailableSquads(byte MyWaveIndex, optional bool bNeedsSpecialSquad = false)
{
	`ZS_Trace(`Location);
	
	Super.GetAvailableSquads(MyWaveIndex % WaveSettings.Waves.length, bNeedsSpecialSquad);
}

public function GetWaveSettings(out DifficultyWaveInfo WaveInfo)
{
	local int AdGD;   // AdjustedGameDifficulty
	local int AvAdGD; // AvailableAdjustedGameDifficulty
	local int AvGD;   // AvailableGameDifficulty
	local int DWL;    // DifficultyWavesLength
	local int MDWSL;  // MacroDifficultyWaveSettingsLength
	
	`ZS_Trace(`Location);
	
	DWL = DifficultyWaves.Length;
	if (DWL > 0)
	{
		AvGD = Clamp(GameDifficulty, 0, DWL - 1);
		MDWSL = DifficultyWaves[AvGD].MacroDifficultyWaveSettings.Length;
		if (MDWSL > 0)
		{
			AdGD     = EndlessDifficulty.GetCurrentDifficultyIndex();
			AvAdGD   = Clamp(AdGD, 0, MDWSL - 1);
			WaveInfo = DifficultyWaves[AvGD].MacroDifficultyWaveSettings[AvAdGD];
		}
	}
	
	V_GetWaveSettings(V_WaveSettings);
}

protected function V_GetWaveSettings(out S_DifficultyWaveInfo WaveInfo)
{
	local int AdGD;   // AdjustedGameDifficulty
	local int AvAdGD; // AvailableAdjustedGameDifficulty
	local int AvGD;   // AvailableGameDifficulty
	local int VDWL;   // V_DifficultyWavesLength
	local int MDWSL;  // MacroDifficultyWaveSettingsLength
	
	`ZS_Trace(`Location);
	
	VDWL = V_DifficultyWaves.Length;
	if (VDWL > 0)
	{
		AvGD = Clamp(GameDifficulty, 0, VDWL - 1);
		MDWSL = V_DifficultyWaves[AvGD].MacroDifficultyWaveSettings.Length;
		if (MDWSL > 0)
		{
			AdGD     = EndlessDifficulty.GetCurrentDifficultyIndex();
			AvAdGD   = Clamp(AdGD, 0, MDWSL - 1);
			WaveInfo = V_DifficultyWaves[AvGD].MacroDifficultyWaveSettings[AvAdGD];
		}
	}
}

public function OnDifficultyUpdated()
{
	`ZS_Trace(`Location);
	
	GetWaveSettings(WaveSettings);
}

public function OnBossDied()
{
	`ZS_Trace(`Location);
	
	BossMinionsSpawnSquads.length = 0;
	AvailableSquads.length        = 0;
	V_AvailableSquads.length      = 0;
}

public function float GetNextSpawnTimeMod()
{
	local float SpawnTimeMod, SpawnTimeModMin;
	local int TempModIdx;

	`ZS_Trace(`Location);

	SpawnTimeMod = super.GetNextSpawnTimeMod();

	if (MyKFGRI.IsSpecialWave(TempModIdx))
	{
		SpawnTimeModMin = EndlessDifficulty.GetSpecialWaveSpawnTimeModMin(SpecialWaveType);
		SpawnTimeMod = Max(SpawnTimeMod, SpawnTimeModMin);
	}

	return SpawnTimeMod;
}

defaultproperties
{
	Config = class'Config_SpawnManager_Endless'
}
