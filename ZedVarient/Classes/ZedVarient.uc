class ZedVarient extends KFMutator
	config(ZedVarient);
 
//Timer rate
var const float dt;
   
//User out cfg
struct TZedCfg
{
	var int Wave;
	var int SpawnAtOnce;
	var int SpawnsDone;
	var int MaxSpawns;
	var int Spawnsleft;
	var string Zed;
	var float Probability;
	var float Delay;
};
 
//Mut inner cfg
struct TZedCfgTmp
{
	var int Wave;
	var int SpawnAtOnce;
	var class<KFPawn_Monster> Zed;
	var float Probability;
	var float DefDelay;
	var float Delay;
	var int SpawnsDone;
	var int MaxSpawns;
	var int SpawnsLeft;
};
   
var config float ZedMultiplier;
var config bool bConfigsInit;
var config array<TZedCfg> CustomZeds;
var config array<string> Bosses;
 
var array< class<KFPawn_Monster> > LoadedBosses;
var array< TZedCfgTmp > LoadedCustomZeds;
var KFGameInfo_Survival KFGT;
var int cwave;
var array<KFPawn_Monster> UZBosses;
var bool bFB;
var KFPawn_Monster OriginalBoss;
var int BossesLeft;
//Dunno how to properly calculate using original stuff
var int NeedMoreZeds;
var int MaxSpawns;
var int SpawnsLeft;
var int SpawnsDone;

function PostBeginPlay()
{
	local int i;
	local class<KFPawn_Monster> C;
	local TZedCfgTmp zct;
   
	for(i=0;i<Bosses.Length;i++)
	{
		C = class<KFPawn_Monster>(DynamicLoadObject(Bosses[i],Class'Class'));
	   
		if(C!=None)
			LoadedBosses.AddItem(C);
		else
			LogInternal("Error while loading"@Bosses[i]);
	}
   
	if(!bConfigsInit)
	{
		bConfigsInit = true;
		ZedMultiplier = 1.0;
		SaveConfig();
	}
   
	cwave=-1;
	KFGT = KFGameInfo_Survival(WorldInfo.Game);
   
	//Init inner cfg
	for(i=0;i<CustomZeds.Length;i++)
	{	  
		C = class<KFPawn_Monster>(DynamicLoadObject(CustomZeds[i].Zed,Class'Class'));
	   
		if(C!=None && CustomZeds[i].Wave>0 && CustomZeds[i].SpawnAtOnce>0 && CustomZeds[i].Probability>0 && CustomZeds[i].Delay>0 && CustomZeds[i].MaxSpawns>0)
		{
			LogInternal("LOADED"@CustomZeds[i].Zed);
			zct.Wave = CustomZeds[i].Wave;
			zct.SpawnAtOnce = CustomZeds[i].SpawnAtOnce;
			zct.Probability = CustomZeds[i].Probability;		   
			zct.DefDelay = CustomZeds[i].Delay;
			zct.Delay = CustomZeds[i].Delay;
			zct.MaxSpawns = CustomZeds[i].MaxSpawns;
			zct.SpawnsLeft = CustomZeds[i].MaxSpawns - CustomZeds[i].SpawnsDone;
			zct.Zed = C;
			LoadedCustomZeds.AddItem(zct);
		}
		else	   
			LogInternal("Error while loading"@CustomZeds[i].Zed);	  
	}
   
	SetTimer(dt,true);
}
 
function Timer()
{
	//setup total amount multiplier
	if(cwave<KFGT.WaveNum && KFGT.WaveNum!=KFGT.WaveMax)
	{
		cwave=KFGT.WaveNum;
		KFGT.SpawnManager.WaveTotalAI*=ZedMultiplier;
		KFGT.MyKFGRI.WaveTotalAICount = KFGT.SpawnManager.WaveTotalAI;
		KFGT.MyKFGRI.AIRemaining = KFGT.SpawnManager.WaveTotalAI;  
		NeedMoreZeds=KFGT.SpawnManager.WaveTotalAI;
	}
   
	SpawnCustomZeds();
	KFGT.RefreshMonsterAliveCount();
}
 
function SpawnCustomZeds()
{
	local int i, j;
	local array< class<KFPawn_Monster> > CSquad;
	local KFSpawnVolume KFSV;

	KFSV = KFGT.SpawnManager.GetBestSpawnVolume(CSquad);

	if( !KFGT.IsWaveActive() || NeedMoreZeds<=0 || KFGT.AIAliveCount>128 || KFSV.Location==PlayerController(Owner).StartSpot.Location )
		return;  //	Maxmonsters, ????, ?? ???? ?? 	//VSize(KFSV.Location-PlayerController(Owner).Pawn.Location)<650.f //KFSV.bNoCollisionFailForSpawn==true	
		
		for(i=0;i<LoadedCustomZeds.Length;i++)
		{
			if(LoadedCustomZeds[i].Wave==KFGT.WaveNum)
			{
				LoadedCustomZeds[i].Delay-=dt;
			   
				if(LoadedCustomZeds[i].Delay<=0 && LoadedCustomZeds[i].SpawnsLeft>0 && LoadedCustomZeds[i].MaxSpawns>=0 && (LoadedCustomZeds[i].SpawnsDone<LoadedCustomZeds[i].MaxSpawns) )
				{
					LoadedCustomZeds[i].Delay=LoadedCustomZeds[i].DefDelay;
				   
					if(FRand()<=LoadedCustomZeds[i].Probability)
					{
						CSquad.Length=0;
						CSquad.AddItem(LoadedCustomZeds[i].Zed);

						for(j=0;j<LoadedCustomZeds[i].SpawnAtOnce;j++)
						{
							TryToSpawnZed(KFSV.Location,LoadedCustomZeds[i].Zed);
							LoadedCustomZeds[i].SpawnsDone++;
						}
					}
				}
			}
		}
}

