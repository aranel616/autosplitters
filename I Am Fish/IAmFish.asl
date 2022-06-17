state("IAmFish") {}

startup {
	vars.Log = (Action<object>)(output => print("[I Am Fish] " + output));

	vars.PreviousTime = 0f;
	vars.InLevel = false;

	vars.SceneTypes = new Dictionary<string, int> {
		{ "Map", 1 },
		{ "Level", 2 },
		{ "MainMenu", 8 }
	};

	#region Settings
	settings.Add("modeAny", true, "Any% Mode");
	settings.SetToolTip("modeAny",
		"Any% Mode:\n" +
		"- Starts timer on level select\n" +
		"- Tracks in game time across multiple levels\n" +
		"- Resets when you select 'Quit Level'"
	);

	settings.Add("modeIL", false, "Individual Level Mode");
	settings.SetToolTip("modeIL",
		"Individual Level Mode:\n" +
		"- Starts timer when in game timer starts\n" +
		"- Resets when you select 'Quit Level'\n" +
		"- Resets when you select 'Restart Level'"
	);

	settings.Add("modeILSplitOnCheckpoint", true, "Split On Checkpoints", "modeIL");
	#endregion

	#region Helper Setup
	var bytes = File.ReadAllBytes(@"Components\LiveSplit.ASLHelper.bin");
	var type = Assembly.Load(bytes).GetType("ASLHelper.Unity");
	vars.Helper = Activator.CreateInstance(type, timer, this);
	#endregion
}

onStart
{
	vars.PreviousTime = 0f;
}

init {
	vars.FirstCheckpointId = 0;
	vars.HasSplit = false;

	vars.Helper.TryOnLoad = (Func<dynamic, bool>)(mono => {
		var shl = mono.GetClass("Shell");
		var ls = mono.GetClass("LevelService");
		var lrm = mono.GetClass("LevelRunModel");
		var fm = mono.GetClass("FishManager");
		var cs = mono.GetClass("CheckpointSystem");
		var cp = mono.GetClass("Checkpoint");
		var sm = mono.GetClass("IAFSceneManager");

		vars.Helper["_levelTimer"] = shl.Make<float>("Instance", "_levelService", ls["_currentRunStats"], lrm["_levelTimer"]);
		vars.Helper["_starsDeaths"] = shl.Make<int>("Instance", "_levelService", ls["_currentRunStats"], lrm["_starsDeaths"]);
		vars.Helper["_currentRunId"] = shl.Make<int>("Instance", "_levelService", ls["_currentRunStats"], lrm["_currentRunId"]);
		vars.Helper["_lastCheckpointId"] = shl.Make<int>("Instance", "_levelService", ls["_levelsFishManager"], fm["_checkpointSystem"], cs["_lastCheckpoint"], cp["CheckpointID"]);
		vars.Helper["_currentSceneType"] = shl.Make<int>("Instance", "_sceneManager", sm["_currentSceneType"]);
		vars.Helper["_currentLoadingOperation"] = shl.Make<bool>("Instance", "_sceneManager", sm["_currentLoadingOperation"]);

		vars.Helper["_lastCheckpointId"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

		return true;
	});

	vars.Helper.Load();
}

update {
	if (!vars.Helper.Update()) {
		return false;
	}

	if (vars.Helper["_currentRunId"].Old != vars.Helper["_currentRunId"].Current) {
		vars.InLevel = true;
	}

	if (vars.Helper["_currentSceneType"].Old == vars.SceneTypes["Map"]) {
		vars.InLevel = false;
	}
}

start {
	// Do not start unless you are in a level
	if (vars.Helper["_currentSceneType"].Current != vars.SceneTypes["Level"]) {
		return;
	}

	// Any% starts on level select
	if (settings["modeAny"]) {
		return (vars.Helper["_currentSceneType"].Old == vars.SceneTypes["Map"] && vars.Helper["_currentSceneType"].Current == vars.SceneTypes["Level"]);
	}

	// IL starts after loading time, tracking in game time
	if (settings["modeIL"] && vars.Helper["_currentRunId"].Old != vars.Helper["_currentRunId"].Current) {
		vars.FirstCheckpointId = vars.Helper["_lastCheckpointId"].Current;
		vars.HasSplit = false;
		return true;
	}
}

split {
	// Ending screen is shown - split for Any% and IL
	if (vars.Helper["_starsDeaths"].Old == 0 && vars.Helper["_starsDeaths"].Current != 0) {
		vars.InLevel = false;
		vars.PreviousTime += vars.Helper["_levelTimer"].Current;
		return true;
	}

	// Last Checkpoint ID has changed - split for IL.
	if (settings["modeILSplitOnCheckpoint"]) {
		if (vars.Helper["_lastCheckpointId"].Old != vars.Helper["_lastCheckpointId"].Current && (!vars.HasSplit || vars.Helper["_lastCheckpointId"].Current != vars.FirstCheckpointId)) {
			vars.HasSplit = true;
			return true;
		}
	}
}

reset {
	if (vars.InLevel && vars.Helper["_currentSceneType"].Current == vars.SceneTypes["Map"]) {
		return true;
	}

	if (settings["modeIL"] && vars.Helper["_currentLoadingOperation"].Current) {
		vars.FirstCheckpointId = 0;
		return true;
	}
}

gameTime {
	var time = Math.Round(vars.Helper["_levelTimer"].Current, 2);

	if (settings["modeAny"]) {
		time = vars.InLevel ? time + vars.PreviousTime : vars.PreviousTime;
	}

	return TimeSpan.FromSeconds(time);
}

isLoading {
	return true;
}

exit {
	vars.Helper.Dispose();
}

shutdown {
	vars.Helper.Dispose();
}
