/*
 * Copyright (c) 2025 Tuomo Kriikkula <tuokri@tuta.io>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

// Server actor that restores verbose login logging that
// was stripped after an EAC update. Add to server actors in
// WebAdmin to enable.
class LoginLogger extends Actor;

const MAX_RETRIES = 10;

struct LoginLogInfo
{
    var int NumRetries;
    var UniqueNetId PlayerId;
};

var OnlineGameInterfaceSteamworks GameInterface;
var array<LoginLogInfo> LoginLogInfos;

function LogPlayerLogins()
{
    local int i;
    local bool bLogged;

    // `lldebug("LoginLogInfos.Length=" $ LoginLogInfos.Length);

    for (i = 0; i < LoginLogInfos.Length; ++i)
    {
        bLogged = LogPlayerLogin(i);
        if (bLogged)
        {
            LoginLogInfos.Remove(i, 1);
            --i;
        }
    }
}

function bool LogPlayerLogin(int Index)
{
    local string UniqueNetIdStr;
    local PlayerController PC;
    local UniqueNetId PlayerId;

    `lldebug("Index=" $ Index);

    LoginLogInfos[Index].NumRetries += 1;

    PlayerId = LoginLogInfos[Index].PlayerId;
    UniqueNetIdStr = class'OnlineSubsystem'.static.UniqueNetIdToString(PlayerId);
    `lldebug("UniqueNetIdStr=" $ UniqueNetIdStr);

    PC = class'PlayerController'.static.GetPlayerControllerFromNetId(PlayerId);
    if (PC == None)
    {
        `llwarn("failed to get PlayerController for ID" @ UniqueNetIdStr);
        return True; // Don't retry in this case.
    }

    // Data not ready yet? Try again later. But if we're over max retries,
    // log the empty address anyway.
    // TODO: investigate why the address is empty sometimes. Happens on LAN only?
    // TODO: is this check actually completely unnecessary?
    if (PC.GetPlayerNetworkAddress() == "" && LoginLogInfos[Index].NumRetries < MAX_RETRIES)
    {
        `lldebug("player data not ready yet");
        return False;
    }

    `lllog("[RegisterPlayer]" @ "UniqueID:" @ UniqueNetIdStr
        @ class'ROSteamUtils'.static.UniqueIdToSteamId64(PlayerId)
        @ "PlayerIP:" @ PC.GetPlayerNetworkAddress() @ "PlayerName:" @ PC.PlayerReplicationInfo.PlayerName
    );

    if (LoginLogInfos[Index].NumRetries >= MAX_RETRIES)
    {
        `lldebug("max retries exceeded");
    }

    return True;
}

function OnRegisterPlayerComplete(name SessionName, UniqueNetId PlayerId, bool bWasSuccessful)
{
    local int Idx;

    `lldebug("SessionName=" $ SessionName
        @ "PlayerId=" $ class'OnlineSubsystem'.static.UniqueNetIdToString(PlayerId)
        @ "bWasSuccessful=" $ bWasSuccessful);

    if (bWasSuccessful)
    {
        // Process later since all data such as network address and player name
        // are not available at this time.
        Idx = LoginLogInfos.Length;
        LoginLogInfos.Length = LoginLogInfos.Length + 1;
        LoginLogInfos[Idx].NumRetries = 0;
        LoginLogInfos[Idx].PlayerId = PlayerId;
    }
}

event PreBeginPlay()
{
    local OnlineSubsystem OnlineSub;

    super.PreBeginPlay();

    OnlineSub = class'GameEngine'.static.GetOnlineSubsystem();
    if (OnlineSub == None)
    {
        `llerror("failed to get OnlineSubsystem");
        return;
    }
    GameInterface = OnlineGameInterfaceSteamworks(OnlineSub.GameInterface);
    if (GameInterface == None)
    {
        `llerror("failed to get GameInterface");
        return;
    }

    GameInterface.AddRegisterPlayerCompleteDelegate(OnRegisterPlayerComplete);
    SetTimer(0.2, True, NameOf(LogPlayerLogins));

    `lllog("initialized");
}

event Tick(float DeltaTime)
{
    super.Tick(DeltaTime);

    // Prevent leak during seamless travel.
    if (WorldInfo.NextSwitchCountdown == 0
        || WorldInfo.NextURL != ""
        || WorldInfo.IsInSeamlessTravel()
        || WorldInfo.IsMapChangeReady()
    )
    {
        `lldebug("destroying self");

        if (GameInterface != None)
        {
            `lldebug("unregistering delegates");
            GameInterface.ClearRegisterPlayerCompleteDelegate(OnRegisterPlayerComplete);
            GameInterface.RegisterPlayerCompleteDelegates.Length = 0;
        }

        Destroy();
    }
}
