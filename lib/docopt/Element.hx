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

