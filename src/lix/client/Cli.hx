package lix.client;

import lix.client.Archives;
import lix.client.sources.*;

class Cli {
  
  static function main()
    dispatch(Sys.args());    
  
  static function dispatch(args:Array<String>) {
    
    var silent = args.remove('--silent'),
        global = args.remove('--global');
        
    var scope = Scope.seek({ cwd: if (global) Scope.DEFAULT_ROOT else null });
    
    var github = new GitHub(switch args.indexOf('--gh-credentials') {
      case -1:
        null;
      case v:
        args.splice(v, 2)[1];
    });
    
    var resolvers:Map<String, ArchiveSource> = [
      'http' => Web,
      'https' => Web,
      'haxelib' => Haxelib,
      'gh' => github,
      'github' => github,
    ];

    function resolve(url:Url):Promise<ArchiveJob>
      return switch resolvers[url.scheme] {
        case null:
          new Error('Unknown scheme in url $url');
        case v:
          v.processUrl(url);
      }
    
    var client = new Client(scope, resolve);
    
    Command.dispatch(args, 'lix - Libraries for haXe', [
    
      new Command('download', '[<url> [as <lib[#ver]>]]', 'download lib from url if specified,\notherwise download missing libs', 
        function (args) return switch args {
          case [url, 'as', alias]: 
            client.downloadUrl(url, LibVersion.parse(alias));
          case [url]: 
            client.downloadUrl(url);
          case []: 
            new HaxeCli(scope).installLibs(silent);
            Noise;//actually the above just exits
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
                case [url]: 
                  client.installUrl(url);
                case []: new Error('Missing url');
                case v: new Error('too many arguments');
              }
      ),
      
    ], []).handle(Command.reportError);
  }
  
}