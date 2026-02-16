#include <sourcemod>

#define KEY_SOUND_NORMAL_FIRE  "single_shot"
// #define KEY_SOUND_DUALIES_FIRE "double_shot"
#define KEY_SOUND_INCEN_FIRE   "shoot_incendiary"

enum struct SoundInfo_t
{
  char FileName[PLATFORM_MAX_PATH]; // only supports one file for now
  float Volume;
  int Level;
  int Channel;
  int Pitch;
}

enum struct FireSounds_t
{
  SoundInfo_t Normal;
  // SoundInfo_t NormalDualies;
  SoundInfo_t Incen;
}

enum struct WepInfo_t
{
  int    Damage;
  int    Bullets;
  float  Range;
  float  RangeGain;
  float  RangeMod;
  float  CycleTime;
  FireSounds_t FireSounds;
}

stock WepInfo_t LoadWeaponFile(const char[] fileName = "scripts\\weapon_csbase_gun.txt")
{
  File file = OpenFile(fileName, "r", true);
  char fileData[10000];
  file.ReadString(fileData, sizeof(fileData));
  delete file;

  KeyValues wepFileKV = CreateKeyValues("OurWep");
  StringToKeyValues(wepFileKV, fileData);

  // defaults are pulled from reversed CTerrorWeaponInfo::Parse
  WepInfo_t ret;
  ret.Damage    = wepFileKV.GetNum("Damage");
  ret.Bullets   = wepFileKV.GetNum("Bullets");
  ret.Range     = wepFileKV.GetFloat("Range", 8192.0);
  ret.RangeGain = wepFileKV.GetFloat("GainRange");
  ret.RangeMod  = wepFileKV.GetFloat("RangeModifier", 0.98);
  ret.CycleTime = wepFileKV.GetFloat("CycleTime", 0.15);

  wepFileKV.JumpToKey("SoundData");
  wepFileKV.GotoFirstSubKey();

  char name[300];
  wepFileKV.GetSectionName(name, sizeof(name));

  bool atLeastOneKey = !!strncmp(name, "SoundData", 9);

  // this means that an entry is itself a KV of data and NOT just a filepath
  if (atLeastOneKey)
  {
    ret.FireSounds = GetScriptSoundInfo(wepFileKV);
  }

  if (!strlen(ret.FireSounds.Normal.FileName))
  {
    ret.FireSounds.Normal = GetSoundDefaults();
    wepFileKV.GetString(KEY_SOUND_NORMAL_FIRE, ret.FireSounds.Normal.FileName, PLATFORM_MAX_PATH, "common/null.wav");
  }

  if (!strlen(ret.FireSounds.Incen.FileName))
  {
    ret.FireSounds.Incen = GetSoundDefaults();
    wepFileKV.GetString(KEY_SOUND_INCEN_FIRE, ret.FireSounds.Incen.FileName, PLATFORM_MAX_PATH, "common/null.wav");
  }

  delete wepFileKV;

  PrecacheSound(ret.FireSounds.Normal.FileName);
  PrecacheSound(ret.FireSounds.Incen.FileName);

  return ret;
}

static FireSounds_t GetScriptSoundInfo(KeyValues& kv)
{
  FireSounds_t ret;

  do
  {
    SoundInfo_t info;

    kv.GetString("wave", info.FileName, sizeof(info.FileName), "common/null.wav");
    info.Volume  = kv.GetFloat("volume", 1.0);
    info.Level   = kv.GetNum("level", SNDLEVEL_NONE);
    info.Channel = kv.GetNum("channel", SNDCHAN_WEAPON);
    info.Pitch   = kv.GetNum("pitch", SNDPITCH_NORMAL);

    char sectionName[300];
    kv.GetSectionName(sectionName, sizeof(sectionName));

    //! TODO: MAKE SURE TO ALSO LOOK FOR "double_shot"
    if (!strncmp(sectionName, KEY_SOUND_NORMAL_FIRE, 11))
    {
      ret.Normal = info;
    }
    else if (!strncmp(sectionName, KEY_SOUND_INCEN_FIRE, 16))
    {
      ret.Incen = info;
    }
  } while (kv.GotoNextKey());

  kv.GoBack();

  return ret;
}

static SoundInfo_t GetSoundDefaults()
{
  SoundInfo_t ret;
  ret.Volume  = 1.0;
  ret.Level   = SNDLEVEL_NONE;
  ret.Channel = SNDCHAN_WEAPON;
  ret.Pitch   = SNDPITCH_NORMAL;
  return ret;
}

static float GetFFReduction()
{
  char diff[11];
  GetConVarString(FindConVar("z_difficulty"), diff, sizeof(diff));
  ReplaceString(diff, sizeof(diff), "Impossible", "expert");

  char factorCVar[40];
  Format(factorCVar, sizeof(factorCVar), "survivor_friendly_fire_factor_%c%s", CharToLower(diff[0]), diff[1]);
  return GetConVarFloat(FindConVar(factorCVar));
}

static float MaxF(float val, float val2)
{
  return val >= val2 ? val : val2;
}

static float MinF(float val, float val2)
{
  return val <= val2 ? val : val2;
}

stock float CalcDamage(float dist, int hitbox, bool friendlyFire = false)
{
  if (dist > OurInfo.Range)
  {
    return 0.0;
  }

  float ret = OurInfo.Damage * Pow(OurInfo.RangeMod, (1.0 - OurInfo.RangeMod) * (dist / 500.0));

  if (OurInfo.RangeGain && dist > OurInfo.RangeGain)
  {
    ret = MinF(ret, ret / ((dist - OurInfo.RangeGain) * (OurInfo.RangeGain / OurInfo.Range)) );
  }

  return friendlyFire ? MaxF(1.0, ret * GetFFReduction()) : ret;
}