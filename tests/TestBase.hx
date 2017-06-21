package;

import sys.io.Process;

using sys.io.File;
using sys.FileSystem;

class TestBase {
	
	public static var CWD(default, null) = Sys.getCwd();
	
	public function new() {}
	
	function switchx(args:Array<String>, debug = false)
		return run('switchx', args, debug);
	
	function lix(args:Array<String>, debug = false)
		return run('node', ['$CWD/bin/lix.js'].concat(args), debug);
	
	function run(cmd, args, debug = false) {
		var proc = new Process(cmd, args);
		var stdout = proc.stdout.readAll().toString();
		var stderr = proc.stderr.readAll().toString();
		
		if(debug) {
			trace(stdout);
			trace(stderr);
		}
		
		return {
			exitCode: proc.exitCode(),
			stdout: stdout,
			stderr: stderr,
		}
	}
	
	function deleteDirectory(path:String) {
		for(p in path.readDirectory()) {
			var full = '$path/$p';
			if(full.isDirectory()) deleteDirectory(full);
			else full.deleteFile();
		}
		path.deleteDirectory();
	}
}