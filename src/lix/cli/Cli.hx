package lix.cli;

import haxe.DynamicAccess;
import lix.client.Archives;
import lix.client.sources.*;
import lix.api.Api;
import lix.client.*;

using haxe.io.Path;

class Cli {

  static function main()
    Command.attempt(HaxeCmd.ensureScope(), dispatch.bind(Sys.args()));

  static function dispatch(args:Array<String>) {
    var version = CompileTime.parseJsonFile("package.json").version;
    var silent = args.remove('--silent'),
        force = args.remove('--force'),
        global = args.remove('--global') || args.remove('-g'),
        flat = args.remove('--flat');

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
    var web = new Web([gitlab.intercept, github.intercept]);
    var sources:Array<ArchiveSource> = [web, new Haxelib(haxelibUrl), github, gitlab, new Git(scope)];
    var resolvers:Map<String, ArchiveSource> = [for (s in sources) for (scheme in s.schemes()) scheme => s];

    function resolve(url:Url):Promise<ArchiveJob>
      return switch resolvers[url.scheme] {
        case null:
          new Error('Unknown scheme in url $url');
        case v:
          v.processUrl(url);
      }

    var logger = Logger.get(silent);

    var hx = new lix.client.haxe.Switcher(scope, logger);
    var libs = new Libraries(
      scope,
      resolve,
      function (_) return new Error(NotImplemented, "not implemented"),
      logger,
      force
    );

    Command.dispatch(args, 'lix - Libraries for Haxe (v$version)', [
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
                  libs.installUrl(url, LibVersion.parse(alias), { flat: flat });
                case [library, _] | [library] if ((library:Url).scheme == null):
                  new Error('Did you mean `lix install haxelib:$library`?');
                case [url]:
                  libs.installUrl(url, { flat: flat });
                case []: new Error('Missing url');
                case v: new Error('too many arguments');
              }
      ),
      new Command('install haxe', '<version>|<alias>', 'install specified haxe version', null),//this is never matched and is here purely for usage display
      new Command('use', 'haxe <version>|<alias>', 'use specified haxe version', function (args) return switch args {
        case ['haxe', version]: hx.resolveInstalled(version).next(hx.switchTo);
        default: new Error('invalid arguments');
      }),
      new Command('dev', '<lib> <path>', 'use dev version of library', args -> switch args {
        case [lib, path]: libs.dev(lib, path);
        default: new Error('invalid arguments');
      }),
      new Command('download haxe', '<version>|<alias>', 'download specified haxe version', null),//this is never matched and is here purely for usage display
      new Command('scope', '[create|delete]', 'creates or deletes the current scope or\ninspects it if no argument is supplied',
        function (args) return switch args {
          case ['create']:
            Scope.create(scope.cwd, {
              version: scope.config.version,
              resolveLibs: if (scope.isGlobal) Scoped else scope.config.resolveLibs,
            }).next(_ -> {
              logger.success('created scope in ${scope.cwd}');
              Noise;
            });
          case ['delete']:
            if (scope.isGlobal)
              new Error('Cannot delete global scope');
            else {
              scope.delete();
              logger.success('deleted scope in ${scope.scopeDir}');
              Noise;
            }
          case []:
            logger.info(
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
              logger.warning('Warning: Processing obsolete `download ${args.map(shorten).join(" ")}`.\n        Please reinstall library in a timely manner!\n\n');
              libs.downloadUrl(url, { into: target })
                .next(a -> Fs.ensureDir(absTarget).swap(a))
                .next(a -> {
                  a.absRoot.rename(absTarget);
                  a;
                });
            }
          case [url, 'into', dir]:

            libs.downloadUrl(url, { into: dir });

          case [(_:Url) => url]:

            libs.downloadUrl(url);

          case []:

            lix.client.haxe.Switcher.ensureNeko(logger)
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
    ], [],
      args -> switch args[0] {
        case null: None;
        case '-lib' | '--library' | '-L' | '--run' | (_.endsWith('.hxml') => true):
          Some(() -> {
            @:privateAccess new haxeshim.HaxeCli(scope).dispatch(args);
            Noise;
          });
        case lib if (scope.libHxml(lib).exists()):
          Some(() -> {
            new haxeshim.HaxelibCli(scope).run(args);
            Noise;
          });
        case cls if (isClassName(cls)):
          Some(() -> {
            function absolute(path:String)
              return Path.join([scope.scopeDir, path]);

            Fs.get(absolute('haxelib.json'))
              .next(s -> haxe.Json.parse.bind(s).catchExceptions())
              .recover(_ -> {
                classPath: '',
                name: scope.scopeDir.removeTrailingSlashes().withoutDirectory(),
                dependencies: new DynamicAccess<String>()
              })
              .next(
                function (info) {

                  var file = cls.replace('.', '/') + '.hx';

                  var candidates = [
                    { file: file, args: ['-cp', absolute('')] },
                    { file: 'scripts/$file', args: ['-cp', absolute('scripts')] }
                  ];

                  switch info.classPath {
                    case null | '':
                    case cp:
                      candidates.push({
                        file: '$cp/$file',
                        args:
                          if (scope.libHxml(info.name).exists()) ['-lib', info.name]
                          else {
                            var ret = [];
                            switch info.dependencies {
                              case null: [];
                              case deps:
                                for (k => v in deps) {
                                  ret.push('-lib');
                                  ret.push(k);
                                }
                            }
                            ret.concat(['-cp', absolute(cp)]);
                          }
                      });
                    }

                  for (c in candidates)
                    switch Path.join([scope.scopeDir, c.file]) {
                      case _.exists() => false:
                      case found:
                        return Fs.get(found)
                          .next(function (content) {
                            var buildArgs = [];
                            {
                              var lines = content.split('\n'),
                                  pos = 0;
                              if (lines[0].startsWith('#!'))
                                pos++;
                              while (true)
                                switch lines[pos++].trim() {
                                  case '':
                                  case content:
                                    if (content.startsWith('//!')) {
                                      for (v in content.substr(3).split(' '))
                                        switch v.trim() {
                                          case '':
                                          case v: buildArgs.push(v);
                                        }
                                    }
                                    else break;
                                }
                            }

                            buildArgs = buildArgs.concat(c.args);
                            var runArgs = args.slice(1);

                            return
                              switch scope.getBuilds(buildArgs) {
                                case Failure({ errors: errors }) | Success([Failure({ errors: errors }) | Success(_.checkClassPaths() => Failure({ errors: errors }))]):
                                  var e = errors[0];
                                  new Error(e.code, e.pos.toString() + ': ' + e.message);
                                case Success([Success({ cwd: cwd, args: args })]):
                                  var args = [for (a in args) a.val];
                                  var nodeFile = null;

                                  for (i in 0...args.length - 1)
                                    switch args[i] {
                                      case '-D' | '--define':
                                        switch args[i + 1] {
                                          case 'hxnodejs', _.startsWith('hxnodejs=') => true:
                                            nodeFile = switch args.indexOf('-js') {
                                              case -1:
                                                var ret = found.withoutExtension().withExtension('js');
                                                args = args.concat(['-js', ret]);
                                                ret;
                                              case v:
                                                args[v + 1];//could be null ... perhaps should be forbidden altogether
                                            }
                                            break;
                                          default:
                                        }
                                      default:
                                    }

                                  args = args.concat(switch nodeFile {
                                    case null: ['--run', cls].concat(runArgs);
                                    default: ['-main', cls];
                                  });

                                  switch Exec.sync(scope.haxeInstallation.compiler, cwd, args, scope.haxeInstallation.env()) {
                                    case Success(0):
                                      switch nodeFile {
                                        case null: Noise;
                                        default:
                                          Fs.get(nodeFile)
                                            .next(script ->
                                              Fs.save(nodeFile, [
                                                'try { require("fs").unlinkSync(__filename); } catch (e) {}',
                                                script,
                                              ].join('\n'))
                                            )
                                            .next(_ ->
                                              switch Exec.sync('node', cwd, [nodeFile].concat(runArgs)) {
                                                case Success(0): Noise;
                                                case Success(v): new Error(v, 'node exited with code $v');
                                                case Failure(e): e;
                                              }
                                            );
                                      }
                                    case Success(v): new Error(v, 'haxe exited with code $v');
                                    case Failure(e): e;
                                  }
                                case Success(_):
                                  new Error('multiple builds defined');
                              }

                            // @:privateAccess new haxeshim.HaxeCli(scope).dispatch(c.args.concat(['--run', cls]).concat(args.slice(1)));//This always exits
                            return Noise;
                          });
                    }

                  return new Error(NotFound, 'Class not found: $cls');
                }
              );
          });
        default: None;
      }
    ).handle(Command.reportOutcome);
  }

  static function isClassName(s:String) {
    var char = s.split('.').pop().charCodeAt(0);
    return char >= 'A'.code && char <= 'Z'.code;
  }

}
