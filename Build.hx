using haxe.io.Path;

class Build {
  static function main() {
    cmd('haxe', ['haxeshim.hxml']);
    cmd('haxe', ['lix.cli.hxml']);
    // cmd('npm i');
    for (file in sys.FileSystem.readDirectory('bin')) {
      if(file.extension() == 'js') {
        var file = 'bin/$file';
        cmd('npm run -- ncc build $file -m');
        sys.FileSystem.rename('dist/index.js', file);
      }
    }
  }
  
  static function cmd(command:String, ?args:Array<String>) {
    switch Sys.command(command, args) {
      case code if (code > 0):
        Sys.println('Errored: $command ${args == null ? '' : args.join(' ')}');
        Sys.exit(code);
      case _:
    }
  }
}