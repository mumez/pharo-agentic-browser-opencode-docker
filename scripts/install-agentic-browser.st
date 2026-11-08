"Loading the WebUI group updates Zinc, which raises MCMergeOrLoadWarning. Its
default action opens a dialog that nobody can answer in a headless build, so
answer it here. See AgenticBrowser's README, 'Installing all packages'.
AGENTIC_BROWSER_REPOS_URL is the Dockerfile ARG of the same name; Docker
exports build args to the environment of RUN, and Pharo inherits it there."
[ Metacello new
	baseline: 'AgenticBrowser';
	repository: (Smalltalk os environment at: 'AGENTIC_BROWSER_REPOS_URL');
	onConflict: [ :e | e useIncoming ];
	onUpgrade: [ :e | e useIncoming ];
	ignoreImage;
	load: 'all' ]
	on: MCMergeOrLoadWarning
	do: [ :ex | ex load ].
