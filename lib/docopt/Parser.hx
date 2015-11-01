package docopt;

import docopt.Expr;
import docopt.Token;
using StringTools;

class Parser {
	static var hasDefault = ~/\[default:([^\]]+)\]/i;

	static function parseOptionDesc(li:String):Option
	{
		var split = li.trim().split("  ");
		var names = ~/[ ]|(,[ ]?)/g.split(split[0]);
		var desc = split.slice(1).join(" ").replace("\n", " ");

		var opt = {
			names : [],
			hasParam : false,
			defaultValue : null
		};
		for (n in names) {
			switch (Tokenizer.tokenizePattern(n).first()) {
			case TLongOption(name, param), TShortOption(name, param):
				if (param != null)
					opt.hasParam = true;
				opt.names.push(name);
			case TArgument(param):
				opt.hasParam = true;
			case _:
				throw 'Docstring: bad option name $n';
			}
		}

		if (hasDefault.match(desc))
			opt.defaultValue = hasDefault.matched(1).trim();

		return opt;
	}

	static function parsePattern(li:String, usage:Usage)
	{
		li = li.trim();
		if (li == "")
			return null;
		var tokens = Tokenizer.tokenizePattern(li);
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
			if (!usage.options.exists(o))
				return null;
			return usage.options[o].hasParam;
		}
		function expr(?breakOn)
		{
			var list = [];
			var t = pop();
			while (t != null) {
				var e = switch (t) {
					case TArgument(a):
						var arg = usage.arguments[a];
						if (arg == null)
							usage.arguments[a] = arg = { name : a };
						EArgument(arg);
					case TCommand(cmd):
						if (!usage.commands.exists(cmd))
							usage.commands[cmd] = cmd;
						ECommand(cmd);
					case TOptionsShortcut:
						if (!usage.hasOptionsSection)
							throw 'Docstring: [options] requires option descriptions section';
						EOptionals(EOption(null));
					case TLongOption(name, val), TShortOption(name, val):
						if (val != null && hasParam(name) == false) {
							if (t.match(TLongOption(_, _)))
								throw 'Docstring: option $name does not expect param';
							else if (val.length > 1)
								push(TShortOption("-" + val.charAt(0), val.substr(1)));
							else
								push(TShortOption("-" + val.charAt(0)));
						}
						if (val == null && hasParam(name)) {
							val = switch (pop()) {
								case TArgument(a): a;
								case _: throw 'Docstring: missing parameter for $name';
							}
						}
						var opt = usage.options[name];
						if (opt == null) {
							opt = usage.options[name] = {
								names : [name],
								hasParam : val != null,
								defaultValue : null
							};
						}
						EOption(opt);
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
				case a: throw 'Docstring: bad executable name $a';
			}
		}
		function pattern()
		{
			return {
				executable : executable(),
				pattern : expr()
			}
		}
		usage.patterns.push(pattern());
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
			var section = match.trim().split("\n");
			section = section.map(function (li) return pat.match(li) ? pat.matchedRight() : li);
			section = section.map(StringTools.trim);
			return section;
		}

		var usageLines = getSection("usage:");
		if (usageLines == null)
			throw 'Docstring: missing "usage:" (case insensitive) marker';
		var optionLines = getSection("options:");

		var usage = {
			arguments : new Map(),
			commands : new Map(),
			options : new Map(),
			patterns : [],
			hasOptionsSection : false
		};

		if (optionLines != null) {
			usage.hasOptionsSection = true;
			while (optionLines.length > 0) {
				var desc = [optionLines.shift()];
				while (optionLines.length > 0 && !optionLines[0].startsWith("-"))
					desc.push(optionLines.shift());
				var opt = parseOptionDesc(desc.join("\n").trim());
				for (name in opt.names)
					usage.options[name] = opt;
			}
		}

		for (li in usageLines)
			parsePattern(li, usage);

		return usage;
	}
}

