class AIWaveInfo extends Object
	dependson(AISpawnSquad)
	hidecategories(Object);

var() bool bRecycleWave;
var() Array<AISpawnSquad> Squads;
var() Array<AISpawnSquad> SpecialSquads;
var() int MaxAI<ClampMin=1|ClampMax=200|DisplayName=TotalAIBase>;
var() Array<AISpawnSquad> EventSquads;

public function GetNewSquadList(out Array<AISpawnSquad> out_SquadList)
{
	local AISpawnSquad SS;

	out_SquadList.Length = 0;
	foreach Squads(SS)
		if (SS != None)
			out_SquadList.AddItem(SS);
}

public function GetSpecialSquad(out Array<AISpawnSquad> out_SquadList)
{
	if (SpecialSquads.Length > 0)
		out_SquadList.AddItem(SpecialSquads[Rand(SpecialSquads.Length)]);
}

public function GetEventSquadList(out Array<AISpawnSquad> out_SquadList)
{
	local AISpawnSquad SS;

	out_SquadList.Length = 0;
	foreach EventSquads(SS)
		if (SS != None)
			out_SquadList.AddItem(SS);
}

public function InitFrom(KFAIWaveInfo WaveInfo)
{
	local KFAISpawnSquad KFSS;
	
	bRecycleWave = WaveInfo.bRecycleWave;
	MaxAI        = WaveInfo.MaxAI;
	
	Squads.Length = 0;
	foreach WaveInfo.Squads(KFSS)
		Squads.AddItem(class'AISpawnSquad'.static.CreateFrom(KFSS));
	
	SpecialSquads.Length = 0;
	foreach WaveInfo.SpecialSquads(KFSS)
		SpecialSquads.AddItem(class'AISpawnSquad'.static.CreateFrom(KFSS));
	
	EventSquads.Length = 0;
	foreach WaveInfo.EventSquads(KFSS)
		EventSquads.AddItem(class'AISpawnSquad'.static.CreateFrom(KFSS));
}

public static function AIWaveInfo CreateFrom(KFAIWaveInfo WaveInfo)
{
	local AIWaveInfo AIWI;
	
	AIWI = new class'AIWaveInfo';
	AIWI.InitFrom(WaveInfo);
	
	return AIWI;
}

defaultproperties
{
	bRecycleWave = true
	MaxAI = 32
}
