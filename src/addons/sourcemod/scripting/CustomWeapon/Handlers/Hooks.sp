#include <sourcemod>
#tryinclude "Helpers.sp" // the linter i use is jank and stupid, please ignore this

//! EXPLOSIVE RADIUS FOR BULLETS: 95
//! EXPLOSIVE RADIUS FOR SHOTGUNS: 175

//! SURVIVOR BLOOD SPLATTER:
  // blood_impact_red_01_goop: Age:   0.04, NumActive:   1, Bounds Center: (-761.92,3019.19,381.14) (0x08AB2410)
  // blood_impact_red_01_chunk: Age:   0.04, NumActive:  22, Bounds Center: (-748.64,3026.55,381.88) (0x09026C10)
  // blood_impact_survivor_01: Age:   0.04, NumActive:   1, Bounds Center: (-757.24,3022.80,381.35) (0x07698C20)

//! INFECTED BLOOD SPLATTER:
  // blood_impact_red_01_goop: Age:   0.26, NumActive:   1, Bounds Center: (-860.64,3193.64,367.17) (0x08235C10)
  // blood_impact_red_01_goop_backspray: Age:   0.26, NumActive:   1, Bounds Center: (-863.74,3137.93,360.91) (0x08F56410)
  // blood_impact_infected_01_cheap: Age:   0.26, NumActive:   1, Bounds Center: (-863.58,3165.79,366.34) (0x08893020)

#define UPGRADE_INCEN 1
#define UPGRADE_EXPLO 2
#define UPGRADE_LASER 4
#define NEW_UPGRADE_BITVEC "m_Gender" //! this is what we're using instead of "m_upgradeBitVec" since we don't have it

// TODO: ADD LOCATION BASED DAMAGE
static float CalcDamage(float dist, int hitbox, bool friendlyFire = false)
{
  if (dist > OurInfo.Range)
  {
    return 0.0;
  }

  float ret = OurInfo.Damage * Pow(OurInfo.RangeMod, (1.0 - OurInfo.RangeMod) * (dist / 500.0));

  if (OurInfo.RangeGain && dist > OurInfo.RangeGain)
  {
    ret = Min(ret, ret / ((dist - OurInfo.RangeGain) * (OurInfo.RangeGain / OurInfo.Range)) );
  }

  float ffReduction = GetFFReduction();

  return friendlyFire ? Max(ffReduction != 0.0 ? 1.0 : 0.0, ret * ffReduction) : ret;
}

MRESReturn Primmy(int _thisRaw)
{
  CBaseCombatWeapon _this = view_as<CBaseCombatWeapon>(_thisRaw);

  int currentClip = _this.GetProp(Prop_Send, "m_iClip1");
  if (currentClip <= 0)
  {
    _this.SetProp(Prop_Send, "m_iClip1", 0);
    _this.SetProp(Prop_Data, "m_bFireOnEmpty", 1);
    SDKCall(Call_Reload, _thisRaw);
    return MRES_Supercede;
  }

  _this.SetPropFloat(Prop_Send, "m_flTimeAttackQueued", GetGameTime());
  _this.SetPropFloat(Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + OurInfo.CycleTime);
  SDKCall(Call_SendWepAnim, _thisRaw, 1252); // ACT_VM_PRIMARYATTACK_LAYER

  bool isUsingIncenAmmo = false; //! TODO
  EmitSoundToAll(isUsingIncenAmmo ? OurInfo.FireSounds.Incen.FileName : OurInfo.FireSounds.Normal.FileName, _this.OwnerEntity.Index);
  _this.SetProp(Prop_Send, "m_iClip1", currentClip - 1);

  for (int i = 0; i < OurInfo.Bullets; i++)
  {
    FireWep(VA_Plr(_this.OwnerEntity));
  }

  return MRES_Handled;
}

static void FireWep(CBasePlayer client)
{
  float eyePos[3];
  float eyeAngs[3];

  client.GetEyePosition(eyePos);
  client.GetEyeAngles(eyeAngs);
  TR_TraceRayFilter(eyePos, eyeAngs, MASK_SHOT, RayType_Infinite, noSelf, client.Index);
  int targ = TR_GetEntityIndex();
  float targPos[3];
  TR_GetEndPosition(targPos);

  bool friendlyFire = targ > 0 && targ <= MaxClients && client.Team == VA_Plr(targ).Team;

  float dmg = CalcDamage(GetVectorDistance(eyePos, targPos), TR_GetHitBoxIndex(), friendlyFire);

  SDKHooks_TakeDamage(targ, client.Index, client.Index, dmg, DMG_BULLET, -1, NULL_VECTOR, eyePos, false);

  // DoEffects(client, targ, targPos, TR_GetHitBoxIndex(), friendlyFire);
}

