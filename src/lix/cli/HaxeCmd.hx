package lix.cli;

class HaxeCmd {
  static public function ensureScope():Promise<Noise>
    return 
      if (Scope.exists(Scope.DEFAULT_ROOT)) Noise;
      else 
        Scope.create(Scope.DEFAULT_ROOT, {
          version: 'stable',
          resolveLibs: Mixed,
        });      

  static public function ensure(logger) 
    return ensureScope()
      .next(function (_) return {

        var scope = Scope.seek();
        var hx = new lix.client.haxe.Switcher(scope, logger);
        
        (
          if (!hx.scope.haxeInstallation.path.exists()) {
            var version = hx.scope.config.version;
            println('Version $version configured in ${hx.scope.configFile} does not exist. Attempting download ...');
            hx.install(version, { force: false });
          }    
          else Promise.lift(Noise)
        ).next(function (_) {
          // switch scope.getInstallationInstructions().instructions.install.length {
          //   case 0: 
          //   case v:
          //     println('Missing $v libraries. Attempting download ...');
          //     new HaxeCli(scope).installLibs(true);
          // }
          return Noise;
        });
      });

  static function main() 
    Command.attempt(ensure(Logger.get()), @:privateAccess HaxeCli.main);
}