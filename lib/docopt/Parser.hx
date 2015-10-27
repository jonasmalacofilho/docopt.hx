package docopt;

import docopt.Expr;
import docopt.Token;
using StringTools;

class Parser {
	static function tokensOf(li:String)
	{
		var tokenPattern = ~/(\[options\]|[()|[\]]|(\.\.\.)|[^ \t()|.[\]]+)[ \t]*/;
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
				case "[options]": TOption(null);
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
		var names = ~/[ ]|(,[ ]?)/g.split(split[0]);
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
		return opt;
	}

	static function parsePattern(options:Map<String,Option>, li:String):Pattern
	{
		li = li.trim();
		if (li == "")
			return null;
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
					case TOption(null):
						// TODO only allow if docstring has options section
						EOptionals(EElement(LOption));
					case TOption(o):
						var p = null;
						if (o.startsWith("--")) {
							var eqi = o.indexOf("=");
							if (eqi > -1) {
								p = o.substr(eqi + 1);
								o = o.substr(0, eqi);
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
							options[o] = opt = { names : [o], hasParam : p != null };
						EElement(LOption);
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
			return switch (list) {
				case []: EEmpty;
				case [e]: e;
				case li: EList(li);
				}
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
		// a section is everything from `marker` to a visibly blank line,
		// stripped of all `marker` strings in other lines too;
		// this moves forward in `doc`
		function getSection(marker:String)
		{
			var pat = new EReg(marker, "igm");
			if (!pat.match(doc))
				return null;
			var vblank = ~/\n[ \t]*\n/;
			var match = if (vblank.match(pat.matchedRight()))
					vblank.matchedLeft();
				else
					pat.matchedRight();
			doc = doc.substr(doc.indexOf(match));
			var section = match.split("\n");
			section = section.map(function (li) return pat.match(li) ? pat.matchedRight() : li);
			section = section.map(StringTools.trim);
			return section;
		}

		var usageLines = getSection("usage:");
		if (usageLines == null)
			throw 'Docstring: missing "usage:" (case insensitive) marker';
		var optionLines = getSection("options:");

		var options = new Map();
		if (optionLines != null) {
			while (optionLines.length > 0) {
				var desc = [optionLines.shift()];
				while (optionLines.length > 0 && !optionLines[0].startsWith("-"))
					desc.push(optionLines.shift());
				var opt = parseOptionDesc(desc.join("\n"));
				for (name in opt.names)
					options[name] = opt;
			}
		}

		var patterns = [ for (li in usageLines) if (li != "") parsePattern(options, li) ];
		return {
			options : options,
			patterns : patterns
		};
	}
}

