class AISpawnSquad extends Object
	hidecategories(Object);

struct S_AISquadElement
{
	var() EAIType Type;
	var() byte    Num <ClampMin=1 | ClampMax=6>;

	var class<KFPawn_Monster> CustomClass;

	structdefaultproperties
	{
		Num = 1
	}
};

var() ESquadType              MinVolumeType;
var() array<S_AISquadElement> MonsterList;

public function AISpawnSquad InitFrom(KFAISpawnSquad SpawnSquad)
{
	local AISquadElement SE;
	local S_AISquadElement SSE;
	
	MinVolumeType = SpawnSquad.MinVolumeType;
	
	foreach SpawnSquad.MonsterList(SE)
	{
		SSE.Type        = SE.Type;
		SSE.Num         = SE.Num;
		SSE.CustomClass = SE.CustomClass;
		MonsterList.AddItem(SSE);
	}
	
	return Self;
}

public static function AISpawnSquad CreateFrom(KFAISpawnSquad SpawnSquad)
{
	local AISquadElement SE;
	local S_AISquadElement SSE;
	local AISpawnSquad NewSpawnSquad;
	
	NewSpawnSquad = new class'AISpawnSquad';
	NewSpawnSquad.MinVolumeType = SpawnSquad.MinVolumeType;
	
	foreach SpawnSquad.MonsterList(SE)
	{
		SSE.Type        = SE.Type;
		SSE.Num         = SE.Num;
		SSE.CustomClass = SE.CustomClass;
		NewSpawnSquad.MonsterList.AddItem(SSE);
	}
	
	return NewSpawnSquad;
}

defaultproperties
{
	MinVolumeType = EST_Medium
}
