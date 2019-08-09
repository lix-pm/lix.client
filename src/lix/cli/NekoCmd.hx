package lix.cli;

class NekoCmd {
  static public function ensure(logger)
    return 
      lix.client.haxe.Switcher.ensureNeko(logger);

  static function main() 
    Command.attempt(ensure(Logger.get()), @:privateAccess NekoCli.main);
}