# This mod is a WIP.
This mod allows you to implement your own custom weapon for L4D2 without overriding an existing weapon script.  
Compiling requires [thelpers](https://github.com/voided/sourcemod-transitional-helpers).
### Issues:
- Currently, in order to make the viewmodel and HUD icons fully functional for a client it REQUIRES them manually acquiring the "weapon_csbase_gun.txt" file, which can be done via a workshop mod or just downloading it normally. This unfortunately does not seem to have any workaround that I'm able to find as of yet; without the client having the file:
  - their viewmodel will lack arms
  - they will have no weapon icon on their hud's loadout display
  - the model will occassionally bug out for a split second (tied to `m_flTimeWeaponIdle` being refreshed)
  - trying to reload while full causes viewmodel anim prediction errors until reload button is let go
- TODO:
  - Accuracy stats are not implemented.
  - Penetration and penetration stats are not implemented.
  - Special ammo (incendiary/explosive) is not implemented.
  - All client side impact effects (blood splatter on hitting player/infected, bullet impact + decal on hitting world/prop) are not implemented.
  - Possibly more things not implemented that I haven't thought about.