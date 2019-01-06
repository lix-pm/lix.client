package lix.cli;

import lix.client.Archives;
import lix.client.sources.*;
import lix.client.*;
import lix.api.types.*;
import tink.http.clients.*;

class Cli {
  
  static function main() 
    Command.attempt(HaxeCmd.ensureScope(), dispatch.bind(Sys.args()));
  
  static function dispatch(args:Array<String>) {
    var version = Macro.getVersion();
    var silent = args.remove('--silent'),
        force = args.remove('--force'),
        submodules = args.remove('--submodules'),
        global = args.remove('--global') || args.remove('-g');

    var scope = Scope.seek({ cwd: if (global) Scope.DEFAULT_ROOT else null });

    args = Command.expand(args, [ 
      "+tink install github:haxetink/tink_${0}",
      "+coco install github:MVCoconut/coconut.${0}",
      "+lib install haxelib:${0}",
    ]);

    function grab(name:String)
      return switch args.indexOf(name) {
        case -1: null;
        case v: args.splice(v, 2)[1];
      }
    
    var gitlab = new GitLab(grab('--gl-private-token')),
        github = new GitHub(switch grab('--gh-credentials') {
          case null: null;
          case _.split(':') => [user, tk]: new tink.url.Auth(user, tk);
          case v: Exec.die(422, '`--gh-credentials $v` should be `--gh-credentials <user>:<token>`');
        });

    var haxelibUrl = new tink.url.Host(grab('--haxelib-url'));

    var sources:Array<ArchiveSource> = [Web, new Lix(), new Haxelib(haxelibUrl), github, gitlab, new Git(github, gitlab, scope, submodules)];
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
    
    var auth = new lix.Auth();
    var remote = new lix.Remote(
      #if (environment == "local")
        new NodeClient(), () -> '2'
      #else 
        new SecureNodeClient(), () -> auth.getSession().next(session -> session.idToken)
      #end
    );

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
      new Command('download haxe', '<version>|<alias>', 'download specified haxe version', null),//this is never matched and is here purely for usage display
      new Command('scope', '[create|delete]', 'creates or deletes the current scope or\ninspects it if no argument is supplied',
        function (args) return switch args {
          case ['create']:
            Scope.create(scope.cwd, {
              version: scope.config.version,
              resolveLibs: if (scope.isGlobal) Scoped else scope.config.resolveLibs,
            });
            log('created scope in ${scope.cwd}');
            Noise;
          case ['delete']:
            if (scope.isGlobal)
              new Error('Cannot delete global scope');
            else {
              scope.delete();
              log('deleted scope in ${scope.scopeDir}');
              Noise;
            }
          case []: 
            println(
              (if (scope.isGlobal) '[global]' else '[local]') + ' ${scope.scopeDir}'
            );
            Noise;
          case v: 
            new Error('Invalid arguments');
        }
      ),
      new Command('haxe-versions', '', 'lists currently downloaded versions',
        function (args) return switch args {
          case []:
            hx.officialInstalled(IncludePrereleases).next(function (o) {
              return hx.nightliesInstalled().next(function (n) {
                function highlight(s:String)
                  return
                    if (s == scope.config.version)
                      ' -> $s';
                    else
                      '    $s';
                
                println('');
                println('Official releases:');
                println('');
                
                for (v in o) 
                  println(highlight(v));
                
                if (n.iterator().hasNext()) {
                  println('');
                  println('Nightly builds:');
                  println('');
                  
                  for (v in n) 
                    println(highlight(v.hash) + v.published.format('  (%Y-%m-%d %H:%M)'));
                }
                
                println('');
                
                return Noise;
              });
            });
          default:
            new Error('command `list` does expect arguments');
        }
      ),
      new Command('download', '[<url[#lib[#ver]]>]', 'download lib from url if specified,\notherwise download missing libs', 
        function (args) return switch args {
          case ['haxe', version]:
            hx.resolveAndDownload(version, { force: force });
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

            lix.client.haxe.Switcher.ensureNeko(println)
              .next(function (_) return
                hx.resolveOnline(scope.config.version)
                  .next(hx.download.bind(_, { force: false }))
                  .next(function (_) {
                    new HaxeCli(scope).installLibs(silent);
                    return Noise;//actually the above just exits
                  })
              );

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
            new haxeshim.HaxelibCli(scope).run(args.slice(1));
            Noise;
        }
      ),
      new Command('login', '', 'log in the Lix Registry', function (args) {
        return remote.me().get()
          .next(user -> {
            if(user.username == null) {
              var readline = js.node.Readline.createInterface({
                input: js.Node.process.stdin,
                output: js.Node.process.stdout,
              });
              Future.async(function(cb) readline.question('Please input a username for your Lix account: ', cb))
                .next(username -> {
                  readline.close();
                  remote.me().update({username: Some(username), nickname: None}).swap(username);
                });
            } else {
              user.username;
            }
          })
          .map(function(o) return switch o {
            case Success(username):
              Sys.println('Logged in as ${username}');
              Success(Noise);
            case Failure(e):
              Sys.println(e);
              Failure(e);
          });
      }),
      new Command('logout', '', 'log out from the Lix Registry', function (args) {
        auth.clearSession();
        return Noise;
      }),
      new Command('submit', '[directory]', 'Submit package to the Lix Registry', function (args) {
        if(args.length > 1) return new Error('command `submit` expectes 0 or 1 arguments');
        var submitter = new lix.Submitter(remote, new archive.zip.NodeZip(), archive.scanner.AsysScanner.new.bind(_, ''));
        return submitter.submit(args[0]);
      }),
      new Command('owner', 'create <name>', 'Create an owner (organization) in the Lix Registry', function (args) {
        return switch args {
          case ['create', name]:
            remote.owners().create(name);
          case _:
            new Error('Invalid arguments');
        }
      }),
      // new Command('me', '', 'Prints the current logged in username', function (args) {
      //   var auth = new lix.Auth();
      //   var remote = new lix.Remote(
      //     #if (environment == "local")
      //       new NodeClient(), () -> '2'
      //     #else 
      //       new SecureNodeClient(), () -> auth.getSession().next(session -> session.idToken)
      //     #end
      //   );
      //   return remote.me().get().next(user -> {
      //     Sys.println('Current username: ${user.username}');
      //     Noise;
      //   });
      // }),
    ], []).handle(Command.reportOutcome);
  }       
}