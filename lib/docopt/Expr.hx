package docopt;

typedef Argument = {
	name : String
	// TODO manyVals : Bool
}

typedef Command = String;

typedef Option = {
	names : Array<String>,
	hasParam : Bool,
	defaultValue : Null<String>,
	// TODO manyVals : Bool
}

enum Expr {
	EEmpty;
	EList(list:Array<Expr>);
	EOptionals(e:Expr);
	ERequired(e:Expr);
	EXor(a:Expr, b:Expr);
	EElipsis(e:Expr);
	EArgument(arg:Argument);
	ECommand(cmd:Command);
	EOption(?opt:Option);
	// TODO EOptionsShortcut instead of EOption(null)
}

typedef Pattern = {
	executable : String,
	pattern : Expr
}

typedef Usage = {
	arguments : Map<String,Argument>,
	commands : Map<String,String>,
	options : Map<String,Option>,
	patterns : Array<Pattern>,
	hasOptionsSection : Bool
}

