# GZDoom-Target-Dummy

Target dummy for GZDoom

A target dummy actor for GZDoom that will print the values of damage it receives and the source/inflictor of the attack. Also spawns floating damage numbers.

There are 2 methods of using the dummy:

1. To summon the dummy, type `summon ShootingRangeDummy` in the console. If you want  the dummy to face you upon spawning, type `netevent summonDummy`.
   Either of these options will summon a custom-designed voxel-based target dummy styled after an Imp.

2. Type `netevent summonDummy:<monsterClassName>` to summon a dummy that will look like a specific monster. For example, `netevent summonDummy:Cyberdemon` will summon a dummy that looks like a Cyberdemon. You can use any monster class as long as it's loaded into GZDoom and has valid sprites.

With the second method, the dummy will be less visually detailed, but will provide more information, such as informing you when you've dealt enough damage to kill the monster it's imitating. The dummy will also not take radius damage when it's imitating a boss monster with the NORADIUSDMG flag, like Cyberdemon.
