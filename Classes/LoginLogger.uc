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

const MAX_RETRIES = 2;

struct LoginLogInfo
{
    var int NumRetries;
    var UniqueNetId PlayerId;
};

var OnlineGameInterface GameInterface;
var array<LoginLogInfo> LoginLogInfos;

function LogPlayerLogins()
{
    local int i;
    local bool bLogged;

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
    local UniqueNetId PlayerId;
    local string UniqueNetIdStr;
    local PlayerController PC;

    if (LoginLogInfos[Index].NumRetries >= MAX_RETRIES)
    {
        return False;
    }

    PlayerId = LoginLogInfos[Index].PlayerId;
    UniqueNetIdStr = class'OnlineSubsystem'.static.UniqueNetIdToString(PlayerId);

    PC = class'PlayerController'.static.GetPlayerControllerFromNetId(PlayerId);
    if (PC == None)
    {
        `llwarn("failed to get PlayerController for ID" @ UniqueNetIdStr);
        return True; // Don't retry in this case.
    }

    // Data not ready yet? Try again later.
    if (PC.GetPlayerNetworkAddress() == "")
    {
        LoginLogInfos[Index].NumRetries += 1;
        return False;
    }

    `lllog("[RegisterPlayer]" @ "UniqueID:" @ UniqueNetIdStr
        @ class'ROSteamUtils'.static.UniqueIdToSteamId64(PlayerId)
        @ "PlayerIP:" @ PC.GetPlayerNetworkAddress() @ "PlayerName:" @ PC.PlayerReplicationInfo.PlayerName
    );

    return True;
}

function OnRegisterPlayerComplete(name SessionName, UniqueNetId PlayerId, bool bWasSuccessful)
{
    if (bWasSuccessful)
    {
        // Process later since all data such as network address and player name
        // are not available at this time.
        LoginLogInfos.Length = LoginLogInfos.Length + 1;
        LoginLogInfos[LoginLogInfos.Length].NumRetries = 0;
        LoginLogInfos[LoginLogInfos.Length].PlayerId = PlayerId;
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
    GameInterface = OnlineSub.GameInterface;
    if (GameInterface == None)
    {
        `llerror("failed to get GameInterface");
        return;
    }

    GameInterface.AddRegisterPlayerCompleteDelegate(OnRegisterPlayerComplete);
    SetTimer(0.2, True, NameOf(LogPlayerLogins));
}

event Destroyed()
{
    super.Destroyed();

    if (GameInterface != None)
    {
        GameInterface.ClearRegisterPlayerCompleteDelegate(OnRegisterPlayerComplete);
    }
}

event Tick(float DeltaTime)
{
    super.Tick(DeltaTime);

    // Prevent leak during seamless travel.
    if (WorldInfo.NextURL != "" || WorldInfo.IsInSeamlessTravel())
    {
        Destroy();
    }
}
