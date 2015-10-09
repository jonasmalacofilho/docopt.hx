package docopt;

using StringTools;

#if macro
import haxe.macro.Expr;
#end

private enum Token {
	TWord(w:String);
	TNewline;  // [\n]
	TOpenBracket;
	TCloseBracket;
	TOpenParens;
	TCloseParens;
	TPipe;
	TEof;
}

class DocstringParser {
	var buf:String;
	var rem:String;
	@:isVar var pos(default,set):Int;
		function set_pos(p)
		{
			pos = p;
			rem = buf.substr(p);
			return p;
		}


	function readText(p:String)
	{
		var i = rem.indexOf(p);
		if (i == -1)
			return null;
		pos += p.length;
		return p;
	}

	function readRegex(r:EReg)
	{
		if (!r.match(rem))
			return null;
		var rpos = r.matchedPos();
		pos += rpos.pos + rpos.len;
		return r.matched(0).trim();
	}


	function parseToken()
	{
		readRegex(~/[\t ]+/);

		if (readText("[") != null)
			return TOpenBracket;
		if (readText("]") != null)
			return TCloseBracket;
		if (readText("(") != null)
			return TOpenParens;
		if (readText(")") != null)
			return TCloseParens;
		if (readText("|") != null)
			return TPipe;
		if (readText("\n") != null)
			return TNewline;

		var word = readRegex(~/[^\t\n]+/);
		if (word != null)
			return TWord(word);

		return TEof;
	}

	function rewind(t:Token)
	{
		switch (t) {
		case TWord(s): pos -= s.length;
		case _: pos--;
		}
	}

	function parseExecutable()
	{
		var w = parseToken();
		if (!w.match(TWord(_)))
			throw "The minimal pattern is 'executable_name'";
		return w;
	}

	function parsePattern()
	{
		var patterns = [];
		patterns.push(parseExecutable());
		// FIXME
		return patterns;
	}

	function parseUsage()
	{
		var mark = readRegex(~/usage:/i);
		if (mark == null)
			throw "Missing 'usage:' section";
		var usage = [];
		var p = parsePattern();
		while (p != null) {
			usage.push(p);
			p = parsePattern();
		}
		if (usage.length < 1)
			throw "At least one usage pattern required";
		return usage;
	}

	function new(doc)
	{
		buf = doc;
		pos = 0;
	}

	public static function parse(doc:String)
	{
		var p = new DocstringParser(doc);
		trace(p.parseUsage());
	}
}

