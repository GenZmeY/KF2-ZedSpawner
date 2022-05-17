class AISpawnManager extends KFAISpawnManager
	abstract;

const class<Config_SpawnManager> Config;

struct S_DifficultyWaveInfo
{
    var Array<AIWaveInfo> Waves;
};

var protected ZedSpawner ZS;

var protected Array<S_DifficultyWaveInfo> V_DifficultyWaveSettings;
var protected S_DifficultyWaveInfo        V_WaveSettings;
var protected Array<AISpawnSquad>         V_AvailableSquads;

var public E_LogLevel LogLevel;

private function CopySpawnSquadArray(Array<KFAISpawnSquad> From, out Array<AISpawnSquad> To)
{
	local KFAISpawnSquad SS;
	
	`ZS_Trace(`Location);
	
	To.Length = 0;
	foreach From(SS)
		To.AddItem(class'AISpawnSquad'.static.CreateFrom(SS));
}

private function ZedSpawner GetZedSpawner()
{
	foreach WorldInfo.DynamicActors(class'ZedSpawner', ZS)
		return ZS;
	return None;
}

public function Initialize()
{
	ZS = GetZedSpawner();
	if (ZS != None)
	{
		LogLevel = ZS.LogLevel;
		`ZS_Trace(`Location);
	}
	else
	{
		`ZS_Log("FATAL: no ZedSpawner found! Destroy" @ Self.class);
		`ZS_Log("FATAL:" @ `Location);
		Destroy();
		return;
	}
	
	// TODO:
	
	Super.Initialize();
}

public function GetWaveSettings(out DifficultyWaveInfo WaveInfo)
{
	`ZS_Trace(`Location);
	
	if (DifficultyWaveSettings.Length > 0)
		WaveInfo = DifficultyWaveSettings[Clamp(GameDifficulty, 0, DifficultyWaveSettings.Length - 1)];

	V_GetWaveSettings(V_WaveSettings);
}

protected function V_GetWaveSettings(out S_DifficultyWaveInfo WaveInfo)
{
	`ZS_Trace(`Location);
	
	if (V_DifficultyWaveSettings.Length > 0)
		WaveInfo = V_DifficultyWaveSettings[Clamp(GameDifficulty, 0, V_DifficultyWaveSettings.Length - 1)];
}

public function SetupNextWave(byte NextWaveIndex, int TimeToNextWaveBuffer = 0)
{
	local KFGameReplicationInfo KFGRI;

	`ZS_Trace(`Location);

	if (OutbreakEvent.ActiveEvent.bBossRushMode)
	{
		NextWaveIndex = MyKFGRI.WaveMax - 1;
	}

	if (NextWaveIndex < V_WaveSettings.Waves.Length)
	{
    	if (GameDifficulty < RecycleSpecialSquad.Length)
    	{
    	   bRecycleSpecialSquad = RecycleSpecialSquad[GameDifficulty];
    	}
    	else
    	{
    	   bRecycleSpecialSquad = RecycleSpecialSquad[RecycleSpecialSquad.Length - 1];
    	}

        LeftoverSpawnSquad.Length = 0;
        NumSpawnListCycles = 1;
        NumSpecialSquadRecycles = 0;

		if (MyKFGRI.IsBossWave() || OutbreakEvent.ActiveEvent.bBossRushMode)
		{
			WaveTotalAI = 1;
		}
		else
		{
			if (V_WaveSettings.Waves[NextWaveIndex].bRecycleWave)
			{
				WaveTotalAI = V_WaveSettings.Waves[NextWaveIndex].MaxAI *
					DifficultyInfo.GetPlayerNumMaxAIModifier(GetNumHumanTeamPlayers()) *
					DifficultyInfo.GetDifficultyMaxAIModifier();
			}
			else
			{
				WaveTotalAI = V_WaveSettings.Waves[NextWaveIndex].MaxAI;
			}
			WaveTotalAI *= GetTotalWaveCountScale();
			WaveTotalAI = Max(1, WaveTotalAI);
		}

        GetAvailableSquads(NextWaveIndex, true);

		WaveStartTime = WorldInfo.TimeSeconds;
		TimeUntilNextSpawn = 5.f + TimeToNextWaveBuffer;

		if (NextWaveIndex == 0)
		{
            TotalWavesActiveTime = 0;
        }

    	KFGRI = KFGameReplicationInfo(WorldInfo.GRI);
    	if (KFGRI != None && (KFGRI.bDebugSpawnManager || KFGRI.bGameConductorGraphingEnabled))
    	{
    		KFGRI.CurrentSineMod = GetSineMod();
    		KFGRI.CurrentNextSpawnTime = TimeUntilNextSpawn;
    		KFGRI.CurrentSineWavFreq = GetSineWaveFreq();
    		KFGRI.CurrentNextSpawnTimeMod = GetNextSpawnTimeMod();
    		KFGRI.CurrentTotalWavesActiveTime = TotalWavesActiveTime;
    		KFGRI.CurrentMaxMonsters = GetMaxMonsters();
    		KFGRI.CurrentTimeTilNextSpawn = TimeUntilNextSpawn;
    	}
	}

    LastAISpawnVolume = None;
}

public function GetAvailableSquads(byte MyWaveIndex, optional bool bNeedsSpecialSquad=false)
{
	local int i, j, TotalZedsInSquads;

	`ZS_Trace(`Location);
	
    if (V_WaveSettings.Waves[MyWaveIndex] != None)
	{
		NumSpawnListCycles++;

        V_WaveSettings.Waves[MyWaveIndex].GetNewSquadList(V_AvailableSquads);

		if (bNeedsSpecialSquad)
		{
		 	V_WaveSettings.Waves[MyWaveIndex].GetSpecialSquad(V_AvailableSquads);

            for (i = 0; i < V_AvailableSquads.Length; i++)
        	{
        		for (j = 0; j < V_AvailableSquads[i].MonsterList.Length; j++)
        		{
                    TotalZedsInSquads += V_AvailableSquads[i].MonsterList[j].Num;
        		}
        	}

    	 	if (WaveTotalAI < TotalZedsInSquads)
    	 	{
                bForceRequiredSquad = true;
            }
		}
	}
}

public function V_GetSpawnListFromSquad(byte SquadIdx, out Array<AISpawnSquad> SquadsList, out Array<class<KFPawn_Monster> > AISpawnList)
{
	local AISpawnSquad Squad;
	local EAIType AIType;
	local int i, j, RandNum;
	local ESquadType LargestMonsterSquadType;
    local Array<class<KFPawn_Monster> > TempSpawnList;
	local int RandBossIndex;
	
	`ZS_Trace(`Location);
	
	Squad = SquadsList[SquadIdx];

	LargestMonsterSquadType = EST_Crawler;

	for (i = 0; i < Squad.MonsterList.Length; i++)
	{
		for (j = 0; j < Squad.MonsterList[i].Num; j++)
		{
			if (Squad.MonsterList[i].CustomClass != None)
			{
				TempSpawnList.AddItem(Squad.MonsterList[i].CustomClass);
			}
			else
			{
				AIType = Squad.MonsterList[i].Type;
				if (AIType == AT_BossRandom)
				{
                    if (OutbreakEvent.ActiveEvent.bBossRushMode)
					{
						RandBossIndex = Rand(BossRushEnemies.length);
						TempSpawnList.AddItem( default.AIBossClassList[BossRushEnemies[RandBossIndex]]);
						BossRushEnemies.Remove(RandBossIndex, 1);
					}
					else
					{
						TempSpawnList.AddItem(GetBossAISpawnType());
					}

                    LargestMonsterSquadType = EST_Boss;
				}
				else
				{
					TempSpawnList.AddItem(GetAISpawnType(AIType));
				}
			}

			if (TempSpawnList[TempSpawnList.Length - 1].default.MinSpawnSquadSizeType < LargestMonsterSquadType)
            {
                LargestMonsterSquadType = TempSpawnList[TempSpawnList.Length - 1].default.MinSpawnSquadSizeType;
            }
		}
	}
	if (TempSpawnList.Length > 0)
	{
        while (TempSpawnList.Length > 0)
        {
            RandNum = Rand( TempSpawnList.Length);
            AISpawnList.AddItem( TempSpawnList[RandNum]);
            TempSpawnList.Remove( RandNum, 1);
        }

		DesiredSquadType = Squad.MinVolumeType;

		if (LargestMonsterSquadType < DesiredSquadType)
        {
            DesiredSquadType = LargestMonsterSquadType;
        }
	}
}

public function Array<class<KFPawn_Monster> > GetNextSpawnList()
{
	local Array<class<KFPawn_Monster> >  NewSquad, RequiredSquad;
	local int RandNum, AINeeded;

	`ZS_Trace(`Location);
	
	if (LeftoverSpawnSquad.Length > 0)
    {
        NewSquad = LeftoverSpawnSquad;
        SetDesiredSquadTypeForZedList(NewSquad);
    }
    else
    {
		if (!IsAISquadAvailable())
		{
			if (!bSummoningBossMinions)
			{
	            if (bRecycleSpecialSquad && NumSpawnListCycles % 2 == 1 && (MaxSpecialSquadRecycles == -1 || NumSpecialSquadRecycles < MaxSpecialSquadRecycles))
	            {
	                GetAvailableSquads(MyKFGRI.WaveNum - 1, true);
	                ++NumSpecialSquadRecycles;
	            }
	            else
	            {
	                GetAvailableSquads(MyKFGRI.WaveNum - 1);
	            }
	        }
	        else
	        {
				CopySpawnSquadArray(BossMinionsSpawnSquads, V_AvailableSquads);
	        }
		}

		RandNum = Rand(V_AvailableSquads.Length);

		if (bForceRequiredSquad && RandNum == (V_AvailableSquads.Length - 1))
		{
		   bForceRequiredSquad=false;
		}
		
		V_GetSpawnListFromSquad(RandNum, V_AvailableSquads, NewSquad);

		if (bForceRequiredSquad)
		{
	    	V_GetSpawnListFromSquad((V_AvailableSquads.Length - 1), V_AvailableSquads, RequiredSquad);

	        if ((NumAISpawnsQueued + NewSquad.Length + RequiredSquad.Length) > WaveTotalAI)
	        {
	            NewSquad = RequiredSquad;
	            RandNum = (V_AvailableSquads.Length - 1);
	            bForceRequiredSquad=false;
	        }
		}

		V_AvailableSquads.Remove(RandNum, 1);
	}

	AINeeded = GetNumAINeeded();
	if (AINeeded < NewSquad.Length)
	{
		LeftoverSpawnSquad = NewSquad;
        LeftoverSpawnSquad.Remove(0, AINeeded);
        NewSquad.Length = AINeeded;
	}
	else
	{
        LeftoverSpawnSquad.Length = 0;
	}

	return NewSquad;
}

public function bool IsAISquadAvailable()
{
	`ZS_Trace(`Location);
	
	return (V_AvailableSquads.Length > 0);
}

public function SummonBossMinions(Array<KFAISpawnSquad> NewMinionSquad, int NewMaxBossMinions, optional bool bUseLivingPlayerScale = true)
{
	`ZS_Trace(`Location);
	
	CopySpawnSquadArray(NewMinionSquad, V_AvailableSquads);
	Super.SummonBossMinions(NewMinionSquad, NewMaxBossMinions, bUseLivingPlayerScale);
}

public function StopSummoningBossMinions()
{
	`ZS_Trace(`Location);
	
	V_AvailableSquads.Length = 0;
	Super.StopSummoningBossMinions();
}

defaultproperties
{
	Config = class'Config_SpawnManager'
}
