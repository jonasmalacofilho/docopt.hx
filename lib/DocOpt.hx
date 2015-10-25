using StringTools;

enum Element {
	LArgument(arg:String);
	LOption(opt:String, ?param:String);
	LCommand(cmd:String);
}

enum Expr {
	EElement(ele:Element);
	EOptionals(e:Expr);
	ERequired(e:Expr);
	EXor(a:Expr, b:Expr);
	EElipsis(e:Expr);
	EList(list:Array<Expr>);
}

typedef Pattern = {
	executable : String,
	pattern : Expr
}

enum Token {
	TOpenBracket;
	TCloseBracket;
	TOpenParens;
	TCloseParens;
	TPipe;
	TElipsis;
	TArgument(arg:String);
	TOption(opt:String);
	TCommand(cmd:String);
}

class DocstringParser {
	static function tokensOf(li:String)
	{
		var tokenPattern = ~/([()|[\]]|(\.\.\.)|[^ \t()|.[\]]+)[ \t]*/;
		var tokens = new List();
		while (tokenPattern.match(li)) {
			li = tokenPattern.matchedRight();
			var t = switch (tokenPattern.matched(1)) {
				case "[": TOpenBracket;
				case "]": TCloseBracket;
				case "(": TOpenParens;
				case ")": TCloseParens;
				case "|": TPipe;
				case "...": TElipsis;
				case w:
					if (!w.startsWith("-")) {
						if ((w.startsWith("<") && w.endsWith(">")) || (w.toUpperCase() == w))
							TArgument(w);
						else
							TCommand(w);
					} else if (w != "-" && w != "--") {
						TOption(w);
					} else {
						TCommand(w);
					}
				}
			tokens.add(t);
		}
		return tokens;
	}

	static function parsePattern(options, li:String)
	{
		var tokens = tokensOf(li);
		var rewindBuf = new List();
		function pop()
		{
			if (tokens.isEmpty())
				return null;
			var t = tokens.pop();
			rewindBuf.push(t);
			return t;
		}
		function rewind(n=1)
		{
			while (n-- > 0 && !rewindBuf.isEmpty())
				tokens.push(rewindBuf.pop());
			return null;
		}
		function expr(?breakOn)
		{
			var list = [];
			var t = pop();
			while (t != null) {
				var e = switch (t) {
					case TArgument(a): EElement(LArgument(a));
					case TCommand(c): EElement(LCommand(c));
					case TOption(o):
						var p = null;
						if (o.startsWith("--")) {
							// TODO check if option expects parameter, and get it necessary
							var eqi = o.indexOf("=");
							if (eqi > -1) {
								// try to get parameter from '=*'
								p = o.substr(eqi + 1);
								o = o.substr(0, eqi);
								// TODO check if param is argument-like: <foo> or FOO
							} else {
								// TODO else get it from the next argument
							}
						} else {
							// TODO split short options from each other and parameter
							// TODO handle multiple short options
						}
						EElement(LOption(o, p));
					case TOpenBracket:
						var inner = expr(TCloseBracket);
						var n = pop();
						if (n == null || !n.match(TCloseBracket))
							throw "Missing closing bracket";
						EOptionals(inner);
					case TOpenParens:
						var inner = expr(TCloseParens);
						var n = pop();
						if (n == null || !n.match(TCloseParens))
							throw "Missing closing parens";
						ERequired(inner);
					case TCloseBracket, TCloseParens if (breakOn != null && t == breakOn):
						rewind();
						break;
					case t:
						throw 'Unexpected token $t';
				}
				var n = pop();
				switch (n) {
				case null:  // NOOP
				case TElipsis:
					e = EElipsis(e);
					n = pop();
				case TPipe:
					e = EXor(e, expr(breakOn));
					n = pop();
				case _:
				}
				list.push(e);
				t = n;
			}
			return list.length == 1 ? list[0] : EList(list);
		}
		function executable()
		{
			return switch (pop()) {
				case TCommand(exec): exec;
				case _: rewind();
			}
		}
		function pattern()
		{
			return {
				executable : executable(),
				pattern : expr()
			}
		}
		return pattern();
	}

	public static function parse(doc:String)
	{
		// spec: text occuring between keyword usage: (case-insensitive) and
		// a visibly empty line is interpreted as list of usage
		// patterns.
		var usageMarker = ~/^.*usage:[ \t\n]*(.+?)(\n[ \t]*\n)|(.+)$/si;
		if (!usageMarker.match(doc))
			throw 'Missing "Usage:" (case insensitive) marker';

		var options = null;
		var optionsMarker = ~/^.*options:[ \t\n]*(.+?)(\n[ \t]*\n)|(.+)$/si;
		if (optionsMarker.match(usageMarker.matchedRight())) {
			// TODO
		}

		var patterns = [ for (li in usageMarker.matched(1).split("\n")) parsePattern(options, li.trim()) ];
		return {
			options : options,
			patterns : patterns
		};
	}
}

class DocOpt {
	static function tryMatch(args:Array<String>, expr:Expr, opts:Map<String,Dynamic>):Bool
	{
		var _a = args.copy();
		var _o = new Map();
		if (match(_a, expr, _o)) {
			while (args.length > _a.length)
				args.shift();
			for (k in _o.keys())
				opts[k] = _o[k];
			return true;
		}
		return false;
	}

	static function match(args:Array<String>, expr:Expr, opts:Map<String,Dynamic>):Bool
	{
		if (!expr.match(EOptionals(_)) && args.length < 1)
			return false;
		// trace(expr);
		switch (expr) {
		case EList(list):
			for (e in list) {
				if (!match(args, e, opts))
					return false;
			}
			if (args.length != 0)
				return false;
		case EElement(LArgument(name)):
			opts[name] = args.shift();
		case EElement(LCommand(name)):
			if (args.shift() != name)
				return false;
			opts[name] = true;
		case EElement(LOption(opt, param)):
			var a = args.shift();
			if (a == opt) {
				if (param == null) {
					opts[opt] = true;
				} else {
					if (args.length < 1 )
						return false;
					opts[opt] = args.shift();
				}
			} else {
				var eqi = a.indexOf("=");
				if (eqi > -1) {
					var p = a.substr(eqi + 1);
					var a = a.substr(0, eqi);
					if (a != opt || param == null)
						return false;
					opts[opt] = p;
				} else {
					// TODO check for synonyms
					return false;
				}
			}
		case EOptionals(e):
			return tryMatch(args, e, opts);
		case ERequired(e):
			return match(args, e, opts);
		case EXor(a, b):
			return tryMatch(args, a, opts) || tryMatch(args, b, opts);
		case EElipsis(e):
			if (!match(args, e, opts))
				return false;
			while (match(args, e, opts))
				true;  // NOOP
		}
		return true;
	}

	public static function docopt(doc:String, args:Array<String>, help=true, ?version:String):Map<String,Dynamic>
	{
		var usage = DocstringParser.parse(doc);
		// trace(usage);

		// trace(args);
		for (pat in usage.patterns) {
			// trace("pattern " + Lambda.indexOf(usage.patterns, pat));
			var a = new Map();
			if (match(args.copy(), pat.pattern, a))
				return a;
		}

		return new Map();
	}
}

