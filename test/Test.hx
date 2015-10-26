import utest.*;
import utest.ui.*;

class Test {
	public function new() {}

	public function test_100_doctrim()
	{
		var usage = "
		Foo.

		Usage:
			foo [options]

		";
		trace(DocOpt.doctrim(usage));
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
		trace(DocOpt.docopt(usage, ["ship", "new", "Guardian"]));
		trace(DocOpt.docopt(usage, ["ship", "Guardian", "move", "10", "50", "--speed", "20"]));
		trace(DocOpt.docopt(usage, ["ship", "shoot", "20", "40"]));
		trace(DocOpt.docopt(usage, ["mine", "set", "5", "45"]));
		trace(DocOpt.docopt(usage, ["mine", "remove", "15", "55"]));
		trace(DocOpt.docopt(usage, ["-h"]));
		trace(DocOpt.docopt(usage, ["--help"]));
		trace(DocOpt.docopt(usage, ["--version"]));
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
		trace(DocOpt.docopt(usage, ["-v"]));
		trace(DocOpt.docopt(usage, ["ship", "Guardian", "move", "10", "50", "-s", "20"]));
		trace(DocOpt.docopt(usage, ["ship", "Guardian", "move", "10", "50", "-k", "20"]));
		trace(DocOpt.docopt(usage, ["ship", "Guardian", "move", "10", "50", "-p20"]));
		trace(DocOpt.docopt(usage, ["ship", "Guardian", "move", "10", "50", "-e20"]));
		trace(DocOpt.docopt(usage, ["ship", "Guardian", "move", "10", "50", "--speed=20"]));
	}

	public static function main()
	{
		var runner = new Runner();

		runner.addCase(new Test());

		Report.create(runner);
		runner.run();
	}
}

