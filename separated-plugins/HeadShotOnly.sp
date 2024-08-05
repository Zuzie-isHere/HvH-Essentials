#include <sourcemod>
#include <sdkhooks>
#include <cstrike>

// Plugin metadata
public Plugin:myinfo = {
    name = "Only Headshot Plugin",
    author = "Axeline",
    description = "This plugin enables a mode where only headshots deal damage.",
    version = "1.0",
    url = "https://discord.gg/jpDDWsDZra"
};

// Define HITGROUP_HEAD 
#define HITGROUP_HEAD 1

// Global variable to control the "only head" mode
bool g_bOnlyHeadMode = false;

public OnPluginStart()
{
    // Hook the TraceAttack event for all clients when they join the server
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }
    HookEvent("player_spawn", EventPlayerSpawn);

    // Register commands to toggle the mode
    RegConsoleCmd("sm_onlyhead_enable", Command_OnlyHeadEnable, "Enable 'only head' mode");
    RegConsoleCmd("sm_onlyhead_disable", Command_OnlyHeadDisable, "Disable 'only head' mode");
}

public EventPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client > 0 && client <= MaxClients)
    {
        OnClientPutInServer(client);
    }
}

public OnClientPutInServer(client)
{
    // Hook the TraceAttack event for the client
    SDKHook(client, SDKHook_TraceAttack, TraceAttack);
}

public Action:TraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
    // Check if the attacker is a valid client and not the same as the victim
    if (attacker > 0 && attacker <= MaxClients && attacker != victim)
    {
        // Allow fall damage and explosion damage to continue as normal
        if ((damagetype & DMG_FALL) == DMG_FALL || (damagetype & DMG_BLAST) == DMG_BLAST)
        {
            return Plugin_Continue;
        }

        // If only head mode is enabled
        if (g_bOnlyHeadMode)
        {
            // If the hitgroup is HEAD, allow the damage to continue as normal
            if (hitgroup == HITGROUP_HEAD)
            {
                return Plugin_Continue;
            }
            else
            {
                // Reduce damage to 0% for other body parts (headshots only)
                damage = 0.0;  // Ensure this is a float assignment
                return Plugin_Changed;
            }
        }
        else
        {
            // Apply default damage reduction (30% of the original value) for other body parts
            if (hitgroup != HITGROUP_HEAD)
            {
                damage *= 0.3;
                return Plugin_Changed;
            }
        }
    }

    // Continue with normal damage if conditions are not met
    return Plugin_Continue;
}

// Command to enable only head mode
public Action:Command_OnlyHeadEnable(client, args)
{
    g_bOnlyHeadMode = true;
    PrintToChat(client, "Only head mode enabled.");
    return Plugin_Handled;
}

// Command to disable only head mode
public Action:Command_OnlyHeadDisable(client, args)
{
    g_bOnlyHeadMode = false;
    PrintToChat(client, "Only head mode disabled.");
    return Plugin_Handled;
}
