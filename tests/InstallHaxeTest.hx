package;

import tink.unit.Assert.assert;

using sys.FileSystem;
using tink.CoreApi;
using StringTools;

@:asserts
class InstallHaxeTest extends TestBase {
	var dir:String;
	
	@:before
	public function mkdir() {
		dir = 'test_' + Date.now().getTime() + '_' + Std.random(1<<24); // fancy way to make a random folder name
		dir.createDirectory();
		Sys.setCwd(dir);
		runLix(['scope', 'create']);
		return Noise;
	}
	
	@:after
	public function rmrf() {
		Sys.setCwd(TestBase.CWD);
		deleteDirectory(dir);
		return Noise;
	}
	
	@:variant('3.4.7')
	@:variant('4.0.0-preview.4')
	public function installHaxe(version:String) {
		runLix('install haxe $version');
		asserts.assert(getVersion() == version);
		return asserts.done();
	}
	
	// an hxmc build by its commit: pinned to its npm version in .haxerc, the compiler answering as Haxe 5
	public function installHxmc() {
		runLix('install haxe hxmc-a5a73c2');
		asserts.assert(haxe.Json.parse(sys.io.File.getContent('.haxerc')).version == 'hxmc-0.1.0-nightly.20261125.a5a73c2');
		asserts.assert(getVersion().startsWith('5.'));
		return asserts.done();
	}

	function getVersion(debug = false) {
		var proc = runHaxe(['-version'], debug);
		
		var v = switch proc.stdout {
			case '': proc.stderr;
			case v: v;
		}
		
		return v.trim().split('+')[0];
	}
}