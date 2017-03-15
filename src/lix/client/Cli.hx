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
    
    var sources:Array<ArchiveSource> = [Web, Haxelib, github];
    var resolvers:Map<String, ArchiveSource> = [for (s in sources) for (scheme in s.schemes()) scheme => s];
    
    var client = new Client(scope);
    
    function resolve(url:Url):Promise<ArchiveJob>
      return switch resolvers[url.scheme] {
        case null:
          new Error('Unknown scheme in url $url');
        case v:
          v.processUrl(url);
      }
    Command.dispatch(args, 'lix - Libraries for haXe', [
    
      new Command('download', '[<url> [into <path>]]', 'download lib from url if specified,\notherwise download missing libs', 
        function (args) return switch args {
          // case [url, 'into', dir]: 
            // client.download(resolve(url), LibVersion.parse(alias));
          // case [url]: 
            // client.download(resolve(url));
          case []: 
            new HaxeCli(scope).installLibs(silent);
            Noise;
          case v: new Error('too many arguments');
        }
      ),
      
      new Command('install', '<url> [as <lib[#ver]>]', 'install lib from specified url',
        function (args) return switch args {
          case [url, 'as', alias]: 
            client.install(resolve(url), LibVersion.parse(alias));
          case [url]: 
            client.install(resolve(url));
          case []: new Error('Missing url');
          case v: new Error('too many arguments');
        }
      ),
      
    ], []).handle(Command.reportOutcome);
  }
  
}