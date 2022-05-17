class KFGI_Access extends Object
	within KFGameInfo;

public function bool IsCustomZed(class<KFPawn_Monster> KFPM)
{
	if (AIClassList.Find(KFPM)         != INDEX_NONE) return false;
	if (NonSpawnAIClassList.Find(KFPM) != INDEX_NONE) return false;
	if (AIBossClassList.Find(KFPM)     != INDEX_NONE) return false;
	return true;
}

// WARN: <optional out> - can it work? need check
public function bool IsOriginalAI(class<KFPawn_Monster> KFPM, optional out EAIType AIType)
{
	local int Type;
	
	Type = AIClassList.Find(KFPM);
	if (Type != INDEX_NONE)
	{
		AIType = EAIType(Type);
		return true;
	}
	
	return false;
}

public function bool IsOriginalAIBoss(class<KFPawn_Monster> KFPM, optional out EBossAIType AIType)
{
	local int Type;
	
	Type = AIBossClassList.Find(KFPM);
	if (Type != INDEX_NONE)
	{
		AIType = EBossAIType(Type);
		return true;
	}
	
	return false;
}

public function class<KFPawn_Monster> AITypePawn(EAIType AIType)
{
	if (AIType < AIClassList.Length)
		return AIClassList[AIType];
	else
		return None;
}

public function class<KFPawn_Monster> BossAITypePawn(EBossAIType AIType)
{
	if (AIType < AIBossClassList.Length)
		return AIBossClassList[AIType];
	else
		return None;
}

defaultproperties
{
	
}
