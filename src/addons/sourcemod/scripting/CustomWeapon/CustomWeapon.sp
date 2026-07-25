#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <sdktools>
#define GAME_L4D2
#include <thelpers>
#tryinclude <PrintToChatAllLog.sp>

public Plugin myinfo =
{
  author = "ijre",
  name = "Custom Weapon",
  description = "Adds a custom weapon creator.",
  version = "0.0.0.1"
}

WepInfo_t OurInfo;

DynamicHook PrimFireHook;
// Handle Call_BaseForceFire;
Handle Call_Reload;
Handle Call_SendWepAnim;

#include "Helpers.sp"
#include "Handlers/WepInfo.sp"

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

  if (!IsDedicatedServer())
  {
    RegConsoleCmd("give csbase_gun", cb);
  }

  HookEvent("weapon_fire", OnFire, EventHookMode_Pre);
  HookEvent("player_use", OnUse);

#if DEBUG
  RegAdminCmd("sm_weptest", Test_Print, ADMFLAG_ROOT);
  RegAdminCmd("sm_weptest_fire", Test_ForcePrimaryFire, ADMFLAG_ROOT);
#endif

  if (LateLoad)
  {
    int ent = -1;
    while ((ent = FindEntityByClassname(ent, WEP_CLASSNAME)) != -1)
    {
      OnEntityCreated(ent, WEP_CLASSNAME);
    }
  }
}

public void OnEntityCreated(int ent, const char[] class)
{
  if (!strncmp(class, WEP_CLASSNAME, 17))
  {
    DHookEntity(PrimFireHook, false, ent, INVALID_FUNCTION, Primmy);
  }
}