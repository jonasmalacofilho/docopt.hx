package docopt;

import docopt.Element;
import docopt.Token;

class Tokenizer {
	static var isArgument = ~/^((<.+?>)|([^a-z]*[A-Z]+[^a-z]*))$/;
	static var isLongOption = ~/^(--.+?)(=(.+))?$/;
	static var isShortOption = ~/^(-[^-])$/;
	static var isShortOptionCat = ~/^(-[^-])(.+)$/;

	static function tokenizeArgument(arg:String):ArgumentToken
	{
		return if (isLongOption.match(arg))
				ALongOption(isLongOption.matched(1), isLongOption.matched(3));
			else if (isShortOption.match(arg))
				AShortOption(isShortOption.matched(0), null);
			else if (isShortOptionCat.match(arg))
				AShortOption(isShortOptionCat.matched(1), isShortOptionCat.matched(2));
			else
				AArgument(arg);
	}

	public static function tokenizePattern(li:String):List<PatternToken>
	{
		var tokenPattern = ~/(\[options\]|[()|[\]]|(\.\.\.)|[^ \t()|.[\]]+)[ \t]*/;
		var tokens = new List();
		while (tokenPattern.match(li)) {
			var t = switch (tokenPattern.matched(1)) {
				case "[": TOpenBracket;
				case "]": TCloseBracket;
				case "(": TOpenParens;
				case ")": TCloseParens;
				case "|": TPipe;
				case "...": TElipsis;
				case _.toLowerCase() => "[options]": TOptionsShortcut;
				case w:
					if (isLongOption.match(w))
						TLongOption(isLongOption.matched(1), isLongOption.matched(3));
					else if (isShortOption.match(w))
						TShortOption(isShortOption.matched(0), null);
					else if (isShortOptionCat.match(w))
						TShortOption(isShortOptionCat.matched(1), isShortOptionCat.matched(2));
					else if (isArgument.match(w))
						TArgument(w);
					else
						TCommand(w);
				}
			tokens.add(t);
			li = tokenPattern.matchedRight();
		}
		return tokens;
	}

	public static function tokenizeArguments(args:Array<String>, opts:Map<String,Option>):List<ArgumentToken>
	{
		var args = args.copy();
		var tokens = new List();
		while (args.length > 0) {
			var t = tokenizeArgument(args.shift());
			switch (t) {
			case AShortOption(name, rest) if (rest != null && opts.exists(name) && !opts[name].hasParam):
				t = AShortOption(name, null);
				args.unshift("-" + rest);
			case _: // NOOP
			}
			tokens.add(t);
		}
		return tokens;
	}
}

