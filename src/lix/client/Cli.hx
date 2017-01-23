package lix.client;

import lix.client.Archives;
import lix.client.sources.Haxelib;
import lix.client.sources.GitHub;
import lix.client.sources.Web;

using sys.io.File;
using haxe.Json;
using sys.FileSystem;


class Cli {
  
  static function main()
    dispatch(Sys.args());    

  
  static function dispatch(args:Array<String>) {
    
    var silent = args.remove('--silent'),
        global = args.remove('--global');
        
    var scope = Scope.seek({ cwd: if (global) Scope.DEFAULT_ROOT else null });
    
    var resolvers:Map<String, Url->Promise<ArchiveJob>> = [
      'http' => Web.getArchive,
      'https' => Web.getArchive,
      'haxelib' => Haxelib.parseUrl,
      'gh' => GitHub.parseUrl,
      'github' => GitHub.parseUrl,
    ];
    
    var client = new Client(scope);
    
    function resolve(url:Url):Promise<ArchiveJob>
      return switch resolvers[url.scheme] {
        case null:
          new Error('Unknown scheme in url $url');
        case v:
          v(url);
      }
    Command.dispatch(args, 'lix - Libraries for haXe', [
    
      new Command('download', '[<url> [as <lib[#ver]>]]', 'download lib from url if specified,\notherwise download missing libs', 
        function (args) return switch args {
          case [url, 'as', alias]: 
            Promise.lift(LibVersion.parse(alias)).next(
              client.download.bind(resolve(url), _)
            );
          case [url]: 
            client.download(resolve(url));
          case []: 
            new HaxeCli(scope).installLibs();
            Noise;
          case v: new Error('too many arguments');
        }
      ),
      
      new Command('install', '<url> [as <lib[#ver]>]', 'install lib from specified url',
        function (args) return switch args {
          case [url, 'as', alias]: 
            Promise.lift(LibVersion.parse(alias)).next(
              client.install.bind(resolve(url), _)
            );
          case [url]: 
            client.install(resolve(url));
          case []: new Error('Missing url');
          case v: new Error('too many arguments');
        }
      ),
      
    ], []).handle(Command.reportError);
  }
  
}