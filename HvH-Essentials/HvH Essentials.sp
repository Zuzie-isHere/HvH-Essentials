/**
 * Plugin Name: HvH Essentials
 * Author: Axeline
 * License: MIT
 * Discord: iloveducks_x
 */


#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

// Define HITGROUP_HEAD
#define HITGROUP_HEAD 1

#define ITEM_NAME_LEN 32
#define CS_SLOT_KNIFE 2

// Define the weapons for each team
#define TERRORIST_ITEMS "weapon_ak47;item_assaultsuit;weapon_deagle"
#define COUNTER_TERRORIST_ITEMS "weapon_ak47;item_assaultsuit;weapon_deagle"

// Define properties
#define OFFSET_AMMO 0
#define OFFSET_HEGRENADE 11
#define OFFSET_FLASHBANG 12
#define OFFSET_SMOKE 13

new VelocityOffset_0, VelocityOffset_1, BaseVelocityOffset;
new Handle:cvarJumpBoost;

// Global variable for "only head" mode
bool g_bOnlyHeadMode = false;

public Plugin:myinfo = {
    name = "HvH Essentials",
    author = "Axeline",
    description = "Provides AK-47 and Desert Eagle to each team at the start of each round, increases jump height, toggles headshot-only mode, gives unlimited ammo, and prevents fall damage.",
    version = "0.3",
    url = "https://discord.gg/jpDDWsDZra"
};


#define UPDATE_INTERVAL 5.0 // Update interval in seconds

// Definition of offsets for entity data
#define ACTIVE_OFFSET 1896
#define CLIP_OFFSET 1204

public void OnPluginStart() {
    // Hook events
    HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Post);
    HookEvent("round_start", EventRoundStart, EventHookMode_Post);
    HookEvent("player_jump", PlayerJumpEvent);

    // Register commands
    RegConsoleCmd("sm_onlyhead_enable", Command_OnlyHeadEnable, "Enable 'only head' mode");
    RegConsoleCmd("sm_onlyhead_disable", Command_OnlyHeadDisable, "Disable 'only head' mode");

    // Initialize properties
    VelocityOffset_0 = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
    VelocityOffset_1 = FindSendPropInfo("CBasePlayer", "m_vecVelocity[1]");
    BaseVelocityOffset = FindSendPropInfo("CBasePlayer", "m_vecBaseVelocity");
    cvarJumpBoost = CreateConVar("sm_jumpboost", "0.2", "Jump boost factor", FCVAR_REPLICATED | FCVAR_NOTIFY);

    // Initialize clients
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            OnClientPutInServer(i);
        }
    }

    // Hook OnTakeDamage
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }

    // Create a timer that calls Timer_UpdateAmmo every UPDATE_INTERVAL seconds
    CreateTimer(UPDATE_INTERVAL, Timer_UpdateAmmo, _, TIMER_REPEAT);
}

public Action:EventPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsPlayerAlive(client)) {
        int team = GetClientTeam(client);

        // Clear existing weapons and items
        ClearPlayerItems(client);

        // Assign items based on team
        if (team == CS_TEAM_T) {
            GiveItemsToPlayer(client, TERRORIST_ITEMS);
        } else if (team == CS_TEAM_CT) {
            GiveItemsToPlayer(client, COUNTER_TERRORIST_ITEMS);
        }
    }

    // Hook OnTakeDamage
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

    return Plugin_Continue;
}

public Action:EventRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            int team = GetClientTeam(i);
            if (team == CS_TEAM_T) {
                GiveItemsToPlayer(i, TERRORIST_ITEMS);
            } else if (team == CS_TEAM_CT) {
                GiveItemsToPlayer(i, COUNTER_TERRORIST_ITEMS);
            }
        }
    }
    return Plugin_Continue;
}

public Action:PlayerJumpEvent(Handle:event, const String:name[], bool:dontBroadcast) {
    int index = GetClientOfUserId(GetEventInt(event, "userid"));
    new Float:finalvec[3];
    
    // Get the cvar value for jump boost
    new Float:jumpBoost = GetConVarFloat(cvarJumpBoost);

    // Apply the jump boost
    finalvec[0] = GetEntDataFloat(index, VelocityOffset_0) * jumpBoost; // x
    finalvec[1] = GetEntDataFloat(index, VelocityOffset_1) * jumpBoost; // y
    finalvec[2] = 15.0; // z 

    // Set the new base velocity
    SetEntDataVector(index, BaseVelocityOffset, finalvec, true);
}

