package lix.cli;

class NekoCmd {
  static public function ensure()
    return 
      lix.client.haxe.Switcher.ensureNeko(println);

  static function main() 
    Command.attempt(ensure(), @:privateAccess NekoCli.main);
}