package lix.client;

import lix.client.sources.*;
import haxe.DynamicAccess;
import lix.client.Archives;
import lix.api.Api;
import haxeshim.Scope.*;

using haxe.Json;

@:tink class Libraries {

  public var scope(default, null):Scope = _;

  var urlToJob:Url->Promise<ArchiveJob> = _;
  var resolver:Array<Dependency>->Promise<Array<ArchiveJob>> = _;

  public var logger(default, null):Logger = _;
  public var force(default, null):Bool = _;

  public function downloadUrl(url:Url, ?options)
    return downloadArchive(urlToJob(url), options);

  public function downloadArchive(a:Promise<ArchiveJob>, _ = { into: (null:String) }):Promise<DownloadedArchive>
    return a.next(
      function (a) {

        var cacheFile = null;

        if (into == null)
          switch a.dest {
            case Fixed(path):
              into = DownloadedArchive.path(path);
            case Computed(_):
              cacheFile = '${scope.libCache}/.cache/libNames/${DownloadedArchive.escape(a.normalized)}';
              if (cacheFile.exists())
                into = cacheFile.getContent();
          }

        var exists = into != null && '${scope.libCache}/$into'.exists();
        return
          if (exists && !force) {
            logger.success('already downloaded: ${a.normalized}');
            DownloadedArchive.existent(into, scope.libCache, a);
          }
          else {
            logger.info('${if (exists) "forcedly redownloading" else "downloading"} ${a.normalized}');
            var dest = scope.haxeshimRoot + '/downloads/download@' + Date.now().getTime();
            (switch a.kind {
              case null: Download.archive(a.url, 0, dest, logger);
              case Zip: Download.zip(a.url, 0, dest, logger);
              case Tar: Download.tar(a.url, 0, dest, logger);
              case Custom(load):
                load({ dest: dest, logger: logger, source: a.normalized, scope: scope });
            })
              .next(dir => DownloadedArchive.fresh(dir, scope.libCache, into, a))
              .next(arch =>
                if (cacheFile != null)
                  Fs.save(cacheFile, arch.relRoot).swap(arch)
                else arch
              );
          }
      }
    );

  public function installUrl(url:Url, ?as:LibVersion, ?options):Promise<Noise>
    return installArchive(urlToJob(url), as, options);

  function installFromLibHxml(lib:String, srcPath:String):Promise<Array<String>> {
    var hxml = scope.libHxml(lib);
    return Fs.copy(srcPath, '${scope.scopeLibDir}/$lib.hxml')
      .next(_ -> scope.getDirectives(lib))
      .next(d -> switch d['install'] {
        case null | []:
          new Error('No install directive in $srcPath');
        case directives:
          Promise.inSequence([for (d in directives)
            Promise.NOISE.next(_ -> {
              logger.info(d);
              Exec.shell(d, scope.scopeDir);
            })
          ]);
      })
      .next(_ -> Fs.get(srcPath))
      .next(content -> Args.fromMultilineString(content, hxml, scope.getVar))
      .next(o -> switch o {
        case Success(args): [for (a in args) a.val];
        case Failure(_.errors[0] => e): new Error(e.code, e.message);
      })
      .next(args -> [for (i => a in args) if (a == '-lib' && Args.getNdll(args[i + 1]) == None) args[i + 1]]);
  }


  public function dev(lib:String, path:String):Promise<Noise> {

    var isAbsolute = path.isAbsolute();

    var absPath =
      if (isAbsolute) path;
      else Path.join([scope.scopeDir, path]);

    var usedPath =
      if (isAbsolute) path;
      else '$${SCOPE_DIR}/$path';

    return switch absPath.readDirectory.catchExceptions() {
      case Success(files) if (files.indexOf('haxelib.json') != -1):

        var manifest = '$absPath/haxelib.json';
        Fs.get(manifest)
          .next(s ->
            try (haxe.Json.parse(s):{ ?version:String, ?classPath:String, ?dependencies:haxe.DynamicAccess<String> })
            catch (e:Dynamic) new Error('cannot parse $manifest')
          )
          .next(
            info -> {
              var lines = [];
              if (info.dependencies != null)
                for (k => v in info.dependencies)
                  lines.push('-lib $k');

              lines.push('-cp ' + switch info.classPath {
                case null: path;
                case v: '$usedPath/$v';
              });
              lines.push('-D $lib='+ switch info.version {
                case null: 'dev';
                case v: v;
              });

              var line = lines.length;

              if (files.indexOf('extraParams.hxml') != -1)
                lines.push('$usedPath/extraParams.hxml');

              lines.push('--macro Sys.println("haxe_libraries/$lib.hxml:$line: [Warning] Using dev version of library $lib")');
              Fs.save(scope.libHxml(lib), lines.join('\n'));
            }
          );
      case Success(_):
        new Error('$absPath does not contain haxelib.json');
      default:
        new Error('$absPath is not a readable directory');
    }
  }

  public function installArchive(
      a:Promise<ArchiveJob>,
      ?as:LibVersion,
      options = {
        alreadyInstalled: new Map(),
        flat: false,
      }
    ):Promise<Noise>

    return downloadArchive(a).next(function (a) {
      var extra =
        switch '${a.absRoot}/extraParams.hxml' {
          case found if (found.exists()):
            found.getContent();
          default: null;
        }

      if (as == null)
        as = { name: None, version: None };

      var infos:ArchiveInfos = a.infos;

      var name = as.name.or(infos.name),
          version = as.version.or(infos.version);

      if (name == null)
        return new Error('Could not determine library name for ${a.job.normalized}');

      var hxml = scope.libHxml(name);

      var DOWNLOAD_LOCATION = '$${$LIBCACHE}/${a.relRoot}';

      function interpolate(s)
        return scope.interpolate(s, switch _ {
          case 'DOWNLOAD_LOCATION': DOWNLOAD_LOCATION;
          default: null;
        });

      function exec(hook:String, cmd:Null<String>, ?cwd:String):Promise<Noise>
        return
          if (cmd != null) {

            cmd = interpolate(cmd);

            if (cwd == null)
              cwd = scope.cwd;

            logger.info('Running $hook hook:');
            logger.info('> $cmd');

            Exec.shell(
              cmd,
              scope.interpolate(cwd),
              scope.haxeInstallation.env()
            ).map(_ => Noise);
          }
          else
            Noise;

      function saveHxml<T>(?value:T):Promise<T> {
        var directives = [
          '# @$INSTALL: lix --silent download "${a.job.normalized}" into ${a.relRoot}',
        ];

        switch infos.postDownload {
          case null:
          case v: directives.push('# @$POST_INSTALL: cd $DOWNLOAD_LOCATION && ${interpolate(v)}');
        }

        switch infos.runAs({ libRoot: scope.interpolate(DOWNLOAD_LOCATION) }) {
          case None:
          case Some(v):
            directives.push('# @run: ' + Args.interpolate(v, switch _ {
              case 'DOWNLOAD_LOCATION': DOWNLOAD_LOCATION;
              case v: '$${$v}';
            }).sure());
        }

        function lines(a:Array<String>)
          return [for (l in a) if (l != null) l].join('\n');

        return Fs.save(
          hxml,
          lines(
            directives
              .concat([for (lib in infos.dependencies) '-lib ${lib.name}'])
              .concat([
                '-cp $DOWNLOAD_LOCATION/${infos.classPath}',
                '-D $name=$version',
                extra,
                if (infos.hasNdll) '-lib ' + Args.makeNdll('$DOWNLOAD_LOCATION/ndll/') else null,
              ])
          )
        ).next(_ -> {
          options.alreadyInstalled[name] = true;
          value;
        });
      };

      function installDependencies()
        return
          if (options.flat) Promise.NOISE;
          else
            Future.ofMany(//TODO: this relies on the implementation being sequential (which it currently is, but that may change)
              [for ({ name: lib, value: dep } in infos.dependencies)
                Future.async(//TODO: it should probably be fine to skip this lazy wrapper
                  function (done)
                    if ('${scope.scopeLibDir}/$lib.hxml'.exists() && options.alreadyInstalled[lib]) //TODO: this should be in some function
                      done(Success(Noise))
                    else switch [dep, infos.haxeshimDependencies[lib]] {
                      case [FromUrl(url), null]:
                        installUrl(url, { name: Some(lib), version: None }, options)
                          .next(n -> {
                            options.alreadyInstalled[lib] = true;
                            n;
                          }).handle(done);
                      case [FromHxml(path), _] | [_, path]:
                        function install(lib, path)
                          return
                            if (options.alreadyInstalled[lib]) Noise;
                            else installFromLibHxml(lib, path)
                              .next(deps -> {
                                options.alreadyInstalled[lib] = true;
                                Promise.inSequence(
                                  [for (name in deps)
                                    install(name, infos.haxeshimDependencies[name])
                                  ]
                                );
                              });

                        install(lib, path).handle(done);
                    },
                  true
                )
              ]
            )
            .next(results => switch [for (Failure(e) in results) e] {
              case []: Noise;
              case errors: Error.withData('Failed to install dependencies of $name :\n  ' + errors.map(e => e.message).join('\n  '), errors);
            });

      return
        saveHxml()
          .next(_ -> {
            logger.success('-> mounted as $name#$version');
            Noise;
          })
          .next(_ -> installDependencies())
          .next(_ =>
            if (!a.alreadyDownloaded) exec('post download', infos.postDownload, DOWNLOAD_LOCATION)
            else Noise
          )
          .next(saveHxml)
          .next(_ => exec('post install', infos.postInstall));
    });
}