#include <sourcemod>

#define VA_Plr(%1) view_as<CBasePlayer>(%1)
#define VA_Ent(%1) view_as<CBaseEntity>(%1)

stock bool noSelf(int ent, int mask, int hit)
{
  return hit != ent;
}