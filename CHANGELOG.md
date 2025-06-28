# Changelog

## v1.4.1 (2024-03-08)
- improved compatibility with StartWave and CD chokepoints
- added a short alias for the mutator: ZedSpawner.Mut (ZedSpawner.ZedSpawnerMut is still available for use)

## v1.4.0 (2022-10-13)
- add preload content options to config

## v1.3.2 (2022-09-13)
- fix destroy player repinfo
- update build tools

## v1.3.1 (2022-08-30)
- update code arch a little

## v1.3.0 (2022-07-13)
- feature: "bSmoothSpawn" (one zed spawn per second)
- refactoring

## v1.2.0 (2022-06-13)
- now the type of unit affects the choice of spawn location
- bSpawnAtPlayerStart removed from spawn list
- SpawnAtPlayerStart can be set separately for specified maps or zed classes
- optimized spawn list loading
- added handling of the situation when the player leaves the game before preloadcontent synchronization ends
- fixed calculation of the number of zeds in some cases

## v1.1.0 (2022-06-06)
- add spawner tickrate setting

## v1.0.4 (2022-06-05)
- fixed possible division by zero when rounding

## v1.0.3 (2022-06-01)
- fixed spawn when all spawn volumes are busy
- refactoring (removed obsolete code, improved readability)
- improved logging

## v1.0.2 (2022-05-31)
- fixed unnecessary spawn after stopping the spawn cycle
- fixed missing spawn on the boss wave
- fixed remaining zed counter
- fixed unnecessary restart of spawn after stopping the spawn cycle
- optimized spawn cycle for large spawn lists

## v1.0.1 (2022-05-23)
- remove incorrect wave0 from default regular spawn list

## v1.0.0 (2022-05-22)
- first version
