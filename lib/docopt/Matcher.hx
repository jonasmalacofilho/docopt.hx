package docopt;

import docopt.Expr;
using StringTools;

class Matcher {
	static function makeRes(usage:Usage):Map<String,Dynamic>
	{
		var res = new Map<String,Dynamic>();
		for (o in usage.options) {
			var init = o.hasParam ? null : false;
			for (n in o.names)
				res[n] = init;
		}

		function addToRes(expr:Expr)
		{
			switch (expr) {
			case EEmpty: return;
			case EList(li): for (e in li) addToRes(e);
			case EElement(LArgument(n)): res[n] = null;
			case EElement(LCommand(n)): res[n] = false;
			case EElement(LOption): return;
			case EOptionals(e), ERequired(e), EElipsis(e): addToRes(e);
			case EXor(a, b): addToRes(a); addToRes(b);
			}
		}
		for (p in usage.patterns)
			addToRes(p.pattern);

		return res;
	}

	static function tryMatchExpr(args:Array<String>, expr:Expr, opts:Map<String, Option>, res:Map<String,Dynamic>):Bool
	{
		var _a = args.copy();
		var _r = new Map();
		if (matchExpr(_a, expr, opts, _r)) {
			while (args.length > _a.length)
				args.shift();
			for (k in _r.keys())
				res[k] = _r[k];
			return true;
		}
		return false;
	}

	static function matchExpr(args:Array<String>, expr:Expr, opts:Map<String, Option>, res:Map<String,Dynamic>):Bool
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
		case EElement(LArgument(name)):
			res[name] = args.shift();
		case EElement(LCommand(name)):
			if (args.shift() != name)
				return false;
			res[name] = true;
		case EElement(LOption):
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
			var opt = null;
			for (_opt in opts) {
				if (Lambda.has(_opt.names, o)) {
					opt = _opt;
					break;
				}
			}
			if (opt == null) {
				for (_opt in opts) {
					if (Lambda.exists(_opt.names, function (n) return n.startsWith(o))) {
						opt = _opt;
						break;
					}
				}
			}
			if (opt == null)
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
		}
		return true;
	}

	public static function match(usage, pat, args)
	{
		var _args = args.copy();
		var res = makeRes(usage);
		if (matchExpr(_args, pat.pattern, usage.options, res) && _args.length == 0)
			return res;
		return null;
	}
}

