package lix.client;

import lix.client.Archives;
import lix.client.sources.*;
import lix.api.Api;
class Cli {
  
  static function main()
    dispatch(Sys.args());    
  
  static function dispatch(args:Array<String>) {
    
    var silent = args.remove('--silent'),
        global = args.remove('--global') || args.remove('-g');
        
    var scope = Scope.seek({ cwd: if (global) Scope.DEFAULT_ROOT else null });
    
    var github = new GitHub(switch args.indexOf('--gh-credentials') {
      case -1:
        null;
      case v:
        args.splice(v, 2)[1];
    });
    
    var sources:Array<ArchiveSource> = [Web, Haxelib, github, new Git(github)];
    var resolvers:Map<String, ArchiveSource> = [for (s in sources) for (scheme in s.schemes()) scheme => s];

    function resolve(url:Url):Promise<ArchiveJob>
      return switch resolvers[url.scheme] {
        case null:
          new Error('Unknown scheme in url $url');
        case v:
          v.processUrl(url);
      }
    
    var client = new Client(scope, resolve, if (silent) function (_) {} else Sys.println);
    
    Command.dispatch(args, 'lix - Libraries for haXe', [
    
      new Command('download', '[<url[#lib[#ver]]>]', 'download lib from url if specified,\notherwise download missing libs', 
        function (args) return switch args {
          case [url, 'into', dir]: 

            client.downloadUrl(url, dir);

          case [(_:Url) => url]: 

            client.downloadUrl(url);

          case []: 

            var s = new switchx.Switchx(scope);
            
            s.resolveOnline(scope.config.version)
              .next(s.download.bind(_, { force: false }))
              .next(function (_) {
                new HaxeCli(scope).installLibs(silent);
                return Noise;//actually the above just exits
              });

          case v: new Error('too many arguments');
        }
      ),
      
      new Command('install', '<url> [as <lib[#ver]>]', 'install lib from specified url',
        function (args) 
          return 
            if (scope.isGlobal && !global)
              new Error('Current scope is global. Please use --global if you intend to install globally, or create a local scope.');
            else
              switch args {
                case [url, 'as', alias]: 
                  client.installUrl(url, LibVersion.parse(alias));
                case [library, constraint]:
                  Promise.lift(Constraint.parse(constraint)).next(client.install.bind(library, _));
                case [library] if ((library:Url).scheme == null): 
                  client.install(library);
                case [url]:
                  client.installUrl(url);
                case []: new Error('Missing url');
                case v: new Error('too many arguments');
              }
      ),
      new Command('build', '...args', 'build',
        function (args) {
          @:privateAccess new HaxeCli(scope).dispatch(args);
          return Noise;
        }
      )
    ], []).handle(Command.reportOutcome);
  }
  
}