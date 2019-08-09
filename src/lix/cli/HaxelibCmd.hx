package lix.cli;

class HaxelibCmd {
  static public function ensure(logger)
    return NekoCmd.ensure(logger).next(
      function (_) return HaxeCmd.ensure(logger)
    );

  static function main() 
    Command.attempt(ensure(Logger.get()), @:privateAccess HaxelibCli.main);
}