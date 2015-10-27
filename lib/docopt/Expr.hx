package docopt;

enum Element {
	LArgument(arg:String);
	LCommand(cmd:String);
	LOption;
}

enum Expr {
	EElement(ele:Element);
	EOptionals(e:Expr);
	ERequired(e:Expr);
	EXor(a:Expr, b:Expr);
	EElipsis(e:Expr);
	EList(list:Array<Expr>);
	EEmpty;
}

typedef Pattern = {
	executable : String,
	pattern : Expr
}

typedef Option = {
	names : Array<String>,
	hasParam : Bool
}

typedef Usage = {
	patterns : Array<Pattern>,
	options : Map<String, Option>
}

