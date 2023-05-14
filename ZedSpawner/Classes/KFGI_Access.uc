class KFGI_Access extends Object
	within KFGameInfo;

public function Array<class<KFPawn_Monster> > GetAIClassList(E_LogLevel LogLevel)
{
	local Array<class<KFPawn_Monster> > RV;
	local class<KFPawn_Monster> KFPMC;

	`Log_Trace();

	foreach AIClassList(KFPMC)
		RV.AddItem(KFPMC);

	return RV;
}

public function Array<class<KFPawn_Monster> > GetNonSpawnAIClassList(E_LogLevel LogLevel)
{
	local Array<class<KFPawn_Monster> > RV;
	local class<KFPawn_Monster> KFPMC;

	`Log_Trace();

	foreach NonSpawnAIClassList(KFPMC)
		RV.AddItem(KFPMC);

	return RV;
}

public function Array<class<KFPawn_Monster> > GetAIBossClassList(E_LogLevel LogLevel)
{
	local Array<class<KFPawn_Monster> > RV;
	local class<KFPawn_Monster> KFPMC;

	`Log_Trace();

	foreach AIBossClassList(KFPMC)
		RV.AddItem(KFPMC);

	return RV;
}

public function bool IsCustomZed(class<KFPawn_Monster> KFPM, E_LogLevel LogLevel)
{
	if (AIClassList.Find(KFPM)         != INDEX_NONE) return false;
	if (NonSpawnAIClassList.Find(KFPM) != INDEX_NONE) return false;
	if (AIBossClassList.Find(KFPM)     != INDEX_NONE) return false;
	return true;
}

public function bool IsOriginalAI(class<KFPawn_Monster> KFPM, optional out EAIType AIType, optional E_LogLevel LogLevel = LL_None)
{
	local int Type;

	`Log_Trace();

	Type = AIClassList.Find(KFPM);
	if (Type != INDEX_NONE)
	{
		AIType = EAIType(Type);
		return true;
	}

	return false;
}

public function bool IsOriginalAIBoss(class<KFPawn_Monster> KFPM, optional out EBossAIType AIType, optional E_LogLevel LogLevel = LL_None)
{
	local int Type;

	`Log_Trace();

	Type = AIBossClassList.Find(KFPM);
	if (Type != INDEX_NONE)
	{
		AIType = EBossAIType(Type);
		return true;
	}

	return false;
}

public function class<KFPawn_Monster> AITypePawn(EAIType AIType, E_LogLevel LogLevel)
{
	`Log_Trace();

	if (AIType < AIClassList.Length)
		return AIClassList[AIType];
	else
		return None;
}

public function class<KFPawn_Monster> BossAITypePawn(EBossAIType AIType, E_LogLevel LogLevel)
{
	`Log_Trace();

	if (AIType < AIBossClassList.Length)
		return AIBossClassList[AIType];
	else
		return None;
}

defaultproperties
{

}
