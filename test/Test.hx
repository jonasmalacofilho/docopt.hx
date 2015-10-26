import utest.*;
import utest.ui.*;

class Test {
	static function assertKeyVals<K>(exp:Map<K, Dynamic>, got:Map<K, Dynamic>, ?msg:String, ?pos:haxe.PosInfos)
	{
		msg = msg == null ? "" : '$msg: ';
		for (k in exp.keys()) {
			Assert.isTrue(got.exists(k), '${msg}missing key $k', pos);
			Assert.same(exp[k], got[k], '${msg}for key $k, expected ${exp[k]} but got ${got[k]}', pos);
		}
	}

	static inline function assert(exp, usage, args, ?pos:haxe.PosInfos)
	{
		var opts = DocOpt.docopt(usage, args);
		Assert.notNull(opts, "no usage pattern matched", pos);
		if (opts != null)
			assertKeyVals(exp, opts, pos);
	}

	static inline function assertFail(usage, args, ?pos:haxe.PosInfos)
	{
		Assert.isNull(DocOpt.docopt(usage, args));
	}

	public function new() {}

	public function test_100_doctrim()
	{
		var usage = "
		Foo.

		Usage:
			foo [options]

		";
		Assert.equals("Foo.\n\nUsage:\n\tfoo [options]", DocOpt.doctrim(usage));  // TODO should end with \n ??
	}

	public function test_101_navalFate()
	{
		var usage = "
		Naval Fate.

		Usage:
			naval_fate ship new <name>...
			naval_fate ship <name> move <x> <y> [--speed=<kn>]
			naval_fate ship shoot <x> <y>
			naval_fate mine (set|remove) <x> <y> [--moored|--drifting]
			naval_fate -h | --help
			naval_fate --version

		Options:
			-h --help     Show this screen.
			--version     Show version.
			--speed=<kn>  Speed in knots [default: 10].
			--moored      Moored (anchored) mine.
			--drifting    Drifting mine.
		";
		assert(["ship"=>true, "new"=>true, "<name>"=>"Guardian"],
			usage, "ship new Guardian".split(" "));
		assert(["ship"=>true, "<name>"=>"Guardian", "move"=>true, "<x>"=>"10", "<y>"=>"50", "--speed"=>"20"],
			usage, "ship Guardian move 10 50 --speed 20".split(" "));
		assert(["ship"=>true, "shoot"=>true, "<x>"=>"20", "<y>"=>"40"],
			usage, "ship shoot 20 40".split(" "));
		assert(["mine"=>true, "set"=>true, "<x>"=>"5", "<y>"=>"45"],  // TODO remove=>false
			usage, "mine set 5 45".split(" "));
		assert(["mine"=>true, "remove"=>true, "<x>"=>"15", "<y>"=>"55"],  // TODO set=>false
			usage, "mine remove 15 55".split(" "));
		assert(["-h"=>true, "--help"=>true],
			usage, ["-h"]);
		assert(["-h"=>true, "--help"=>true],
			usage, ["--help"]);
		assert(["--version"=>true],
			usage, ["--version"]);
	}

	public function test_102_extendedNavalFate()
	{
		var usage = "
		Naval Fate.

		Usage:
			naval_fate ship new <name>...
			naval_fate ship <name> move <x> <y> [--speed=<kn>]
			naval_fate ship shoot <x> <y>
			naval_fate mine (set|remove) <x> <y> [--moored|--drifting]
			naval_fate -h | --help
			naval_fate --version

		Options:
			-h --help        Show this screen.
			-v --version     Show version.
			-s <kn> -k KN -p<kn> -eKN --speed=<kn>     Speed in knots [default: 10].
			--moored         Moored (anchored) mine.
			--drifting       Drifting mine.
		";
		assert(["--version"=>true, "-v"=>true],
			usage, ["-v"]);
		assert(["--speed"=>"20", "-s"=>"20", "-k"=>"20", "-p"=>"20", "-e"=>"20"],
			usage, "ship Guardian move 10 50 -s 20".split(" "));
		assert(["--speed"=>"20", "-s"=>"20", "-k"=>"20", "-p"=>"20", "-e"=>"20"],
			usage, "ship Guardian move 10 50 -k 20".split(" "));
		assert(["--speed"=>"20", "-s"=>"20", "-k"=>"20", "-p"=>"20", "-e"=>"20"],
			usage, "ship Guardian move 10 50 -p20".split(" "));
		assert(["--speed"=>"20", "-s"=>"20", "-k"=>"20", "-p"=>"20", "-e"=>"20"],
			usage, "ship Guardian move 10 50 -e20".split(" "));
		assert(["--speed"=>"20", "-s"=>"20", "-k"=>"20", "-p"=>"20", "-e"=>"20"],
			usage, "ship Guardian move 10 50 --speed=20".split(" "));
	}

	public function test_999_testcases_docopt()
	{
		var res = haxe.Resource.getString("testcases.docopt");

		var lines = res.split("\n").map(function (li) return li.split("#")[0]);
		var lineNumber = 0;
		function readLine()
		{
			if (lines.length == 0)
				return null;
			lineNumber++;
			return lines.shift();
		}

		function makePos()
		{
			return {
				fileName : "@testcases.docopt",
				lineNumber : lineNumber,
				className : "",
				methodName : "",
				customParams : null
			}
		}

		var cnt = 0;
		var usagePat = ~/^r"""(.+)"""$/s;
		var argsPat = ~/^\$ (.+)/;
		while (lines.length > 0) {
			while (lines[0] == "")
				readLine();
			var ulines = [];
			while (!StringTools.startsWith(lines[0], "$ "))
				ulines.push(readLine());
			var usage = ulines.join("\n");
			if (!usagePat.match(usage))
				throw 'Unexpected usage format: $usage';
			usage = usagePat.matched(1);

			while (lines.length > 0 && StringTools.startsWith(lines[0], "$ ")) {
				var argsLine = readLine();
				if (!argsPat.match(argsLine))
					throw 'Unexpected args format: $argsLine';
				var args = argsPat.matched(1).split(" ");

				var elines = [];
				while (lines[0] != "")
					elines.push(readLine());
				var expJson = elines.join("\n");
				var exp = null;
				if (expJson == '"user-error"') {
					// TODO
				} else {
					var obj = haxe.Json.parse(expJson);
					exp = new Map();
					for (k in Reflect.fields(obj))
						exp[k] = Reflect.field(obj, k);
					assert(exp, usage, args.slice(1), makePos());
				}

				cnt++;
				readLine();
			}
		}
		trace('Total test cases from testcases.docopt: $cnt');
	}

	public static function main()
	{
		var runner = new Runner();

		runner.addCase(new Test());

		Report.create(runner);
		runner.run();
	}
}

