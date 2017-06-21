package;

import haxe.crypto.Sha1;
import tink.unit.Assert.assert;

using sys.FileSystem;
using tink.CoreApi;
using StringTools;

@:asserts
class InstallTest extends TestBase {
	var dir:String;
	
	@:before
	public function mkdir() {
		dir = 'test_' + Sha1.encode(Std.string(Std.random(999999))).substr(0, 12); // fancy way to make a random folder name
		dir.createDirectory();
		Sys.setCwd(dir);
		return Noise;
	}
	
	@:after
	public function rmrf() {
		Sys.setCwd(TestBase.CWD);
		deleteDirectory(dir);
		return Noise;
	}
	
	@:variant('tink_core')
	public function haxelib(lib:String) {
		switchx(['scope', 'create']);
		lix(['install', 'haxelib:$lib']);
		var resolved = run('haxe', ['--run', 'resolve-args', '-lib', lib]).stdout.split('\n');
		asserts.assert(resolved[0] == '-D');
		asserts.assert(resolved[1].startsWith('$lib='));
		asserts.assert(resolved[2] == '-cp');
		asserts.assert(regex(lib, Haxelib(None)).match(resolved[3]));
		return asserts.done();
	}
	
	@:variant('haxetink/tink_core')
	public function github(repo:String) {
		var lib = repo.split('/')[1];
		switchx(['scope', 'create']);
		lix(['install', 'gh:$repo']);
		var resolved = run('haxe', ['--run', 'resolve-args', '-lib', lib]).stdout.split('\n');
		asserts.assert(resolved[0] == '-D');
		asserts.assert(resolved[1].startsWith('$lib='));
		asserts.assert(resolved[2] == '-cp');
		trace(resolved[3]);
		asserts.assert(regex(lib, Github(None)).match(resolved[3]));
		return asserts.done();
	}
	
	function regex(lib:String, type:SourceType) {
		var pattern = '/haxe_libraries/$lib/';
		pattern += switch type {
			case Haxelib(None): '[^/]*/haxelib/';
			case Haxelib(version): '$version/haxelib/';
			case Github(None): '[^/]*/github/\\w*/';
			case Github(hash): '[^/]*/github/$hash\\w*/';
		}
		
		pattern += 'src';
		return new EReg(pattern, '');
	}
}

enum SourceType {
	Haxelib(version:Option<String>);
	Github(hash:Option<String>);
}