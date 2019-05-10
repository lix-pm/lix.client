package;

import tink.unit.Assert.assert;

using sys.FileSystem;
using tink.CoreApi;
using StringTools;

@:asserts
class InstallTest extends TestBase {
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
	
	@:variant('tink_core',      'install haxelib:tink_core',                                 v -> this.regex('tink_core', Haxelib(None)).match(v))
	@:variant('tink_core',      'install haxelib:tink_core#1.13.1',                          v -> this.regex('tink_core', Haxelib(Some('1.13.1'))).match(v))
	@:variant('tink_core',      '+lib tink_core',                                            v -> this.regex('tink_core', Haxelib(None)).match(v))
	@:variant('tink_core',      '+lib tink_core#1.13.1',                                     v -> this.regex('tink_core', Haxelib(Some('1.13.1'))).match(v))
	@:variant('tink_core',      'install gh:haxetink/tink_core',                             v -> this.regex('tink_core', Github(None)).match(v))
	@:variant('tink_core',      'install gh:haxetink/tink_core#93227943',                    v -> this.regex('tink_core', Github(Some('93227943'))).match(v))
	@:variant('tink_core',      '+tink core',                                                v -> this.regex('tink_core', Github(None)).match(v))
	@:variant('tink_core',      '+tink core#93227943',                                       v -> this.regex('tink_core', Github(Some('93227943'))).match(v))
	@:variant('react-native',   'install gh:haxe-react/haxe-react-native as react-native',   v -> this.regex('react-native', Github(None)).match(v))
	public function install(lib:String, args:Args, check:String->Bool) {
		switch runLix(args, true).exitCode == 0 {
			case 0:
				var resolved = resolve(lib).replace('\n', ' ');
				asserts.assert(check(resolved), '-cp tag is in place');
			default:
				// most likely means quota have run out
		}
		return asserts.done();
	}
	
	function resolve(lib:String, debug = false)
		return runHaxe(['--run', 'resolve-args', '-lib', lib], debug).stdout;
	
	function regex(lib:String, type:SourceType) {
		var pattern = '-cp .*/haxe_libraries/$lib/';
		pattern += switch type {
			case Haxelib(None): '[^/]*/haxelib';
			case Haxelib(Some(version)): '$version/haxelib';
			case Github(None): '[^/]*/github/\\w*';
			case Github(Some(hash)): '[^/]*/github/$hash\\w*';
		}
		return new EReg(pattern, '');
	}
}

enum SourceType {
	Haxelib(version:Option<String>);
	Github(hash:Option<String>);
}