class ZedSpawnerMut extends KFMutator
	dependson(ZedSpawner);
	
var private ZedSpawner ZS;

public event PreBeginPlay()
{
	Super.PreBeginPlay();
	
	if (WorldInfo.NetMode == NM_Client) return;
	
	foreach WorldInfo.DynamicActors(class'ZedSpawner', ZS)
	{
		`Log_Base("Found 'ZedSpawner'");
		break;
	}
	
	if (ZS == None)
	{
		`Log_Base("Spawn 'ZedSpawner'");
		ZS = WorldInfo.Spawn(class'ZedSpawner');
	}
	
	if (ZS == None)
	{
		`Log_Base("Can't Spawn 'ZedSpawner', Destroy...");
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

public function NotifyLogin(Controller C)
{
	Super.NotifyLogin(C);
	
	ZS.NotifyLogin(C);
}

public function NotifyLogout(Controller C)
{
	Super.NotifyLogout(C);
	
	ZS.NotifyLogout(C);
}

DefaultProperties
{

}