void ClearPlayerItems(int client) {
    // Clear primary, secondary weapons and keep the knife
    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    int secondary = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
    
    if (primary != -1) RemovePlayerItem(client, primary);
    if (secondary != -1) RemovePlayerItem(client, secondary);

    // Clear grenades and ammo
    SetEntData(client, OFFSET_HEGRENADE * 4, 0); // HE Grenade
    SetEntData(client, OFFSET_FLASHBANG * 4, 0); // Flashbang
    SetEntData(client, OFFSET_SMOKE * 4, 0);     // Smoke Grenade
    SetEntData(client, OFFSET_AMMO * 4, 0);      // Ammo
}

void GiveItemsToPlayer(int client, const String:items[]) {
    // Buffer for item names
    new String:buffer[32][ITEM_NAME_LEN];
    
    // Split item string by ';'
    new numItems = ExplodeString(items, ";", buffer, sizeof(buffer), ITEM_NAME_LEN - 1);

    // Give each item to the player
    for (int i = 0; i < numItems; i++) {
        if (strlen(buffer[i])) {
            GivePlayerItem(client, buffer[i]);
        }
    }

    // Ensure player has a knife
    if (GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1) {
        GivePlayerItem(client, "weapon_knife");
    }
}

public Action:TraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup) {
    // Validate attacker and victim
    if (attacker > 0 && attacker <= MaxClients && attacker != victim) {
        // Allow explosion damage
        if ((damagetype & DMG_BLAST) == DMG_BLAST) {
            return Plugin_Continue;
        }

        // If "only head" mode is enabled
        if (g_bOnlyHeadMode) {
            // Allow damage if hitgroup is HEAD
            if (hitgroup == HITGROUP_HEAD) {
                return Plugin_Continue;
            } else {
                // Set damage to 0% for non-headshots
                damage = 0.0;
                return Plugin_Changed;
            }
        } else {
            // Apply default damage reduction for non-headshots
            if (hitgroup != HITGROUP_HEAD) {
                damage *= 0.3;
                return Plugin_Changed;
            }
        }
    }

    // Continue with normal damage otherwise
    return Plugin_Continue;
}

// Handle damage
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
    // Nullify fall damage
    if ((damagetype & DMG_FALL) == DMG_FALL) {
        damage = 0.0;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

// Enable "only head" mode
public Action:Command_OnlyHeadEnable(client, args) {
    g_bOnlyHeadMode = true;
    PrintToChat(client, "Only head mode enabled.");
    return Plugin_Handled;
}

// Disable "only head" mode
public Action:Command_OnlyHeadDisable(client, args) {
    g_bOnlyHeadMode = false;
    PrintToChat(client, "Only head mode disabled.");
    return Plugin_Handled;
}

// Hook TraceAttack on client join
public OnClientPutInServer(client) {
    SDKHook(client, SDKHook_TraceAttack, TraceAttack);
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:Timer_UpdateAmmo(Handle:timer) {
    // Iterate over all clients
    for (int i = 1; i <= MaxClients; i++) {
        // Check if the client is in game and alive
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
            // Get the active entity of the client
            int activeEntity = GetEntDataEnt2(i, ACTIVE_OFFSET);

            // Check if the entity is valid
            if (IsValidEntity(activeEntity)) {
                // Set the clip ammo value to 100
                SetEntData(activeEntity, CLIP_OFFSET, 100, 4, true);
            }
        }
    }
    return Plugin_Continue;
}

stock TakeDamageV34(victim, ddamage, attacker = -1, dmgflags = 0, const String:weapon[] = "") {
    new String:strDmg[8], String:strDmgFlags[16];
    IntToString(ddamage, strDmg, sizeof(strDmg));
    IntToString(dmgflags, strDmgFlags, sizeof(strDmgFlags));   
    new hurtent = CreateEntityByName("point_hurt"); 
    if(hurtent) {
        DispatchKeyValue(victim, "targetname", "dmgtarget");
        DispatchKeyValue(hurtent, "DamageTarget", "dmgtarget"); 
        DispatchKeyValue(hurtent, "Damage", strDmg);
        DispatchKeyValue(hurtent, "DamageType", strDmgFlags); 
        if(weapon[0]) DispatchKeyValue(hurtent, "classname", weapon);
        DispatchSpawn(hurtent);
        AcceptEntityInput(hurtent, "Hurt", (attacker > 0) ? attacker : -1);
        DispatchKeyValue(victim, "targetname", "nodmg");
        RemoveEdict(hurtent);
    }
}
