package docopt;

typedef Argument = {
	name : String
	// TODO manyVals : Bool
}

typedef Command = String;

typedef Option = {
	names : Array<String>,
	hasParam : Bool
	// TODO manyVals : Bool
}

enum Element {
	LArgument(arg:Argument);
	LCommand(cmd:Command);
	LOption;  // TODO (opt:Option)
}

enum Expr {
	EEmpty;
	EList(list:Array<Expr>);
	EElement(ele:Element);
	EOptionals(e:Expr);
	ERequired(e:Expr);
	EXor(a:Expr, b:Expr);
	EElipsis(e:Expr);
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

