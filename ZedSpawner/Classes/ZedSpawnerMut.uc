class ZedSpawnerMut extends KFMutator
	dependson(ZedSpawner);
	
var private ZedSpawner ZS;

public event PreBeginPlay()
{
	Super.PreBeginPlay();
	
	if (WorldInfo.NetMode == NM_Client) return;
	
	foreach WorldInfo.DynamicActors(class'ZedSpawner', ZS)
	{
		break;
	}
	
	if (ZS == None)
	{
		ZS = WorldInfo.Spawn(class'ZedSpawner');
	}
	
	if (ZS == None)
	{
		`Log_Base("FATAL: Can't Spawn 'ZedSpawner'");
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
	ZS.NotifyLogin(C);
	
	Super.NotifyLogin(C);
}

public function NotifyLogout(Controller C)
{
	ZS.NotifyLogout(C);
	
	Super.NotifyLogout(C);
}

DefaultProperties
{

}