using StringTools;

import docopt.*;

class DocOpt {
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
		var doc = doctrim(doc);
		var usage = Parser.parse(doc);
		// trace("usage " + usage);
		trace("options " + usage.options);

		trace("args " + args);
		for (pat in usage.patterns) {
			trace("pattern " + Lambda.indexOf(usage.patterns, pat));
			// trace("expr " + pat.pattern);
			var res = Matcher.matchPattern(usage, pat, args);
			if (res != null)
				return res;
			trace("failed match");
		}

		return null;
	}
}

