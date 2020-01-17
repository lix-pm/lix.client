package ;

class Helpers {
  static public function cmd(cmd:String, ?args:Array<String>)
    switch Sys.command(cmd, args) {
      case 0:
      case v: Sys.exit(v);
    }
}