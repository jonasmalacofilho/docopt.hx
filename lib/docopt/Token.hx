package docopt;

enum Token {
	TOpenBracket;
	TCloseBracket;
	TOpenParens;
	TCloseParens;
	TPipe;
	TElipsis;
	TArgument(arg:String);
	TLongOption(opt:String, ?val:String);
	TShortOption(opt:String, ?rest:String);
	TOptionsShortcut;
	TCommand(cmd:String);
}