Action OnFire(Event event, const char[] name, bool dontBroadcast)
{
  char weapon[128];
  event.GetString("weapon", weapon, sizeof(weapon));

#if DEBUG
  int client = GetClientOfUserId(event.GetInt("userid"));
  CBaseCombatWeapon wep = VA_Plr(client).ActiveWeapon;
  if (!IsFakeClient(client) && (!wep.HasProp(Prop_Send, "m_upgradeBitVec") || wep.GetProp(Prop_Send, "m_upgradeBitVec")))
  {
    GetEntityNetClass(wep.Index, weapon, sizeof(weapon));
    char props[3][128];
    props[0] = "m_iClip1";
    props[1] = "m_nUpgradedPrimaryAmmoLoaded";
    props[2] = "m_iExtraPrimaryAmmo";
    int safeBitVec = LoadFromAddress(GetEntityAddress(wep.Index) + view_as<Address>(6112), NumberType_Int8);
    PrintToChatAllLog("\n\n~=%d: \n%s: %d \n%s: %d \n%s: %d \nupgradeBitVec: %d~=", \
                      wep.Index, \
                      props[0], wep.GetProp(Prop_Send, props[0]), props[1], wep.GetProp(Prop_Send, props[1]), \
                      props[2], wep.GetProp(Prop_Send, props[2]), safeBitVec);
  }
#endif

  // for some reason this event gives the proper classname (CWeaponCSBaseGun) rather than the normal "weapon_[...]" style classname
  if (!strncmp(weapon[7], "CSBaseGun", 9))
  {
    event.SetInt("weaponid", 23);
    event.SetInt("count", OurInfo.Bullets);
    return Plugin_Changed;
  }

  return Plugin_Continue;
}

