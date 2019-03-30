using haxe.io.Path;

class Build {
  static function main() {
    cmd('haxe', ['haxeshim.hxml']);
    cmd('haxe', ['lix.cli.hxml']);
    for (file in sys.FileSystem.readDirectory('bin')) {
      if(file.extension() == 'js') {
        var file = 'bin/$file';
        var tmp = '$file.bundled';
        cmd('npm run --silent noderify $file > $tmp');
        sys.FileSystem.rename(tmp, file);
      }
    }
  }
  
  static function cmd(command:String, ?args:Array<String>) {
    if(Sys.command(command, args) != 0) throw 'Errored: $command ${args.join(' ')}';
  }
}