using StringTools;

enum Element {
	LArgument(arg:String);
	LOption(opt:Option);
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
	names : Array<String>,
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
			names : [],
			hasParam : false
		};
		for (n in names) {
			var eqi = n.indexOf("=");
			if (eqi > -1) {
				opt.hasParam = true;
				n = n.substr(0, eqi);
			}
			if (~/^-[^-]$/.match(n) || ~/^--.+$/.match(n)) {
				opt.names.push(n);
			} else if (~/^<.+?>$/.match(n) || n.toUpperCase() == n) {
				opt.hasParam = true;
			} else if (~/^-[^-].+$/.match(n)) {
				opt.names.push(n.substr(0, 2));
				opt.hasParam = true;
			} else {
				throw 'Docstring: bad option name $n';
			}
		}
		// trace(opt);
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
		function push(t)
		{
			tokens.push(t);
		}
		function hasParam(o)
		{
			if (!options.exists(o))
				return null;
			return options[o].hasParam;
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
								p = o.substr(eqi + 1);
								o = o.substr(0, eqi);
								if (!~/^<.+>$/.match(p) && p.toUpperCase() != p)
									throw 'Docstring: bad parameter format $p';
								if (hasParam(o) == false)
									throw 'Docstring: option $o does not expect param';
							}
						} else if (o.length > 2) {
							var s = o.substr(0, 2);
							if (hasParam(s))
								p = o.substr(2);
							else
								push(TOption("-" + o.substr(2)));
							o = s;
						}
						if (p == null && hasParam(o)) {
							p = switch (pop()) {
								case TArgument(a): a;
								case _: throw 'Docstring: missing parameter for $o';
								}
						}
						var opt = options[o];
						if (o == null)
							opt = { names : [o], hasParam : p != null };
						EElement(LOption(opt));
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

	static function getSection(doc:String, marker:String)
	{
		var pat = new EReg(marker, "i");
		if (!pat.match(doc))
			return null;
		var vblank = ~/\n[ \t]*\n/;
		if (vblank.match(pat.matchedRight()))
			return vblank.matchedLeft();
		else
			return pat.matchedRight();
	}

	public static function parse(doc:String):Usage
	{
		var usageText = getSection(doc, "usage:");
		if (usageText == null)
			throw 'Docstring: missing "usage:" (case insensitive) marker';
		var optionsText = getSection(doc.substr(doc.indexOf(usageText) + usageText.length), "options:");

		var options = new Map();
		if (optionsText != null) {
			for (li in optionsText.split("\n")) {
				var opt = parseOptionDesc(li);
				for (name in opt.names)
					options[name] = opt;
			}
		}

		var patterns = [ for (li in usageText.split("\n")) parsePattern(options, li.trim()) ];
		return {
			options : options,
			patterns : patterns
		};
	}
}

class DocOpt {
	static function tryMatch(args:Array<String>, expr:Expr, opts:Map<String, Option>, res:Map<String,Dynamic>):Bool
	{
		var _a = args.copy();
		var _r = new Map();
		if (match(_a, expr, opts, _r)) {
			while (args.length > _a.length)
				args.shift();
			for (k in _r.keys())
				res[k] = _r[k];
			return true;
		}
		return false;
	}

	static function match(args:Array<String>, expr:Expr, opts:Map<String, Option>, res:Map<String,Dynamic>):Bool
	{
		if (!expr.match(EOptionals(_)) && args.length < 1)
			return false;
		// trace(expr);
		switch (expr) {
		case EList(list):
			for (e in list) {
				if (!match(args, e, opts, res))
					return false;
			}
			if (args.length != 0)
				return false;
		case EElement(LArgument(name)):
			res[name] = args.shift();
		case EElement(LCommand(name)):
			if (args.shift() != name)
				return false;
			res[name] = true;
		case EElement(LOption(opt)):
			var r = null;
			var o = args.shift();
			var p = null;
			if (o.startsWith("--")) {
				var eqi = o.indexOf("=");
				if (eqi > -1) {
					p = o.substr(eqi + 1);
					o = o.substr(0, eqi);
				}
			} else if (o.length > 2) {
				r = o.substr(2);
				o = o.substr(0, 2);
			}
			if (!Lambda.has(opt.names, o))
				return false;
			if (p == null && opt.hasParam) {
				if (r != null) {
					p = r;
					r = null;
				} else if (args.length > 0) {
					p = args.shift();
				} else {
					return false;
				}
			}
			if (r != null)
				args.unshift("-" + r);
			for (n in opt.names)
				res[n] = untyped p != null ? p : true;
		case EOptionals(e):
			tryMatch(args, e, opts, res);
		case ERequired(e):
			return match(args, e, opts, res);
		case EXor(a, b):
			return tryMatch(args, a, opts, res) || tryMatch(args, b, opts, res);
		case EElipsis(e):
			// TODO deal (somewhere) with the multiple returned values
			if (!match(args, e, opts, res))
				return false;
			while (match(args, e, opts, res))
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

		trace(args);
		for (pat in usage.patterns) {
			// trace("pattern " + Lambda.indexOf(usage.patterns, pat));
			trace(pat.pattern);
			var res = new Map();
			if (match(args.copy(), pat.pattern, usage.options, res))
				return res;
		}

		return new Map();
	}
}

