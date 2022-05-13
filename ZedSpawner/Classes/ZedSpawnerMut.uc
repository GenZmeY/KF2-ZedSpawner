class ZedSpawnerMut extends KFMutator
	dependson(ZedSpawner);
	
var private ZedSpawner ZS;

event PreBeginPlay()
{
    Super.PreBeginPlay();
	
	if (WorldInfo.NetMode == NM_Client) return;
	
	foreach WorldInfo.DynamicActors(class'ZedSpawner', ZS)
	{
		`ZS_Log("Found 'ZedSpawner'");
		break;
	}
	
	if (ZS == None)
	{
		`ZS_Log("Spawn 'ZedSpawner'");
		ZS = WorldInfo.Spawn(class'ZedSpawner');
	}
	
	if (ZS == None)
	{
		`ZS_Log("Can't Spawn 'ZedSpawner', Destroy...");
		Destroy();
	}
}

public function AddMutator(Mutator Mut)
{
	if (Mut == Self) return;
	
	if (Mut.Class == Class)
		Mut.Destroy();
	else
		Super.AddMutator(Mut);
}

function NotifyLogin(Controller C)
{
	Super.NotifyLogin(C);
	
	ZS.NotifyLogin(C);
}

function NotifyLogout(Controller C)
{
	Super.NotifyLogout(C);
	
	ZS.NotifyLogout(C);
}

DefaultProperties
{

}