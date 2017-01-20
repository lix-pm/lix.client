package lix.client;

import haxeshim.*;
import switchx.*;

using tink.CoreApi;
using sys.io.File;
using haxe.Json;
using sys.FileSystem;

typedef SchemeHandler = { url:String, tmpLoc:String }->Promise<Downloaded>;
typedef Downloaded = { lib:String, version:String, root:String, };

class Cli {

  static function main() {
    dispatch(Sys.args());    
  }
  
  static function dispatch(args:Array<String>) {
    
    var silent = args.remove('--silent'),
        global = args.remove('--global');
        
    var scope = Scope.seek({ cwd: if (global) Scope.DEFAULT_ROOT else null });
        
    function detectLib(src:String, path:String, ?version:String):Promise<Downloaded> {
      return switch path.readDirectory() {
        case [v]:
          
          detectLib(src, '$path/$v', version);
          
        case files:
          var ret:Downloaded = null;
          
          for (f in files) 
            switch f {
              case 'haxelib.json' | 'package.json': 
                var o:{ name: String, version:String } = '$path/$f'.getContent().parse();
                ret = {
                  lib: o.name,
                  version: switch version {
                    case null: o.version;
                    case v: v;
                  },
                  root: path,
                }
                break;
              default:
            }
          return  
            if (ret == null)
              new Error('unable to determing library information from ');
            else
              ret;
      }
    }
    
    function http(url, into, version) {
      return Download.archive(url, 0, into).next(detectLib.bind(url, _, version));
    }
    
    var fetch:SchemeHandler = function (args) {
      return http(args.url, args.tmpLoc, null);
    }
        
    //var fetchFromHaxelib:SchemeHandler = function (args) 
      //return switch args.url.substr('haxelib:'.length).split('#') {
        //case [name, version]:
          //fetch({ url: 'https://lib.haxe.org/p/$name/$version/download/', tmpLoc: args.tmpLoc });
        //case [name]:
          //new Error('Missing version specification in ${args.url}');
        //case v:
          //new Error('Invalid haxelib download URL ${args.url}');
      //}
      
    //var fetchFromGitHub:SchemeHandler = function (args) 
      //return switch args.url.substr('github:'.length).split('/') {
        //case [owner, repo, commit]:
          //if (commit.length != 40)
            //new Error('Invalid sha "$commit" in GitHub URL ${args.url}');
            //
          //
        //default:
          //new Error('GitHub URL not fully specified: ${args.url}');
      //}
    
    //{
      //var lib:Promise<{ lib:String, version: String }> = 
        //switch args.url.substr('haxelib:'.length).split('#') {
          //case [name]:
            //Download.text('https://lib.haxe.org/p/hxnodejs').next(function (s) {
              //return {
                //lib: name,
                //version: s.split(')</title>')[0].split('(').pop(),
              //}
            //});
          //case [name, version]:
            //{ lib: name, version: version };
          //case v:
            //new Error('Invalid library format $v');
        //}
        //
      //return lib.next(function (v) {
        //return fetch(
      //});
    //}  
    
    function resolveHaxelibVersion(s:String):Promise<String>
      return new Error('not implemented');
      
    function grabGitHubCommit(owner, repo, version) {
      return Download.text('https://api.github.com/repos/$owner/$repo/commits?sha=$version').next(function (s):String {
        return s.parse()[0].sha;
      });
    }
      
    function githubArchive(owner, repo, sha)
      return 'https://github.com/$owner/$repo/archive/$sha.tar.gz';
    
    function resolveGithubVersion(url:String):Promise<String>
      return switch url.substr(url.indexOf(':') + 1).split('/') {
        case [owner, repo, sha] if (sha.length == 40):
          githubArchive(owner, repo, sha);
        case [owner, repo, version]:
          grabGitHubCommit(owner, repo, version).next(githubArchive.bind(owner, repo, _));
        case [owner, repo]:
          grabGitHubCommit(owner, repo, '').next(githubArchive.bind(owner, repo, _));
        default:
          new Error('Malformed GitHub URL $url');
      }
    
    var downloaders:Map<String, SchemeHandler> = [
      'http' => fetch,
      'https' => fetch,
    ];
    
    var resolvers:Map<String, String->Promise<String>> = [
      'haxelib' => resolveHaxelibVersion,
      'gh' => resolveGithubVersion,
      'github' => resolveGithubVersion,
    ];
    
    function download(url:String):Promise<Downloaded> 
      return 
        switch downloaders[url.split(':')[0]] {
          case null:
            new Error('Unknown scheme in url $url');
          case v:
            v({ url: url, tmpLoc: Sys.getCwd() + '/downloads/' + Date.now().getTime() }).next(
              function (v):Promise<Downloaded> {
                var target = scope.libCache + '/' + v.lib + '/' + v.version;
                try {
                  Fs.ensureDir(target);
                  if (target.exists())
                    target.rename('$target-archived@' + Date.now().getTime());
                  v.root.rename(target);
                  v.root = target;
                  return v;
                }
                catch (e:Dynamic) {
                  return new Error('Failed to move downloaded library to its final destination: $target because $e');
                }
              }
            );
        }  
        
    function resolve(url:String):Promise<String>
      return
        switch resolvers[url.split(':')[0]] {
          case null: url;
          case v:
            v(url).next(resolve);
        }
    
    Command.dispatch(args, 'lix - Libraries for haXe', [
      new Command('download', '<url>', 'download library from specified url', 
        function (args) return switch args {
          case [url]: download(url);
          case []: new Error('Missing url');
          case v: new Error('too many arguments');
        }
      ),
      new Command('install', '<url>', 'install library from specified url',
        function (args) return switch args {
          case [url]:
            
            resolve(url).next(
              function (actual) {
                return download(actual).next(function (v) {
                  
                  var extra =
                    switch '${v.root}/extraParams.hxml' {
                      case found if (found.exists()):
                        found.getContent();
                      default: '';
                    }
                    
                  Resolver.libHxml(scope.scopeLibDir, v.lib).saveContent([
                    '# @install: lix download $actual',
                    '-D ${v.lib}=${v.version}',
                    '-cp $${HAXESHIM_LIBCACHE}/${v.lib}/${v.version}/src',
                    extra,
                  ].join('\n'));
                  
                  return Noise;
                });
              }
            );
          case []: new Error('Missing url');
          case v: new Error('too many arguments');
        }
      ),
    ], []).handle(Command.reportError);
  }
  
}