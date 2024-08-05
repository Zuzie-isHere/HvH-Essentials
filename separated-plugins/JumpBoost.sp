#include <sdkhooks>

new VelocityOffset_0, VelocityOffset_1, BaseVelocityOffset;
new Handle:cvarJumpBoost;

public Plugin:myinfo = {name = "JumpBoost", author = "Axeline"};

public OnPluginStart() {
    HookEvent("player_jump", PlayerJumpEvent);
    VelocityOffset_0 = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
    VelocityOffset_1 = FindSendPropInfo("CBasePlayer", "m_vecVelocity[1]");
    BaseVelocityOffset = FindSendPropInfo("CBasePlayer", "m_vecBaseVelocity");

    // Crear la cvar para el impulso de salto
    cvarJumpBoost = CreateConVar("sm_jumpboost", "0.2", "Factor de impulso de salto", FCVAR_REPLICATED | FCVAR_NOTIFY);
}

public PlayerJumpEvent(Handle:event, const String:name[], bool:dontBroadcast) {
    new index = GetClientOfUserId(GetEventInt(event, "userid"));
    new Float:finalvec[3];
    
    // Obtener el valor de la cvar para el impulso de salto
    new Float:jumpBoost = GetConVarFloat(cvarJumpBoost);

    // Parte del impulso de salto
    finalvec[0] = GetEntDataFloat(index, VelocityOffset_0) * jumpBoost; // x
    finalvec[1] = GetEntDataFloat(index, VelocityOffset_1) * jumpBoost; // y
    finalvec[2] = 15.0; // z 

    // Establecer la nueva velocidad base
    SetEntDataVector(index, BaseVelocityOffset, finalvec, true);
}
