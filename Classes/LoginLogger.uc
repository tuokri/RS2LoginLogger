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

var OnlineGameInterface GameInterface;

function OnRegisterPlayerComplete(name SessionName, UniqueNetId PlayerId, bool bWasSuccessful)
{
    local PlayerController PC;
    local string UniqueNetIdStr;
    local string SteamID64String;

    if (!bWasSuccessful)
    {
        return;
    }

    UniqueNetIdStr = class'OnlineSubsystem'.static.UniqueNetIdToString(PlayerId);

    PC = class'PlayerController'.static.GetPlayerControllerFromNetId(PlayerId);
    if (PC == None)
    {
        `llwarn("failed to get PlayerController for ID" @ UniqueNetIdStr);
        return;
    }

    SteamID64String = class'ROSteamUtils'.static.UniqueIdToSteamId64(PlayerId);

    `lllog("[RegisterPlayer]" @ "UniqueID:" @ UniqueNetIdStr @ SteamID64String
        @ "PlayerIP:" @ PC.GetPlayerNetworkAddress() @ "PlayerName:" @ PC.PlayerReplicationInfo.PlayerName
    );
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
}

event Destroyed()
{
    super.Destroyed();

    if (GameInterface != None)
    {
        GameInterface.ClearRegisterPlayerCompleteDelegate(OnRegisterPlayerComplete);
    }
}
