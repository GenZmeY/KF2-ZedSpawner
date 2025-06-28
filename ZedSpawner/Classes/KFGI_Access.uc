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