void OnUse(Event event, const char[] name, bool dontBroadcast)
{
  CBaseEntity targ = VA_Ent(event.GetInt("targetid"));

  char cName[24];
  targ.GetClassname(cName, sizeof(cName));
  // technically speaking, this can actually get things other than _pack_incendiary/_pack_explosive/_laser_sight, but nothing that you can +use
  if (!!strncmp(cName, "upgrade_", 8))
  {
    return;
  }

  CBasePlayer client = VA_Plr(GetClientOfUserId(event.GetInt("userid")));
  CBaseCombatWeapon wep = client.ActiveWeapon;
  if (GetClientTeam(client.Index) != 2 || !wep.IsValid)
  {
    return;
  }

  char wepName[128];
  wep.GetClassname(wepName, sizeof(wepName));
  if (!!strncmp(wepName, WEP_CLASSNAME, 17) || !strncmp(cName, "upgrade_l", 9)) // todo: implement laser
  {
    return;
  }

  int upgrades = wep.GetProp(Prop_Send, NEW_UPGRADE_BITVEC);
  int newUpgrade = !strncmp(cName[13], "incendiary", 10) ? UPGRADE_INCEN : UPGRADE_EXPLO;

  if (upgrades & newUpgrade)
  {
    return;
  }

  wep.SetProp(Prop_Send, NEW_UPGRADE_BITVEC, upgrades | newUpgrade);
  wep.SetProp(Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", OurInfo.ClipSize);

  int count = targ.GetProp(Prop_Data, "m_itemCount");
  targ.SetProp(Prop_Data, "m_itemCount", --count);
  if (count <= 0) // fun fact: valve does "== 0" for this, so you can break this easily through changing this value lol
  {
    RemoveEntity(targ.Index);
  }

  Event upgrade = CreateEvent("receive_upgrade");
  upgrade.SetInt("userid", client.UserID);
  upgrade.SetString("upgrade", newUpgrade == UPGRADE_INCEN ? "INCENDIARY_AMMO" : "EXPLOSIVE_AMMO");
  upgrade.Fire();

  upgrade = CreateEvent("upgrade_pack_added");
  upgrade.SetInt("userid", client.UserID);
  upgrade.SetInt("upgradeid", targ.Index);
  upgrade.Fire();
}

// #region DoEffects testing
// #if DEBUG
//   char nameAndInfo[12800];

//   static void timeup(Handle time)
//   {
//     PrintToChatAllLog(nameAndInfo);
//   }
//   Action spla(const char[] name, const int[] players, int playerCount, float delay)
//   {
//     float floats[9];
//     int floatCount = -1;
//     floats[++floatCount] = TE_ReadFloat("m_vOrigin.x");
//     floats[++floatCount] = TE_ReadFloat("m_vOrigin.y");
//     floats[++floatCount] = TE_ReadFloat("m_vOrigin.z");
//     floats[++floatCount] = TE_ReadFloat("m_vStart.x");
//     floats[++floatCount] = TE_ReadFloat("m_vStart.y");
//     floats[++floatCount] = TE_ReadFloat("m_vStart.z");
//     floats[++floatCount] = TE_ReadFloat("m_flScale");
//     floats[++floatCount] = TE_ReadFloat("m_flMagnitude");
//     floats[++floatCount] = TE_ReadFloat("m_flRadius");
//     float v[3];
//     TE_ReadVector("m_vAngles", v);
//     int ints[8];
//     int intCount = -1;
//     ints[++intCount] = TE_ReadNum("entindex");
//     ints[++intCount] = TE_ReadNum("m_nHitBox");
//     ints[++intCount] = TE_ReadNum("m_nMaterial");
//     ints[++intCount] = TE_ReadNum("m_iEffectName");
//     ints[++intCount] = TE_ReadNum("m_nColor");
//     ints[++intCount] = TE_ReadNum("m_nDamageType");
//     ints[++intCount] = TE_ReadNum("m_nSurfaceProp");
//     ints[++intCount] = TE_ReadNum("m_fFlags");

//     static char ugh[2][9][20] =
//     {
//       {
//         "m_vOrigin.x",
//         "m_vOrigin.y",
//         "m_vOrigin.z",
//         "m_vStart.x",
//         "m_vStart.y",
//         "m_vStart.z",
//         "m_flScale",
//         "m_flMagnitude",
//         "m_flRadius"
//       },
//       {
//         "entindex",
//         "m_nHitBox",
//         "m_nMaterial",
//         "m_iEffectName",
//         "m_nColor",
//         "m_nDamageType",
//         "m_nSurfaceProp",
//         "m_fFlags",
//         ""
//       }
//     };

//     for (int i = 0; i < floatCount; i++)
//     {
//       Format(nameAndInfo, sizeof(nameAndInfo), "%s%s: %.3f \n", nameAndInfo, ugh[0][i], floats[i]);
//     }
//     Format(nameAndInfo, sizeof(nameAndInfo), "%s%s: %.3f %.3f %.3f \n", nameAndInfo, "m_vAngles", v[0], v[1], v[2]);
//     for (int i = 0; i < intCount; i++)
//     {
//       Format(nameAndInfo, sizeof(nameAndInfo), "%s%s: %.3f \n", nameAndInfo, ugh[1][i], ints[i]);
//     }

//     CreateTimer(0.1, timeup);

//     return Plugin_Continue;
//   }
// #endif

// static void DoEffects(CBasePlayer client, int targ, const float pos[3], int hitbox, bool friendlyFire)
// {
//   float ourEyes[3];
//   client.GetEyePosition(ourEyes);

//   float ourDir[3];
//   MakeVectorFromPoints(ourEyes, pos, ourDir);
//   GetVectorAngles(ourDir, ourDir);

//   // TE_Start("EffectDispatch");
//   // TE_WriteFloat("m_vOrigin.x", ourEyes[0]);
//   // TE_WriteFloat("m_vOrigin.y", ourEyes[1]);
//   // TE_WriteFloat("m_vOrigin.z", ourEyes[2]);
//   // TE_WriteFloat("m_vStart.x", pos[0]);
//   // TE_WriteFloat("m_vStart.y", pos[1]);
//   // TE_WriteFloat("m_vStart.z", pos[2]);
//   // TE_WriteFloat("m_flScale", 1.0);
//   // TE_WriteFloat("m_flMagnitude", 1.0);
//   // TE_WriteAngles("m_vAngles", ourDir);
//   // TE_WriteNum("entindex", targ);
//   // TE_WriteNum("m_nHitBox", hitbox);
//   // // blood_impact_red_01
//   // TE_WriteNum("m_nMaterial", PrecacheDecal("particle/smoke1/smoke1.vtf"));
//   // TE_WriteNum("m_iEffectName", 28);
//   // TE_WriteFloat("m_flRadius", 175.0);

//   TE_Start("Impact");
//   TE_WriteVector("m_vecOrigin", pos);
//   TE_WriteVector("m_vecNormal", { 0.0, 0.0, 1.0 });
//   TE_WriteNum("m_iType", 1);

//   TE_SendToClient(client.Index);
// }
// #endregion