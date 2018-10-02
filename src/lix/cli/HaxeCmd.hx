package lix.cli;

class HaxeCmd {
  static public function ensureScope() {
    if (!Scope.exists(Scope.DEFAULT_ROOT)) {
      Fs.ensureDir(Scope.DEFAULT_ROOT + '/');
        
      Scope.create(Scope.DEFAULT_ROOT, {
        version: 'stable',
        resolveLibs: Mixed,
      });      
    }
    return Promise.lift(Noise);    
  }

  static public function ensure() 
    return ensureScope().next(function (_) {
      var hx = new lix.client.haxe.Switcher(
        Scope.seek(),
        false,
        println
      );
      return 
        if (!hx.scope.haxeInstallation.path.exists()) {
          var version = hx.scope.config.version;
          println('Version $version configured in ${hx.scope.configFile} does not exist. Attempting download ...');
          hx.install(version, { force: false });
        }    
        else Promise.lift(Noise);
    });

  static function main() 
    Command.attempt(ensure(), @:privateAccess HaxeCli.main);
}