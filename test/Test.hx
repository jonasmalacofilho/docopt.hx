import utest.*;
import utest.ui.*;

class Test {
	public function new() {}

	public function test_101_docstring_parser()
	{
		var navalFate = "
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
		docopt.DocstringParser.parse(navalFate);
	}

	public static function main()
	{
		var runner = new Runner();

		runner.addCase(new Test());

		Report.create(runner);
		runner.run();
	}
}

