class ZedSpawnerRepInfo extends ReplicationInfo;

var public  ZedSpawner ZS;
var public  E_LogLevel LogLevel;
var public  Array<class<KFPawn_Monster> > CustomZeds;
var private int Recieved;

replication
{
	if (bNetInitial && Role == ROLE_Authority)
		LogLevel;
}

public simulated function bool SafeDestroy()
{
	return (bPendingDelete || bDeleteMe || Destroy());
}

public reliable client function ClientSync(class<KFPawn_Monster> CustomZed)
{
	`Log_Trace();

	`Log_Debug("Received:" @ CustomZed);
	CustomZeds.AddItem(CustomZed);
	ServerSync();
}

public reliable client function SyncFinished()
{
	local class<KFPawn_Monster> CustomZed;

	`Log_Trace();

	foreach CustomZeds(CustomZed)
	{
		`Log_Debug("Preload Content for" @ CustomZed);
		CustomZed.static.PreloadContent();
	}

	SafeDestroy();
}

public reliable server function ServerSync()
{
	`Log_Trace();

	if (bPendingDelete || bDeleteMe) return;

	if (CustomZeds.Length == Recieved || WorldInfo.NetMode == NM_StandAlone)
	{
		`Log_Debug("Sync finished");
		SyncFinished();
		if (!ZS.DestroyRepInfo(Controller(Owner)))
		{
			SafeDestroy();
		}
	}
	else
	{
		`Log_Debug("Sync:" @ CustomZeds[Recieved]);
		ClientSync(CustomZeds[Recieved++]);
	}
}

defaultproperties
{
	bAlwaysRelevant               = false;
	bOnlyRelevantToOwner          = true;
	bSkipActorPropertyReplication = false;

	Recieved = 0
}
