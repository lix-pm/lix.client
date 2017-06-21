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
		switchx(['scope', 'create']);
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
		lix(['install', 'haxelib:$lib']);
		var resolved = resolve(lib).split('\n');
		asserts.assert(resolved[0] == '-D');
		asserts.assert(resolved[1].startsWith('$lib='));
		asserts.assert(resolved[2] == '-cp');
		asserts.assert(regex(lib, Haxelib(None)).match(resolved[3]));
		return asserts.done();
	}
	
	@:variant('haxetink/tink_core')
	public function github(repo:String) {
		var lib = repo.split('/')[1];
		lix(['install', 'gh:$repo']);
		var resolved = resolve(lib).split('\n');
		asserts.assert(resolved[0] == '-D');
		asserts.assert(resolved[1].startsWith('$lib='));
		asserts.assert(resolved[2] == '-cp');
		asserts.assert(regex(lib, Github(None)).match(resolved[3]));
		return asserts.done();
	}
	
	@:variant('tink_core', '1.13.1')
	public function haxelibVersion(lib:String, version:String) {
		lix(['install', 'haxelib:$lib#$version']);
		var resolved = resolve(lib).split('\n');
		asserts.assert(resolved[0] == '-D');
		asserts.assert(resolved[1] == '$lib=$version');
		asserts.assert(resolved[2] == '-cp');
		asserts.assert(regex(lib, Haxelib(Some(version))).match(resolved[3]));
		return asserts.done();
	}
	
	@:variant('haxetink/tink_core', '93227943')
	public function githubHash(repo:String, hash:String) {
		var lib = repo.split('/')[1];
		lix(['install', 'gh:$repo#$hash']);
		var resolved = resolve(lib).split('\n');
		asserts.assert(resolved[0] == '-D');
		asserts.assert(resolved[1].startsWith('$lib='));
		asserts.assert(resolved[2] == '-cp');
		asserts.assert(regex(lib, Github(Some(hash))).match(resolved[3]));
		return asserts.done();
	}
	
	@:variant('haxe-react/haxe-react-native', 'react-native')
	public function githubAs(repo:String, lib:String) {
		lix(['install', 'gh:$repo', 'as', lib]);
		var resolved = resolve(lib).split('\n');
		asserts.assert(resolved[0] == '-D');
		asserts.assert(resolved[1].startsWith('$lib='));
		asserts.assert(resolved[2] == '-cp');
		asserts.assert(regex(repo.split('/')[1], Github(None)).match(resolved[3]));
		return asserts.done();
	}
	
	function resolve(lib:String, debug = false)
		return run('haxe', ['--run', 'resolve-args', '-lib', lib], debug).stdout;
	
	function regex(lib:String, type:SourceType) {
		var pattern = '/haxe_libraries/$lib/';
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