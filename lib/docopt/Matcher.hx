package docopt;

import docopt.Element;
import docopt.Expr;
import docopt.Token;
using StringTools;

class Matcher {
	static function makeRes(usage:Usage):Map<String,Dynamic>
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

	static function popArgument(args:List<ArgumentToken>)
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

	static function popOption(args:List<ArgumentToken>, ?names:Array<String>)
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

	static function match(args:List<ArgumentToken>, expr:Expr, opts:Map<String, Option>, res:Map<String,Dynamic>):Bool
	{
		trace("matching " + expr);
		if (!expr.match(EOptionals(_) | EEmpty) && args.length < 1)
			return false;
		var _args = Lambda.list(args);
		var _res = new Map<String,Dynamic>();
		switch (expr) {
		case EEmpty:  // NOOP
		case EList(list):
			for (e in list) {
				if (!match(_args, e, opts, _res))
					return false;
			}
		case EOptionals(e):
			match(_args, e, opts, _res);
		case ERequired(e):
			if (!match(args, e, opts, res))
				return false;
		case EXor(a, b):
			if (!match(args, a, opts, res) && !match(args, b, opts, res))
				return false;
		case EElipsis(EOptionals(e)):
			match(_args, e, opts, _res);
			while (match(_args, e, opts, _res))
				true;  // NOOP
		case EElipsis(e):
			// TODO deal (somewhere) with the multiple returned values
			if (!match(_args, e, opts, _res))
				return false;
			while (match(_args, e, opts, _res))
				true;  // NOOP
		case EArgument(arg):
			var val = popArgument(_args);
			if (val == null)
				return false;
			_res[arg.name] = val;
		case ECommand(name):
			var val = popArgument(_args);
			if (val != name)
				return false;
			_res[name] = true;
		case EOption(null):
			// FIXME don't try each option more than once
			// FIXME don't try options in the pattern
			// TODO maybe move this in the parser
			var succeeded = false;
			for (opt in opts)
				succeeded = match(_args, EOption(opt), opts, _res) || succeeded;
			if (!succeeded)
				return false;
		case EOption(opt):
			var val = popOption(_args, opt.names);
			if (val == null)
				return false;
			if (opt.hasParam && val.param == null) {
				if (_args.length > 0) {
					val.param = popArgument(_args);
				} else {
					return false;
				}
			} else if (!opt.hasParam && val.param != null) {
				if (val.arg.match(AShortOption(_))) {
					throw 'Assert fail: !opt.hasParam && val.param != null && val.arg.match(AShortOption(_))';
				} else {
					return false;
				}
			}
			for (n in opt.names)
				_res[n] = untyped val.param != null ? val.param : true;
		}
		var rem = [ for (a in args) if (!Lambda.has(_args, a)) a];
		while (rem.length > 0)
			args.remove(rem.pop());
		for (k in _res.keys())
			res[k] = _res[k];
		return true;
	}

	public static function matchPattern(usage, pat, args)
	{
		var args = Tokenizer.tokenizeArguments(args, usage.options);
		var res = makeRes(usage);
		if (match(args, pat.pattern, usage.options, res) && args.length == 0)
			return res;
		return null;
	}
}

