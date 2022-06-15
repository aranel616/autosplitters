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

	vars.Watch = (Action<string>)(key => { if(vars.Unity[key].Changed) vars.Log(key + ": " + vars.Unity[key].Old + " -> " + vars.Unity[key].Current); });
    vars.Unity = Assembly.Load(File.ReadAllBytes(@"Components\UnityASL.bin")).CreateInstance("UnityASL.Unity");
}

onStart
{
	vars.PreviousTime = 0f;
}

init {
	vars.FirstCheckpointId = 0;
	vars.HasSplit = false;

	vars.Unity.TryOnLoad = (Func<dynamic, bool>)(helper => {
		var shl = helper.GetClass("Assembly-CSharp", 0x2000333); // Shell
		var ls = helper.GetClass("Assembly-CSharp", 0x2000319);  // LevelService
		var lrm = helper.GetClass("Assembly-CSharp", 0x2000318); // LevelRunModel
		var fm = helper.GetClass("Assembly-CSharp", 0x20002C6);  // FishManager
		var cs = helper.GetClass("Assembly-CSharp", 0x20002E0);  // CheckpointSystem
		var cp = helper.GetClass("Assembly-CSharp", 0x20002DF);  // Checkpoint
		var sm = helper.GetClass("Assembly-CSharp", 0x2000314);  // IAFSceneManager

		vars.Unity.Make<float>(shl.Static, shl["Instance"], shl["_levelService"], ls["_currentRunStats"], lrm["_levelTimer"]).Name = "_levelTimer";
		vars.Unity.Make<int>(shl.Static, shl["Instance"], shl["_levelService"], ls["_currentRunStats"], lrm["_starsDeaths"]).Name = "_starsDeaths";
		vars.Unity.Make<int>(shl.Static, shl["Instance"], shl["_levelService"], ls["_currentRunStats"], lrm["_currentRunId"]).Name = "_currentRunId";
		vars.Unity.Make<int>(shl.Static, shl["Instance"], shl["_levelService"], ls["_levelsFishManager"], fm["_checkpointSystem"], cs["_lastCheckpoint"], cp["CheckpointID"]).Name = "_lastCheckpointId";
		vars.Unity.Make<int>(shl.Static, shl["Instance"], shl["_sceneManager"], sm["_currentSceneType"]).Name = "_currentSceneType";
		vars.Unity.Make<bool>(shl.Static, shl["Instance"], shl["_sceneManager"], sm["_currentLoadingOperation"]).Name = "_currentLoadingOperation";

		vars.Unity["_lastCheckpointId"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

		return true;
	});

	vars.Unity.Load(game);
}

update {
	if (!vars.Unity.Loaded) {
		return false;
	}

	vars.Unity.Update();

	current.LevelTimer = vars.Unity["_levelTimer"].Current;
	current.StarsDeaths = vars.Unity["_starsDeaths"].Current;
	current.RunId = vars.Unity["_currentRunId"].Current;
	current.LastCheckpointId = vars.Unity["_lastCheckpointId"].Current;
	current.SceneType = vars.Unity["_currentSceneType"].Current;
	current.LoadingOperation = vars.Unity["_currentLoadingOperation"].Current;

	if (old.RunId != current.RunId) {
		vars.InLevel = true;
	}

	if (old.SceneType == vars.SceneTypes["Map"]) {
		vars.InLevel = false;
	}
}

start {
	// Do not start unless you are in a level
	if (current.SceneType != vars.SceneTypes["Level"]) {
		return;
	}

	// Any% starts on level select
	if (settings["modeAny"]) {
		return old.SceneType == vars.SceneTypes["Map"] && current.SceneType == vars.SceneTypes["Level"];
	}

	// IL starts after loading time, tracking in game time
	if (settings["modeIL"] && old.RunId != current.RunId) {
		vars.FirstCheckpointId = current.LastCheckpointId;
		vars.HasSplit = false;
		return true;
	}
}

split {
	// Ending screen is shown - split for Any% and IL
	if (old.StarsDeaths == 0 && current.StarsDeaths != 0) {
		vars.InLevel = false;
		vars.PreviousTime += current.LevelTimer;
		return true;
	}

	// Last Checkpoint ID has changed - split for IL.
	if (settings["modeILSplitOnCheckpoint"]) {
		if (old.LastCheckpointId != current.LastCheckpointId && (!vars.HasSplit || current.LastCheckpointId != vars.FirstCheckpointId)) {
			vars.HasSplit = true;
			return true;
		}
	}
}

reset {
	if (vars.InLevel && current.SceneType == vars.SceneTypes["Map"]) {
		return true;
	}

	if (settings["modeIL"] && current.LoadingOperation) {
		vars.FirstCheckpointId = 0;
		return true;
	}
}

gameTime {
	var time = Math.Round(current.LevelTimer, 2);

	if (settings["modeAny"]) {
		time = vars.InLevel ? time + vars.PreviousTime : vars.PreviousTime;
	}

	return TimeSpan.FromSeconds(time);
}

isLoading {
	return true;
}

exit {
	vars.Unity.Reset();
}

shutdown {
	vars.Unity.Reset();
}