function TryToSpawnZed( vector L, class<KFPawn_Monster> ZedClass )
{
	local KFPawn_Monster M;
	local Controller C;

	if( ZedClass==class'HL2Monsters.Combine_Strider' || ZedClass==class'HL2Monsters.Combine_Gunship' || ZedClass==class'HL2Monsters.Hunter_Chopper' )
	{
		L = KFGameInfo(WorldInfo.Game).FindPlayerStart(PlayerController(Owner),0).Location;
		L.Y += 64;
		L.Z += 64;
	}
	else L.Z += 10;
	
	M = Spawn(ZedClass,,,L,rot(0,0,1),,true);
  
	if( M==None )
		return;
   
	C = M.Spawn(M.ControllerClass);
	C.Possess(M,false);
	KFGT.MyKFGRI.AIRemaining+=1;	//added
	KFGT.NumAISpawnsQueued++;
	KFGT.AIAliveCount++;
	KFGT.RefreshMonsterAliveCount();
	NeedMoreZeds--;
}
 
//Kill original boss
//function KillOriginalBoss()
//{
//  if(OriginalBoss!=None)
//  {
//	  OriginalBoss.Suicide();
//	  SetTimer(1, false, 'ResetCamera');
//  }
//}
 
//Rollback camera mode
function ResetCamera()
{  
	local KFPlayerController PC;
   
	foreach WorldInfo.AllControllers( class'KFPlayerController', PC )
	{	  
		PC.ServerCamera( 'ThirdPerson' );
		PC.ServerCamera( 'FirstPerson' );
		PC.HideBossNameplate();	
	}
}
 
//Rollback wave number
function ReturnWaveNum()
{
	KFGT.MyKFGRI.WaveNum++;
}
 
//Prevent end game on any but last boss kill
function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> damageType, vector HitLocation)
{
	if(KFGT.WaveNum==KFGT.WaveMax)
	{
		if(UZBosses.Find(KFPawn_Monster(Killed))>=0)
		{
			BossesLeft--;
		}
	   
		if(KFPawn_MonsterBoss(Killed)!=None && BossesLeft>0)
		{		  
			KFGT.MyKFGRI.WaveNum--;
			SetTimer(0.2, false, 'ReturnWaveNum');
		}	  
	}
   
	return (NextMutator != None && NextMutator.PreventDeath(Killed, Killer, damageType, HitLocation));
}
 
function AddMutator(Mutator M)
{
	if( M!=Self )
	{
		if( M.Class==Class )
			M.Destroy();
		else Super.AddMutator(M);
	}
}
 
//Spawn bosses by original boss
//function bool CheckReplacement(Actor Other)
//{
//  local int i, j;
// 
//  if(KFPawn_Monster(Other)!=None)
//	  NeedMoreZeds--;
// 
//  if(KFPawn_MonsterBoss(Other)!=None && !bFB && KFGT.WaveNum==KFGT.WaveMax)
//  {
//	  bFB=true;
//	  OriginalBoss = KFPawn_Monster(Other);
//	  SetTimer(1,false,'KillOriginalBoss');
//	 
//	  for( i=0; i<LoadedBosses.Length;i++)
//	  {
//		  // 10 tries for each zed
//		  for( j=0; j<10; j++ )
//			  if( TryToSpawnBoss(Pawn(Other), LoadedBosses[i]) )
//			  {			  
//				  KFGameInfo_Survival(WorldInfo.Game).MyKFGRI.AIRemaining+=1;
//				  `log("Spawn succeded for"@Bosses[i]);
//				  break;							 
//			  }  
//	  }
//  }
// 
//  return true;
//}
 
//Spawn routine
function bool TryToSpawnBoss( Pawn A, class<KFPawn_Monster> MC )
{
	local vector V;
	local vector E,HL,HN;
	local KFPawn_Monster M;
	local Controller C;
 
	E.X = A.GetCollisionRadius()*0.8;
	E.Y = E.X;
	E.Z = A.GetCollisionHeight()*0.8;
	V=A.Location;
	V.Z+=32; //32
   
	if(FRand()>0.5)
		V.X+= FRand()>0.5 ? 100 : -100;
	else
		V.Y+= FRand()>0.5 ? 100 : -100;
	   
	if( A.Trace(HL,HN,V,A.Location,false,E)!=None )
		V = HL;
   
	M = A.Spawn(MC,,,V,A.Rotation,,true);
	if( M==None )
		return false;
	C = M.Spawn(M.ControllerClass);
	C.Possess(M,false);
	   
	BossesLeft++;	  
	UZBosses.AddItem(M);
	   
	return true;
}

DefaultProperties
{
	dt=1.0f
}
