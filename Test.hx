package ;

class Test {
  static function main() {
    //trace(haxe.macro.Context.parse('{}', null));
    trace(parsed());
  }
  static function die(reason:String):Dynamic {
    Sys.println(reason);
    Sys.exit(500);
    return null;
  }
  macro static function parsed() {
    switch Sys.args() {
      case [file]:
        var content = 
          try sys.io.File.getContent(file)
          catch (e:Dynamic) die('failed to open $file');
      case []: die('please supply file parameter');
      default: die('too many arguments');
    }
    return macro null;
  }
}