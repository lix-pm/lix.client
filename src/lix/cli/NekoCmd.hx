package lix.cli;

class NekoCmd {
  static public function ensure(andThen:Void->Void)
    lix.client.haxe.Switcher.ensureNeko(println)
      .recover(Command.reportError)
      .handle(andThen);

  static function main() 
    ensure(@:privateAccess NekoCli.main);
}