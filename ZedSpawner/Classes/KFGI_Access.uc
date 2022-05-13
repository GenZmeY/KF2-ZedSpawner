class KFGI_Access extends Object
	within KFGameInfo_Survival;

// Bypass protected modifier for these lists

function bool IsCustomZed(class<KFPawn_Monster> KFPM)
{
	if (AIClassList.Find(KFPM)         != INDEX_NONE) return false;
	if (NonSpawnAIClassList.Find(KFPM) != INDEX_NONE) return false;
	if (AIBossClassList.Find(KFPM)     != INDEX_NONE) return false;
	return true;
}

defaultproperties
{
	
}
