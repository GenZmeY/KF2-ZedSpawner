class ZedSpawnerRepLink extends ReplicationInfo;

var public E_LogLevel LogLevel;
var public Array<class<KFPawn_Monster> > CustomZeds;
var private int Recieved;

replication
{
	if (bNetInitial && Role == ROLE_Authority)
		LogLevel;
}

public reliable client function ClientSync(class<KFPawn_Monster> CustomZed)
{
	`ZS_Trace(`Location, LogLevel);
	
	`ZS_Debug("Received:" @ CustomZed, LogLevel);
	CustomZeds.AddItem(CustomZed);
	ServerSync();
}

public reliable client function SyncFinished()
{
	local class<KFPawn_Monster> CustomZed;
	
	`ZS_Trace(`Location, LogLevel);
	
	foreach CustomZeds(CustomZed)
	{
		`ZS_Debug("Preload Content for" @ CustomZed, LogLevel);
		CustomZed.static.PreloadContent();
	}
	
	Destroy();
}

public reliable server function ServerSync()
{
	`ZS_Trace(`Location, LogLevel);
	
	if (CustomZeds.Length == Recieved)
	{
		`ZS_Debug("Sync finished", LogLevel);
		SyncFinished();
		Destroy();
	}
	else
	{
		`ZS_Debug("Sync:" @ CustomZeds[Recieved], LogLevel);
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
