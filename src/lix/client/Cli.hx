package lix.client;

import haxeshim.*;
import switchx.*;

using tink.CoreApi;
using sys.io.File;
using haxe.Json;
using sys.FileSystem;

typedef SchemeHandler = { url:String, tmpLoc:String }->Promise<Downloaded>;
typedef Downloaded = { lib:String, version:String, root:String, };

abstract LibId(String) from String to String {
  
  public var scheme(get, never):String;
    function get_scheme()
      return switch this.indexOf(':') {
        case -1: '';
        case v: this.substr(0, v);
      }  
      
  public var payload(get, never):String;
    function get_payload()
      return this.substr(this.indexOf(':') + 1);
}

abstract LibUrl(String) from String to String {
  
  
  public var id(get, never):LibId;
    function get_id():LibId
      return switch this.indexOf('#') {
        case -1: this;
        case v: this.substr(0, v);
      }
      
  public var version(get, never):Option<String>;
    function get_version()
      return switch this.indexOf('#') {
        case -1: None;
        case v: switch this.substr(v + 1) {
          case '': None;
          case v: Some(v);
        }
      }
}

abstract DownloadUrl(String) from String to String {
  
  public function new(source:LibUrl, target:Option<LibUrl>)
    this = source + switch target {
      case Some(v): '@' + v;
      case None: '';
    }
    
  public var source(get, never):LibUrl;
    function get_source():LibUrl
      return switch this.indexOf('@') {
        case -1: this;
        case v: this.substr(0, v);
      }
      
  public var target(get, never):Option<LibUrl>;
    function get_target():Option<LibUrl>
      return switch this.indexOf('@') {
        case -1: None;
        case v: switch this.substr(v + 1) {
          case '': None;
          case v: Some(v);
        }
      }
}


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
              new Error('unable to determing library information from $src');
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
      
    function grabGitHubCommit(repo, version) {
      return Download.text('https://api.github.com/repos/$repo/commits?sha=$version').next(function (s):String {
        return s.parse()[0].sha;
      });
    }
      
    function githubArchive(repo, sha)
      return 'https://github.com/$repo/archive/$sha.tar.gz';
    
    function resolveGithubVersion(url:LibUrl):Promise<String>
      return 
        switch url.version {
          case Some(sha) if (sha.length == 40):
            githubArchive(url.id.payload, sha);
          case Some(v):
            grabGitHubCommit(url.id.payload, v).next(githubArchive.bind(url.id.payload, _));
          case None:
            grabGitHubCommit(url.id.payload, '').next(githubArchive.bind(url.id.payload, _));
        }
    
    var downloaders:Map<String, SchemeHandler> = [
      'http' => fetch,
      'https' => fetch,
    ];
    
    var resolvers:Map<String, LibUrl->Promise<LibUrl>> = [
      'haxelib' => resolveHaxelibVersion,
      'gh' => resolveGithubVersion,
      'github' => resolveGithubVersion,
    ];
    
    function download(url:DownloadUrl):Promise<Downloaded> 
      return 
        switch downloaders[url.source.id.scheme] {
          case null:
            new Error('Unknown scheme in url $url');
          case v:
            switch url.source.version {
              case Some(v):
                new Error('Unresolved version fragment in url ${url.source}');
              case None:
                v({ url: url.source, tmpLoc: Sys.getCwd() + '/downloads/' + Date.now().getTime() }).next(
                  function (v:Downloaded):Promise<Downloaded> {
                    switch url.target {
                      case Some(target):
                        switch target.id {
                          case '':
                          case id: v.lib = id;
                        }
                        switch target.version {
                          case Some(version): v.version = version;
                          case None:
                        }
                      case None:
                    }
                    
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
        }  
        
    function resolve(url:LibUrl):Promise<LibUrl>
      return
        switch resolvers[url.id.scheme] {
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
          case [(_:DownloadUrl) => url]:
            
            resolve(url.source).next(
              function (actual) {
                return download(new DownloadUrl(actual, url.target)).next(function (v) {
                  
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