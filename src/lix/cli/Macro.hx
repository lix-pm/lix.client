package lix.cli;

class Macro {
	public static macro function getVersion() {
		return macro $v{haxe.Json.parse(sys.io.File.getContent('./package.json')).version};
	}
}