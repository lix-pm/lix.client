using haxe.io.Path;

class Build {
  static function main() {
    Sys.command('haxe', ['haxeshim.hxml']);
    Sys.command('haxe', ['lix.cli.hxml']);
    for (file in sys.FileSystem.readDirectory('bin')) {
      if(file.extension() == 'js') {
        var file = 'bin/$file';
        var tmp = '$file.bundled';
        Sys.command('npm run --silent noderify $file > $tmp');
        sys.FileSystem.rename(tmp, file);
      }
    }
  }
}