package lix.cli;

import lix.client.Archives;
import lix.client.sources.*;
import lix.api.Api;
import lix.client.*;
import js.Node.*;

using haxe.Json;
using sys.io.File;
using sys.FileSystem;

class Cli {
  
  static function main() {
    var args = Sys.args();
    var global = args.remove('--global') || args.remove('-g');
    function getScope()
      return Scope.seek({ cwd: if (global) Scope.DEFAULT_ROOT else null });
    
    // (switch getScope.catchExceptions() {
    //   case Failure(e):
    //     switchx.Cli.ensureGlobal('lix');
    //   case Success(v): Future.sync(v);
    // }).handle(dispatch.bind(_, global, args));
  }
  
  static function dispatch(scope:Scope, global:Bool, args:Array<String>) {
    var version = CompileTime.parseJsonFile("./package.json").version;//haxe.Json.parse(sys.io.File.getContent(js.Node.__dirname+'/../package.json')).version;
    var silent = args.remove('--silent'),
        force = args.remove('--force');

    args = Command.expand(args, [
      "+tink install github:haxetink/tink_${0}",
      "+coco install github:MVCoconut/coconut.${0}",
      "+lib install haxelib:${0}",
    ]);
    
    var github = new GitHub(switch args.indexOf('--gh-credentials') {
      case -1:
        null;
      case v:
        args.splice(v, 2)[1];
    });
    
    var gitlab = new GitLab(switch args.indexOf('--gl-private-token') {
      case -1:
        null;
      case v:
        args.splice(v, 2)[1];
    });
    
    var sources:Array<ArchiveSource> = [Web, Haxelib, github, gitlab, new Git(github, gitlab)];
    var resolvers:Map<String, ArchiveSource> = [for (s in sources) for (scheme in s.schemes()) scheme => s];

    function resolve(url:Url):Promise<ArchiveJob>
      return switch resolvers[url.scheme] {
        case null:
          new Error('Unknown scheme in url $url');
        case v:
          v.processUrl(url);
      }
    
    var log = if (silent) function (_) {} else Sys.println;

    var hx = new lix.client.haxe.Switcher(scope, silent, log);    
    var libs = new Libraries(
      scope, 
      resolve, 
      function (_) return new Error(NotImplemented, "not implemented"), 
      log,
      force,
      silent
    );

    // var switchxCli = new switchx.Cli(switcher, force); 
    // var switchxCommands = switchxCli.makeCommands();

    Command.dispatch(args, 'lix - Libraries for haXe (v$version)', [
      new Command('install', '<url> [as <lib[#ver]>]', 'install lib from specified url',
        function (args) 
          return 
            if (scope.isGlobal && !global)
              new Error('Current scope is global. Please use --global if you intend to install globally, or create a local scope with `lix scope create`.');
            else
              switch args {
                case ['haxe', version]:
                  hx.install(version, { force: force });
                case [url, 'as', alias]: 
                  libs.installUrl(url, LibVersion.parse(alias));
                case [library, constraint]:
                  Promise.lift(Constraint.parse(constraint)).next(libs.install.bind(library, _));
                case [library] if ((library:Url).scheme == null): 
                  libs.install(library);
                case [url]:
                  libs.installUrl(url);
                case []: new Error('Missing url');
                case v: new Error('too many arguments');
              }
      ),      
      new Command('install haxe', '<version>|<alias>', 'install specified haxe version', null),//this is never matched and is here purely for usage display
      new Command('use', 'haxe <alias>|<version>', 'use specified haxe version', function (args) return switch args {
        case ['haxe', version]: hx.resolveInstalled(version).next(hx.switchTo);
        default: new Error('invalid arguments');
      }),
      // fromSwitchx('list').as('haxe-versions', 'lists currently downloaded haxe versions'),
      // fromSwitchx('scope'),
      new Command('download', '[<url[#lib[#ver]]>]', 'download lib from url if specified,\notherwise download missing libs', 
        function (args) return switch args {
          case [url, 'as', legacy]:
            var target = legacy.replace('#', '/');
            var absTarget = scope.libCache + '/$target';
            function shorten(s:String)
              return 
                if (s.length > 40) s.substr(0, 37)+ '...';
                else s;

            if (absTarget.exists()) 
              new Error('`download <url> as <ver>` is no longer supported');
            else {
              Sys.println('[WARN]: Processing obsolete `download ${args.map(shorten).join(" ")}`.\n        Please reinstall library in a timely manner!\n\n');
              libs.downloadUrl(url, { into: target }).next(function (a) return {
                Fs.ensureDir(absTarget);
                a.absRoot.rename(absTarget);
                return a;
              });
            }
          case [url, 'into', dir]: 

            libs.downloadUrl(url, { into: dir });

          case [(_:Url) => url]: 

            libs.downloadUrl(url);

          case []: 

            // @:privateAccess switchx.Cli.ensureNeko(Scope.seek()).next(
              // function (_) return
                hx.resolveOnline(scope.config.version)
                  .next(hx.download.bind(_, { force: false }))
                  .next(function (_) {
                    new HaxeCli(scope).installLibs(silent);
                    return Noise;//actually the above just exits
                  })    ;         
            // );


          case v: new Error('too many arguments');
        }
      ),
      new Command('run', 'lib ...args', 'run a library', function (args) return switch args {
        case []: new Error('no library specified');
        case args:
          scope.getLibCommand(args)
            .next(function (cmd) return cmd());
      }),
      new Command(['--version', '-v'], '', 'print version', function (args) return
        if (args.length > 0) new Error('too many arguments')
        else {
          Sys.println(version);
          Noise;
        }
      ),
      new Command('run-haxelib', 'path ...args', 'invoke a haxelib at a given path following haxelib\'s conventions', function (args) return 
        switch args {
          case []: new Error('no path supplied');
          default: 
            Haxelib.runLib(scope, args);
        }
      ),             
    ], []).handle(Command.reportOutcome);
  }       
}