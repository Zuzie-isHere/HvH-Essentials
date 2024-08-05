#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#define ITEM_NAME_LEN 32
#define CS_SLOT_KNIFE 2

// Define the items for Terrorists and Counter-Terrorists
#define TERRORIST_ITEMS "weapon_ak47;item_assaultsuit;weapon_deagle"
#define COUNTER_TERRORIST_ITEMS "weapon_ak47;item_assaultsuit;weapon_deagle"

// Define properties
#define OFFSET_AMMO 0
#define OFFSET_HEGRENADE 11
#define OFFSET_FLASHBANG 12
#define OFFSET_SMOKE 13

new VelocityOffset_0, VelocityOffset_1, BaseVelocityOffset;
new Handle:cvarJumpBoost;

public Plugin:myinfo = {
    name = "HvH Essentials",
    author = "Axeline",
    description = "Provides akhelmdeagle to each team at the start of each round and increases jump height.",
    version = "0.1",
    url = "" 
};

public void OnPluginStart() {
    HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Post);
    HookEvent("round_start", EventRoundStart, EventHookMode_Post);
    HookEvent("player_jump", PlayerJumpEvent);

    VelocityOffset_0 = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
    VelocityOffset_1 = FindSendPropInfo("CBasePlayer", "m_vecVelocity[1]");
    BaseVelocityOffset = FindSendPropInfo("CBasePlayer", "m_vecBaseVelocity");

    // Create the cvar for jump boost
    cvarJumpBoost = CreateConVar("sm_jumpboost", "0.2", "Jump boost factor", FCVAR_REPLICATED | FCVAR_NOTIFY);
}

public Action:EventPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsPlayerAlive(client)) {
        int team = GetClientTeam(client);

        // Clear existing weapons and items
        ClearPlayerItems(client);

        // Give specific items based on the team
        if (team == CS_TEAM_T) {
            GiveItemsToPlayer(client, TERRORIST_ITEMS);
        } else if (team == CS_TEAM_CT) {
            GiveItemsToPlayer(client, COUNTER_TERRORIST_ITEMS);
        }
    }
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

void ClearPlayerItems(int client) {
    // Clear primary and secondary weapons but keep the knife
    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    int secondary = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
    
    if (primary != -1) RemovePlayerItem(client, primary);
    if (secondary != -1) RemovePlayerItem(client, secondary);

    // No action needed for the knife as it will be handled in GiveItemsToPlayer
    SetEntData(client, OFFSET_HEGRENADE * 4, 0); // HE Grenade
    SetEntData(client, OFFSET_FLASHBANG * 4, 0); // Flashbang
    SetEntData(client, OFFSET_SMOKE * 4, 0);     // Smoke Grenade
    SetEntData(client, OFFSET_AMMO * 4, 0);      // Ammo
    // Clear other items if necessary (e.g., defuser, NVG, helmet, etc.)
}

void GiveItemsToPlayer(int client, const String:items[]) {
    // Create a buffer with a size of 128 bytes to hold item names
    new String:buffer[32][ITEM_NAME_LEN];
    
    // Split the item string using ';' as the delimiter
    new numItems = ExplodeString(items, ";", buffer, sizeof(buffer), ITEM_NAME_LEN - 1);

    // Iterate through the buffer and give each item to the player
    for (int i = 0; i < numItems; i++) {
        if (strlen(buffer[i])) {
            GivePlayerItem(client, buffer[i]);
        }
    }

    // Ensure the player always has a knife
    if (GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == -1) {
        GivePlayerItem(client, "weapon_knife");
    }
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
