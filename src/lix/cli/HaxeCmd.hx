package lix.cli;

class HaxeCmd {
  static public function ensure(andThen:Void->Void) {
    NekoCmd.ensure(function () {
      if (!Scope.exists(Scope.DEFAULT_ROOT)) {
        Fs.ensureDir(Scope.DEFAULT_ROOT + '/');
          
        Scope.create(Scope.DEFAULT_ROOT, {
          version: 'stable',
          resolveLibs: Mixed,
        });      
      }
      
      var hx = new lix.client.haxe.Switcher(
        Scope.seek(),
        false,
        println
      );
      (
        if (!hx.scope.haxeInstallation.path.exists()) {
          var version = hx.scope.config.version;
          println('Version $version configured in ${hx.scope.configFile} does not exist. Attempting download ...');
          hx.install(version, { force: false });
        }
        else
          Promise.lift(Noise)
      ).recover(Command.reportError).handle(andThen);
    });
  }
  static function main() 
    ensure(@:privateAccess HaxeCli.main);
}