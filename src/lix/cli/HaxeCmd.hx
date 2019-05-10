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
    return ensureScope()
      .next(function (_) return {

        var scope = Scope.seek();
        var hx = new lix.client.haxe.Switcher(scope, false, println);
        
        (
          if (!hx.scope.haxeInstallation.path.exists()) {
          var version = hx.scope.config.version;
          println('Version $version configured in ${hx.scope.configFile} does not exist. Attempting download ...');
          hx.install(version, { force: false });
          }    
          else Promise.lift(Noise)
        ).next(function (_) {
          switch scope.getInstallationInstructions().instructions.install.length {
            case 0: 
            case v:
              println('Missing $v libraries. Attempting download ...');
              new HaxeCli(scope).installLibs(true);
          }
          return Noise;
        });
      });

  static function main() 
    Command.attempt(ensure(), @:privateAccess HaxeCli.main);
}