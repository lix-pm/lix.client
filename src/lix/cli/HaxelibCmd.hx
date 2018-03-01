package lix.cli;

class HaxelibCmd {
  static public function ensure()
    return NekoCmd.ensure().next(
      function (_) return HaxeCmd.ensure()
    );

  static function main() 
    Command.attempt(ensure(), @:privateAccess HaxelibCli.main);
}