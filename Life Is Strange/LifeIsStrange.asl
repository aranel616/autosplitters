state("LifeIsStrange")
{
    bool isLoading : "LifeIsStrange.exe", 0x1234AB0;
    bool isSaving : "LifeIsStrange.exe", 0x1234E00;
    string5 map : "LifeIsStrange.exe", 0x122DFF8;
    float fov : "LifeIsStrange.exe", 0x011E4DF8, 0xA20, 0x1C, 0x120, 0x98, 0x794, 0x590;
    int walkingAnimation : "LifeIsStrange.exe", 0x011E4DF8, 0x7BC;
    float cameraX : "LifeIsStrange.exe", 0x12072C0;
    float cameraY : "LifeIsStrange.exe", 0x12072C4;
    float cameraZ : "LifeIsStrange.exe", 0x12072C8;
}

startup {
    settings.Add("calculateIGT", true, "Calculate IGT [SEE TOOLTIP]");
    settings.Add("ignoreLoadingScreenForIGT", true, "Ignore loading screens", "calculateIGT");
    settings.Add("ignoreMainMenuForIGT", true, "Ignore main menu between episodes", "calculateIGT");
    settings.SetToolTip("calculateIGT", "For personal use only. Runs are submitted to the leaderboards using RTA.");

    settings.Add("singleEpisode", false, "Single episode mode [EXPERIMENTAL - SEE TOOLTIP]");
    settings.SetToolTip("singleEpisode", @"Attempts to start and stop the timer at the appropriate times for single episode runs.
Currently starts the timer for Episodes 1, 3 and 5, and stops the timer for Episodes 1, 3, and 4.
May not work.");
}

init
{
    vars.splitOnNextSave = false;
    vars.finalSplitComplete = false;
}

start
{
    var willStart = false;

    if (settings["singleEpisode"]) {
        // Episode 1 starts on first movement
        if (current.map == "E1_1A") {
            if (current.walkingAnimation > 0) {
                willStart = true;
            }
        }

        // @todo Episode 2 starts when you hit snooze

        // Episode 3 starts on first movement
        if (current.map == "E3_1A") {
            if (current.walkingAnimation > 0) {
                willStart = true;
            }
        }

        // @todo Episode 4 starts on first dialogue choice

        // Episode 5 starts on first camera movement
        if (
            (Math.Round(old.cameraX, 3) == -582.353 && old.cameraX != current.cameraX) &&
            (Math.Round(old.cameraY, 3) == 94.093 && old.cameraY != current.cameraY) &&
            (Math.Round(old.cameraZ, 3) == 152.826 && old.cameraZ != current.cameraZ)
        ) {
            willStart = true;
        }
    }

    if (willStart) {
        vars.splitOnNextSave = false;
        vars.finalSplitComplete = false;
    }

    return willStart;
}

split
{
    /*** Reusable states (even if they are only used once for now) ***/

    // Avoids an extra split at the end of Episode 3 when the player
    // briefly has control again after throwing the keys.
    if (vars.finalSplitComplete) {
        return false;
    }

    // Don't split if loading a map from the menu
    // @todo needs to be false for full game runs
    if (old.map == "E0_Me") {
        //return;
    }

    // Used for the "Jefferson's Car" split in Episode 5
    if (!old.isSaving && current.isSaving && vars.splitOnNextSave) {
        vars.splitOnNextSave = false;
        return true;
    }

    /*** Map changes that do not correspond to splits ***/

    // Transition between "Dormitories - With The Flash Drive" and "Parking Lot" in Episode 1
    if (old.map == "E1_3B" && current.map == "E1_3A") {
        return;
    }

    // Transition between "Parking Lot - Evening" and "Chloe's House - Upstairs" in Episode 3
    if (old.map == "E3_3b" && current.map == "E3_3c") {
        return;
    }

    // Transition between "Swimming Pool - Party" and "Junkyard - Evening"
    if (old.map == "E4_8B" && current.map == "E4_8c") {
        return;
    }

    // The map changes to E5_5e at the end of "Dark Room - Confrontation" at the end of episode 5,
    // but the split does not occur until the next save, at the start of "Jefferson's Car"
    if (old.map == "E5_5D" && current.map == "E5_5e") {
        vars.splitOnNextSave = true;
        return false;
    }

    /***  Final split conditions for single episode runs ***/
    if (settings["singleEpisode"]) {
        // Final split in episode 1 when you read the newspaper
        if (current.map == "E1_6B" && old.fov == 68 && current.fov == 20) {
            vars.finalSplitComplete = true;
            return true;
        }

        // @todo Final split in episode 2 when you sign the contract

        // Final split in episode 3
        if (current.map == "E3_8A" && old.fov == 68 && current.fov == 30) {
            vars.finalSplitComplete = true;
            return true;
        }

        // Final split in episode 4
        if (current.map == "E4_9b" && old.fov == 68 && current.fov == 40) {
            vars.finalSplitComplete = true;
            return true;
        }

        // @todo Final split in episode 5 when you pick a choice
    }

    /*** Unless otherwise accounted for above, splits occur on every map change ***/
    if (old.map != current.map) {
        return true;
    }
}

isLoading
{
    var isLoading = false;

    if (settings["calculateIGT"]) {
        if (settings["ignoreLoadingScreenForIGT"] && !settings["ignoreMainMenuForIGT"]) {
            isLoading = current.isLoading;
        }

        if (settings["ignoreLoadingScreenForIGT"] && settings["ignoreMainMenuForIGT"]) {
            isLoading = current.isLoading || current.map == "E0_Me";
        }
    }

    return isLoading;
}

reset
{
    // @todo How can I tell if the user is quitting vs in between chapters?
    if (settings["singleEpisode"]) {
        if (old.map != "E0_Me" && current.map == "E0_Me") {
            //vars.finalSplitComplete = false;
            //return true;
        }
    }
}
