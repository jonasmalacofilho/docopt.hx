package docopt;

enum PatternToken {
	TOpenBracket;
	TCloseBracket;
	TOpenParens;
	TCloseParens;
	TPipe;
	TElipsis;
	TArgument(arg:String);
	TLongOption(opt:String, ?param:String);
	TShortOption(opt:String, ?rest:String);
	TOptionsShortcut;
	TCommand(cmd:String);
}

enum ArgumentToken {
	ALongOption(opt:String, ?param:String);
	AShortOption(opt:String, ?rest:String);
	AArgument(arg:String);
	// TODO ADoubleDash;
	// TODO ADash;
}

