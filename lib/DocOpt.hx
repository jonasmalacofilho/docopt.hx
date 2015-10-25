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

typedef Option = {
	shortNames : Array<String>,
	longNames : Array<String>,
	hasParam : Bool
}

typedef Usage = {
	patterns : Array<Pattern>,
	options : Map<String, Option>
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

	static function parseOptionDesc(li:String):Option
	{
		var split = li.trim().split("  ");
		var names = ~/[ ,]/g.split(split[0]);
		var desc = split[1];

		var opt = {
			shortNames : [],
			longNames : [],
			hasParam : false
		};
		for (n in names) {
			var eqi = n.indexOf("=");
			if (eqi > -1) {
				opt.hasParam = true;
				n = n.substr(0, eqi);
			}
			if (~/^-[^-]$/.match(n))
				opt.shortNames.push(n);
			else if (~/^--.+$/.match(n))
				opt.longNames.push(n);
			else if (~/^<.+?>$/.match(n))
				opt.hasParam = true;
			else
				throw 'Docstring: bad option name $n';
		}
		return opt;
	}

	static function parsePattern(options:Map<String,Option>, li:String):Pattern
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
							var eqi = o.indexOf("=");
							if (eqi > -1) {
								// try to get parameter from '=*'
								p = o.substr(eqi + 1);
								o = o.substr(0, eqi);
								if (!~/^<.+>$/.match(p) && p.toUpperCase() != p)
									throw 'Docstring: bad parameter format $p';
							}
						} else {
							// TODO split short options from each other and parameter
							// TODO handle multiple short options
						}
						var hasParam:Null<Bool> = if (options != null && options.exists(o))
								options[o].hasParam
							else
								null;
						if (hasParam == false && p != null) {
							throw 'Docstring: option $o does not expect param';
						}
						if (hasParam == true && p == null) {
							p = switch (pop()) {
								case TArgument(a): a;
								case _: throw 'Docstring: missing parameter for $o';
								}
						}
						EElement(LOption(o, p));
					case TOpenBracket:
						var inner = expr(TCloseBracket);
						var n = pop();
						if (n == null || !n.match(TCloseBracket))
							throw "Docstring: missing closing bracket";
						EOptionals(inner);
					case TOpenParens:
						var inner = expr(TCloseParens);
						var n = pop();
						if (n == null || !n.match(TCloseParens))
							throw "Docstring: missing closing parens";
						ERequired(inner);
					case TCloseBracket, TCloseParens if (breakOn != null && t == breakOn):
						rewind();
						break;
					case t:
						throw 'Docstring: unexpected token $t';
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

	public static function parse(doc:String):Usage
	{
		// spec: text occuring between keyword usage: (case-insensitive) and
		// a visibly empty line is interpreted as list of usage
		// patterns.
		var usageMarker = ~/^.*usage:[ \t\n]*(.+?)((\n[ \t]*\n.*)|[ \t\n]*)$/si;
		if (!usageMarker.match(doc))
			throw 'Docstring: missing "usage:" (case insensitive) marker';

		var options = null;
		var optionsMarker = ~/^.*options:[ \t\n]*(.+?)((\n[ \t]*\n.*)|[ \t\n]*)$/si;
		if (usageMarker.matched(3) != null && optionsMarker.match(usageMarker.matched(3))) {
			options = new Map();
			for (li in optionsMarker.matched(1).split("\n")) {
				var opt = parseOptionDesc(li);
				for (name in opt.shortNames)
					options[name] = opt;
				for (name in opt.longNames)
					options[name] = opt;
			}
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
			tryMatch(args, e, opts);
		case ERequired(e):
			return match(args, e, opts);
		case EXor(a, b):
			return tryMatch(args, a, opts) || tryMatch(args, b, opts);
		case EElipsis(e):
			// TODO deal (somewhere) with the multiple option values
			if (!match(args, e, opts))
				return false;
			while (match(args, e, opts))
				true;  // NOOP
		}
		return true;
	}

	public static function doctrim(str:String):String
	{
		var lines = str.split("\n");
		var indent = 0xffff;
		for (li in lines.slice(1)) {
			var tli = StringTools.trim(li);
			if (tli.length == 0)
				continue;
			var ind = li.indexOf(tli);
			if (ind < indent)
				indent = ind;
		}
		if (indent == 0 || indent == 0xffff)
			return str;
		var trimmed = [ for (li in lines)
				if (StringTools.trim(li.substr(0, indent)).length == 0)
					li.substr(indent)
				else
					li
		];
		return StringTools.trim(trimmed.join("\n"));
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

