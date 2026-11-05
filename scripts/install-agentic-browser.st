"Loading the WebUI group updates Zinc, which raises MCMergeOrLoadWarning. Its
default action opens a dialog that nobody can answer in a headless build, so
answer it here. See AgenticBrowser's README, 'Installing all packages'."
[ Metacello new
	baseline: 'AgenticBrowser';
	repository: (Smalltalk os environment at: 'AGENTIC_BROWSER_REPOS_URL');
	onConflict: [ :e | e useIncoming ];
	onUpgrade: [ :e | e useIncoming ];
	ignoreImage;
	load: 'all' ]
	on: MCMergeOrLoadWarning
	do: [ :ex | ex load ].
