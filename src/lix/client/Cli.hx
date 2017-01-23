package lix.client;
import haxe.crypto.Md5;

using sys.io.File;
using haxe.Json;
using sys.FileSystem;


class Cli {

  static function main()
    dispatch(Sys.args());    
  
  static function detectLib(src:String, path:String, ?target:LibUrl):Promise<Downloaded>
    return switch path.readDirectory() {
      case [v]:
        
        detectLib(src, '$path/$v', target);
      
      case files:
        
        switch target {
          case null | { version: None }:
            var ret:Downloaded = null;
            
            for (f in files) 
              switch f {
                case 'haxelib.json' | 'package.json': 
                  var o:{ name: String, version:String } = '$path/$f'.getContent().parse();
                  ret = {
                    lib: switch target {
                      case null: o.name;
                      case v: v.id.payload;
                    },
                    version: o.version,
                    root: path,
                  }
                  break;
                default:
              }
            return  
              if (ret == null)
                new Error('unable to determine library information from $src');
              else
                ret;
          case { id: { payload: name }, version: Some(version) } :
            {
              lib: name,
              version: version,
              root: path,
            }
        }
    }
  
  static function dispatch(args:Array<String>) {
    
    var silent = args.remove('--silent'),
        global = args.remove('--global');
        
    var scope = Scope.seek({ cwd: if (global) Scope.DEFAULT_ROOT else null });
    
    function http(url, into, target) {
      return Download.archive(url, 0, into).next(detectLib.bind(url, _, target));
    }
    
    var fetch:SchemeHandler = function (args) {
      return http(args.url, args.tmpLoc, args.target);
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
    
    function resolveHaxelibVersion(url:DownloadJob):Promise<DownloadJob>
      return new Error('not implemented');
      
    function grabGitHubCommit(repo, version) {
      return Download.text('https://api.github.com/repos/$repo/commits?sha=$version').next(function (s):String {
        return s.parse()[0].sha;
      });
    }
      
    function githubArchive(repo, sha)
      return 'https://github.com/$repo/archive/$sha.tar.gz';
    
    function resolveGithubSource(url:LibUrl):Promise<LibUrl>
      return switch url.version {
        case Some(sha) if (sha.length == 40):
          githubArchive(url.id.payload, sha);
        case Some(v):
          grabGitHubCommit(url.id.payload, v).next(githubArchive.bind(url.id.payload, _));
        case None:
          grabGitHubCommit(url.id.payload, '').next(githubArchive.bind(url.id.payload, _));
      }
      
    function resolveGithubVersion(url:DownloadJob):Promise<DownloadJob>
      return 
        resolveGithubSource(url.source).next(function (v):DownloadJob return {
          source: v,
          target: url.target,
        });
    
    var downloaders:Map<String, SchemeHandler> = [
      'http' => fetch,
      'https' => fetch,
    ];
    
    var resolvers:Map<String, DownloadJob->Promise<DownloadJob>> = [
      'haxelib' => resolveHaxelibVersion,
      'gh' => resolveGithubVersion,
      'github' => resolveGithubVersion,
    ];
    
    function download(url:DownloadJob):Promise<Downloaded> 
      return 
        switch downloaders[url.source.id.scheme] {
          case null:
            new Error('Unknown scheme in url $url');
          case v:
            switch url.source.version {
              case Some(v):
                new Error('Unresolved version fragment in url ${url.source}');
              case None:
                v({ url: url.source.id, tmpLoc: scope.haxeshimRoot + '/downloads/' + Date.now().getTime(), target: url.target }).next(
                  function (v:Downloaded) {
                    switch url.target {
                      case null:
                      case target:                        
                        switch target.id {
                          case '':
                          case id: v.lib = id.payload;
                        }
                        switch target.version {
                          case Some(version): v.version = version;
                          case None:
                        }
                    }
                    
                    var savedTo = v.lib + '/' + v.version + '/' + Md5.encode(url.source.id);
                    var target = scope.libCache + '/$savedTo';
                    
                    try {
                      Fs.ensureDir(target);
                      if (target.exists())
                        target.rename('$target-archived@' + Date.now().getTime());
                      v.root.rename(target);
                      v.root = target;
                      v.savedTo = savedTo;//this is really ugly
                      return v;
                    }
                    catch (e:Dynamic) {
                      return new Error('Failed to move downloaded library to its final destination: $target because $e');
                    }
                  }
                );
            }
        }  
        
    function resolve(url:DownloadJob):Promise<DownloadJob>
      return
        switch resolvers[url.source.id.scheme] {
          case null: url;
          case v:
            v(url).next(resolve);
        }
        
    function install(url:DownloadJob)
      return
        resolve(url).next(
          function (actual) {
            return download(actual).next(function (v) {
              
              var extra =
                switch '${v.root}/extraParams.hxml' {
                  case found if (found.exists()):
                    found.getContent();
                  default: '';
                }
                
              switch actual.target {
                case null:
                  actual = {
                    source: actual.source, 
                    target: new LibUrl(v.lib, Some(v.version)),
                  }
                default:
              }
                
              var hxml = Resolver.libHxml(scope.scopeLibDir, v.lib);
              
              Fs.ensureDir(hxml);
              
              var contents = v.root.readDirectory();
              
              var cp:String = 
                if (contents.remove('haxelib.json'))
                  '${v.root}/haxelib.json'.getContent().parse().classPath;
                else if (contents.remove('src')) 'src';
                else null;
                
              if (cp == null)
                cp = '';
                
              hxml.saveContent([
                '# @install: lix download $actual',
                '-D ${v.lib}=${v.version}',
                '-cp $${HAXESHIM_LIBCACHE}/${v.savedTo}/$cp',
                extra,
              ].join('\n'));
              
              return Noise;
            });
          }
        );        
    
    Command.dispatch(args, 'lix - Libraries for haXe', [
    
      new Command('download', '[<url> [as <lib[#ver]>]]', 'download lib from url if specified,\notherwise download missing libs', 
        function (args) return switch args {
          case [url, 'as', alias]: download({ source: url, target: alias });
          case [url]: download({ source: url });
          case []: 
            new HaxeCli(scope).installLibs();
            Noise;
          case v: new Error('too many arguments');
        }
      ),
      
      new Command('install', '<url> [as <lib[#ver]>]', 'install lib from specified url',
        function (args) return switch args {
          case [url, 'as', alias]: install({ source: url, target: alias });
          case [url]: install({ source: url });
          case []: new Error('Missing url');
          case v: new Error('too many arguments');
        }
      ),
      
    ], []).handle(Command.reportError);
  }
  
}