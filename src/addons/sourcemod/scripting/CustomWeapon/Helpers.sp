#include <sourcemod>

#define DEFAULT_DEBUG 1
#tryinclude <SetupDebugMacros.sp>

#define WEP_CLASSNAME "weapon_csbase_gun"
#define VA_Plr(%1) view_as<CBasePlayer>(%1)
#define VA_Ent(%1) view_as<CBaseEntity>(%1)

// #region one-liners
stock bool noSelf(int ent, int mask, int hit)
{
  return hit != ent;
}

stock any Max(any val, any val2)
{
  return val >= val2 ? val : val2;
}

stock any Min(any val, any val2)
{
  return val <= val2 ? val : val2;
}
// #endregion

stock float GetFFReduction()
{
  char diff[11];
  GetConVarString(FindConVar("z_difficulty"), diff, sizeof(diff));
  ReplaceString(diff, sizeof(diff), "Impossible", "expert");

  char factorCVar[40];
  Format(factorCVar, sizeof(factorCVar), "survivor_friendly_fire_factor_%c%s", CharToLower(diff[0]), diff[1]);
  return GetConVarFloat(FindConVar(factorCVar));
}