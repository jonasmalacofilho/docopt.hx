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

	static function tryMatchExpr(args:List<ArgumentToken>, expr:Expr, opts:Map<String, Option>, res:Map<String,Dynamic>):Bool
	{
		var _a = Lambda.list(args);
		var _r = new Map();
		if (matchExpr(_a, expr, opts, _r)) {
			var rem = [ for (arg in args) if (!Lambda.has(_a, arg)) arg];
			while (rem.length > 0)
				args.remove(rem.pop());
			for (k in _r.keys())
				res[k] = _r[k];
			return true;
		}
		return false;
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

	static function matchExpr(args:List<ArgumentToken>, expr:Expr, opts:Map<String, Option>, res:Map<String,Dynamic>):Bool
	{
		if (!expr.match(EOptionals(_) | EEmpty) && args.length < 1)
			return false;
		trace("matching " + expr);
		switch (expr) {
		case EEmpty:  // NOOP
		case EList(list):
			for (e in list) {
				if (!matchExpr(args, e, opts, res))
					return false;
			}
		case EOptionals(e):
			tryMatchExpr(args, e, opts, res);
		case ERequired(e):
			return matchExpr(args, e, opts, res);
		case EXor(a, b):
			return tryMatchExpr(args, a, opts, res) || tryMatchExpr(args, b, opts, res);
		case EElipsis(EOptionals(e)):
			tryMatchExpr(args, e, opts, res);
			while (tryMatchExpr(args, e, opts, res))
				true;  // NOOP
		case EElipsis(e):
			// TODO deal (somewhere) with the multiple returned values
			if (!matchExpr(args, e, opts, res))
				return false;
			while (matchExpr(args, e, opts, res))
				true;  // NOOP
		case EArgument(arg):
			var val = popArgument(args);
			if (val == null)
				return false;
			res[arg.name] = val;
		case ECommand(name):
			var val = popArgument(args);
			if (val != name)
				return false;
			res[name] = true;
		case EOption(null):
			// FIXME don't try each option more than once
			// FIXME don't try options in the pattern
			// TODO maybe move this in the parser
			for (opt in opts)
				matchExpr(args, EOption(opt), opts, res);
		case EOption(opt):
			var val = popOption(args, opt.names);
			if (val == null)
				return false;
			if (opt.hasParam && val.param == null) {
				if (args.length > 0) {
					val.param = popArgument(args);
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
				res[n] = untyped val.param != null ? val.param : true;
		}
		return true;
	}

	public static function match(usage, pat, args)
	{
		var args = Tokenizer.tokenizeArguments(args, usage.options);
		var res = makeRes(usage);
		if (matchExpr(args, pat.pattern, usage.options, res) && args.length == 0)
			return res;
		return null;
	}
}

