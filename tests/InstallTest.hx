package;

import haxe.crypto.Sha1;
import tink.unit.Assert.assert;

using sys.FileSystem;
using tink.CoreApi;

class InstallTest extends TestBase {
	var dir:String;
	
	@:before
	public function mkdir() {
		dir = Sha1.encode(Std.string(Std.random(999999))).substr(0, 12); // fancy way to make a random folder name
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
	
	public function test() {
		return assert(true);
	}
}