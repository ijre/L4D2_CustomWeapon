#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <sdktools>
#define GAME_L4D2
#include <thelpers>
#tryinclude <PrintToChatAllLog.sp>
#define DEFAULT_DEBUG 1
#tryinclude <SetupDebugMacros.sp>

#include "Helpers.sp"

WepInfo_t OurInfo;
#include "WepInfoHandler.sp"

public Plugin myinfo =
{
  author = "ijre",
  name = "Custom Weapon",
  description = "Adds a custom weapon creator.",
  version = "0.0.0.1"
}

static DynamicHook PrimFireHook;
// static Handle Call_BaseForceFire;
static Handle Call_Reload;
static Handle Call_SendWepAnim;

static bool LateLoad = false;
public APLRes AskPluginLoad2(Handle h, bool late)
{
  LateLoad = late;
  return APLRes_Success;
}

static Action cb(int client, int args) { return Plugin_Continue; }

#if DEBUG
  static Action Test_Print(int client, int args) { return Plugin_Handled; }
  static Action Test_ForcePrimaryFire(int client, int args) { Primmy(GetPlayerWeaponSlot(client, 0)); return Plugin_Handled; }
#endif

public void OnPluginStart()
{
  if (GetEngineVersion() != Engine_Left4Dead2)
  {
    ThrowError("This plugin only works for Left 4 Dead 2.");
  }

  GameData gaming = LoadGameConfigFile("CustomWeapon");

  PrimFireHook = DynamicHook.FromConf(gaming, "PrimFire");

  StartPrepSDKCall(SDKCall_Entity);
  PrepSDKCall_SetFromConf(gaming, SDKConf_Virtual, "Reload");
  Call_Reload = EndPrepSDKCall();

  StartPrepSDKCall(SDKCall_Entity);
  PrepSDKCall_SetFromConf(gaming, SDKConf_Virtual, "SendWeaponAnim");
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
  Call_SendWepAnim = EndPrepSDKCall();

  delete gaming;

  OurInfo = LoadWeaponFile();

  RegConsoleCmd("give csbase_gun", cb);

  HookEvent("weapon_fire", OnFire, EventHookMode_Pre);

#if DEBUG
  RegAdminCmd("sm_weptest", Test_Print, ADMFLAG_ROOT);
  RegAdminCmd("sm_weptest_fire", Test_ForcePrimaryFire, ADMFLAG_ROOT);
#endif

  if (LateLoad)
  {
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, "weapon_csbase_gun")) != -1)
    {
      OnEntityCreated(ent, "weapon_csbase_gun");
    }
  }
}

public void OnEntityCreated(int ent, const char[] class)
{
  if (!strncmp(class, "weapon_csbase_gun", 17))
  {
    DHookEntity(PrimFireHook, false, ent, INVALID_FUNCTION, Primmy);
  }
}

static MRESReturn Primmy(int _thisRaw)
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

  float dmg = CalcDamage(GetVectorDistance(eyePos, targPos), TR_GetHitBoxIndex(),
    targ > 0 && targ <= MaxClients
    ?
    client.Team == VA_Plr(targ).Team
    :
    false);

  SDKHooks_TakeDamage(targ, client.Index, client.Index, dmg, DMG_BULLET, -1, NULL_VECTOR, eyePos, false);
}

static Action OnFire(Event event, const char[] name, bool dontBroadcast)
{
  char weapon[128];
  event.GetString("weapon", weapon, sizeof(weapon));

#if DEBUG
    int client = GetClientOfUserId(event.GetInt("userid"));
    CBaseCombatWeapon wep = view_as<CBaseCombatWeapon>(VA_Plr(client).ActiveWeapon.Index);
    if (!IsFakeClient(client) && (!wep.HasProp(Prop_Send, "m_upgradeBitVec") || wep.GetProp(Prop_Send, "m_upgradeBitVec")))
    {
      GetEntityNetClass(wep.Index, weapon, sizeof(weapon));
      char props[3][128];
      props[0] = "m_iClip1";
      props[1] = "m_nUpgradedPrimaryAmmoLoaded";
      props[2] = "m_iExtraPrimaryAmmo";
      int offs2 = 0;
      int offs1 = FindSendPropInfo(weapon, "m_upgradeBitVec", _, _, offs2);
      int test = LoadFromAddress(GetEntityAddress(wep.Index) + view_as<Address>(6112), NumberType_Int8);
      PrintToChatAllLog("\n\n~=%d: \n%s: %d \n%s: %d \n%s: %d \ntest: %d - offs1: %d, offs2: %d~=", \
                        wep, \
                        props[0], wep.GetProp(Prop_Send, props[0]), props[1], wep.GetProp(Prop_Send, props[1]), \
                        props[2], wep.GetProp(Prop_Send, props[2]), test, offs1, offs2);
    }
#endif

  if (!strncmp(weapon, "csbase_gun", 10))
  {
    event.SetInt("weaponid", 22);
    event.SetInt("count", 1);
    return Plugin_Changed;
  }

  return Plugin_Continue;
}