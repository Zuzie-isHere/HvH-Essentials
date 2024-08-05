#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin:myinfo = {
    name = "HvH autobuy",
    author = "Axeline",
    description = "Gives ak47,helm,deagle to each team at the start of each round.",
    version = "v0.1",
    url = ""
}

#define ITEM_NAME_LEN 32
#define CS_SLOT_PRIMARY 0
#define CS_SLOT_SECONDARY 1
#define CS_SLOT_KNIFE 2

// Define items for Terrorists and Counter-Terrorists
#define TERRORIST_ITEMS "weapon_ak47;item_assaultsuit;weapon_deagle"
#define COUNTER_TERRORIST_ITEMS "weapon_m4a1;item_assaultsuit;weapon_usp"

// Define properties
#define OFFSET_HEGRENADE 11
#define OFFSET_FLASHBANG 12
#define OFFSET_SMOKE 13

public void OnPluginStart() {
    HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Post);
    HookEvent("round_start", EventRoundStart, EventHookMode_Post);
}

public Action:EventPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsPlayerAlive(client)) {
        int team = GetClientTeam(client);

        // Clear existing weapons and items
        ClearPlayerItems(client);

        // Give specific items based on team
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
    // Clear all items except the knife
    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    int secondary = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
    int knife = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);

    // Remove primary and secondary weapons
    if (primary != -1) RemovePlayerItem(client, primary);
    if (secondary != -1) RemovePlayerItem(client, secondary);

    // Do not remove the knife
    if (knife != -1) {
        GivePlayerItem(client, "weapon_knife");
    }
    
    // Clear grenades and ammo
    SetEntData(client, OFFSET_HEGRENADE * 4, 0, 0, true); // HE Grenade
    SetEntData(client, OFFSET_FLASHBANG * 4, 0, 0, true); // Flashbang
    SetEntData(client, OFFSET_SMOKE * 4, 0, 0, true);     // Smoke Grenade
}

void GiveItemsToPlayer(int client, const String:items[]) {
    // Create a buffer with a size of 128 bytes to hold the exploded item names
    new String:buffer[32][ITEM_NAME_LEN];
    
    // Explode the items string using ';' as the delimiter
    new numItems = ExplodeString(items, ";", buffer, sizeof(buffer), ITEM_NAME_LEN - 1);

    // Iterate through the buffer and give each item to the player
    for (int i = 0; i < numItems; i++) {
        if (strlen(buffer[i])) {
            GivePlayerItem(client, buffer[i]);
        }
    }
}
