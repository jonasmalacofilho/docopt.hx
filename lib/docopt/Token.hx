package docopt;

enum Token {
	TOpenBracket;
	TCloseBracket;
	TOpenParens;
	TCloseParens;
	TPipe;
	TElipsis;
	TArgument(arg:String);
	TOption(opt:String);
	TOptionsShortcut;
	TCommand(cmd:String);
}

