package docopt;

import docopt.Element;
import docopt.Expr;
import docopt.Token;
using StringTools;

typedef Value = {
	name : String,
	value : Dynamic
}

enum MatchResult {
	Fail;
	Matched(collected:Array<Value>, left:Array<ArgumentToken>);
}

class Matcher {
	var usage:Usage;

	function makeRes():Map<String,Dynamic>
	{
		var res = new Map<String,Dynamic>();
		for (o in usage.options) {
			var init:Dynamic = o.hasParam ? o.defaultValue : false;
			for (n in o.names)
				res[n] = init;
		}

		function addToRes(expr:Expr)
		{
			switch (expr) {
			case EEmpty: return;
			case EList(li): for (e in li) addToRes(e);
			case EArgument(arg): res[arg.name] = null;
			case ECommand(cmd): res[cmd] = false;
			case EOption(opt): return;
			case EOptionals(e), ERequired(e), EElipsis(e): addToRes(e);
			case EXor(a, b): addToRes(a); addToRes(b);
			}
		}
		for (p in usage.patterns)
			addToRes(p.pattern);

		return res;
	}

	function popArgument(args:Array<ArgumentToken>)
	{
		for (a in args) {
			switch (a) {
			case AArgument(arg):
				args.remove(a);
				return arg;
			case _: // NOOP
			}
		}
		return null;
	}

	function popOption(args:Array<ArgumentToken>, ?names:Array<String>)
	{
		for (a in args) {
			switch (a) {
			case ALongOption(name, param), AShortOption(name, param):
				if (names == null || Lambda.has(names, name)) {
					args.remove(a);
					return { name : name, param : param, arg : a };
				}
			case _: // NOOP
			}
		}
		return null;
	}

	function join(collected:Array<Value>, left:Array<ArgumentToken>, result:MatchResult)
	{
		return switch (result) {
			case Fail: false;
			case Matched(c, l):
				for (v in c)
					collected.push(v);
				var rm = [ for (a in left) if (!Lambda.has(l, a)) a ];
				while (rm.length > 0)
					left.remove(rm.shift());
				true;
			}
	}

	function match(expr:Expr, args:Array<ArgumentToken>):MatchResult
	{
		trace("matching " + expr);
		if (!expr.match(EOptionals(_) | EEmpty) && args.length < 1)
			return Fail;
		var collected = [];
		var left = args.copy();
		trace(collected);
		trace(left);
		switch (expr) {
		case EEmpty:  // NOOP
		case EList(list):
			for (e in list)
				if (!join(collected, left, match(e, left)))
					return Fail;
		case EOptionals(EList(list)):
			var s = false;
			for (e in list)
				s = join(collected, left, match(e, left)) || s;
			if (!s)
				return Fail;
		case EOptionals(e):
			join(collected, left, match(e, left));
		case EElipsis(EOptionals(e)):
			return match(EOptionals(EElipsis(e)), left);
		case EElipsis(e):
			if (!join(collected, left, match(e, left)))
				return Fail;
			while (join(collected, left, match(e, left)))
				null;  // NOOP
		case ERequired(e):
			return match(e, left);
		case EXor(a, b):
			var ma = match(a, left);
			var mb = match(b, left);
			return switch [ma, mb] {
				case [Matched(_), Fail]: ma;
				case [Fail, Matched(_)]: mb;
				case [Matched(_, la), Matched(_, lb)]: la.length < lb.length ? ma : mb;
				case [Fail, Fail]: Fail;
				}
		case EArgument(arg):
			var val = popArgument(left);
			if (val == null)
				return Fail;
			collected.push({ name : arg.name, value : val });
		case ECommand(name):
			var val = popArgument(left);
			if (val != name)
				return Fail;
			collected.push({ name : name, value : true });
		case EOption(null):
			// FIXME don't try each option more than once
			// FIXME don't try options in the pattern
			// TODO maybe move this in the parser
			var s = false;
			for (opt in usage.options)
				s = join(collected, left, match(EOption(opt), left)) || s;
			if (!s)
				return Fail;
		case EOption(opt):
			var val = popOption(left, opt.names);
			if (val == null)
				return Fail;
			if (opt.hasParam && val.param == null) {
				if (left.length > 0) {
					val.param = popArgument(left);
				} else {
					return Fail;
				}
			} else if (!opt.hasParam && val.param != null) {
				if (val.arg.match(AShortOption(_))) {
					throw 'Assert fail: short option with unexpected param';
				} else {
					return Fail;
				}
			}
			for (n in opt.names) {
				var val:Dynamic = val.param != null ? val.param : true;
				collected.push({ name : n, value : val });
			}
		}
		return Matched(collected, left);
	}

	public function matchPattern(pat, args)
	{
		var args = Tokenizer.tokenizeArguments(args, usage.options);
		var res = makeRes();
		return switch (match(pat.pattern, args)) {
			case Matched(collected, left) if (left.length == 0):
				var r = makeRes();
				for (v in collected) {
					// TODO deal with multiple returned values
					r[v.name] = v.value;
				}
				r;
			case _:
				null;
			}
	}

	public function new(usage)
	{
		this.usage = usage;
	}
}

