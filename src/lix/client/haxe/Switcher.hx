package lix.client.haxe;

using lix.client.haxe.ResolvedVersion;
using lix.client.haxe.UserVersion;

enum PickOfficial {
  StableOnly;
  IncludePrereleases;
}

class Switcher {

  public var scope(default, null):haxeshim.scope.Scope;
  public var logger(default, null):Logger;
  var downloads:String;

  public function new(scope, logger) {
    this.scope = scope;
    this.logger = logger;

    Fs.ensureDir(scope.versionDir.addTrailingSlash()).eager();//TODO: avoid these
    Fs.ensureDir(scope.haxelibRepo.addTrailingSlash()).eager();
    Fs.ensureDir(this.downloads = scope.haxeshimRoot + '/downloads/').eager();
  }

  static var VERSION_INFO = 'version.json';

  static function nightlies() 
    return 'https://build.haxe.org/builds/haxe/' + switch Os.platform {
      case Linux64: 'linux64';
      case LinuxArm64: 'linux-arm64';
      case Win64:'windows64';
      case Mac64 | MacArm | MacUniversal: 'mac';
      case v: v;
    }

  static function linkToNightly(hash:String, date:Date, ?file:String) {
    if (file == null) 
      file = date.format('haxe_%Y-%m-%d_development_$hash.tar.gz');
    return date.format('${nightlies()}/$file');
  }

  static function sortedOfficial(kind:PickOfficial, versions:Array<Official>):Iterable<Official> {
    if (kind == StableOnly)
      versions = [for (v in versions) if (!v.isPrerelease) v];
    versions.sort(Official.compare);
    return versions;
  }

  static public function officialOnline(kind:PickOfficial):Promise<Iterable<Official>>
    return Download.text('https://haxe.org/website-content/downloads/versions.json')
      .next(function (s) {
        return sortedOfficial(kind, s.parse().versions.map(function (v) return v.version));
      });

  static function sortedNightlies(raw:Array<Nightly>):Iterable<Nightly> {
    raw.sort(function (a, b) return Reflect.compare(b.published.getTime(), a.published.getTime()));
    return raw;
  }


  static public function nightliesOnline():Promise<Iterable<Nightly>> {
    return Promise.lift(nightlies()).next(Download.text).next(function (s:String):Iterable<Nightly> {
      var lines = s.split('------------------\n').pop().split('\n'),
          ret = new Array<Nightly>();

      function parseDate(date:String)
        return try Some(Date.fromString(date)) catch (e:Dynamic) None;

      for (l in lines)
        switch l.trim().split('<a href="') {
          case [parseDate(_.split('  ')[0]) => Some(published), _.split('"')[0] => file]:
            switch file.split('.')[0].split('_').pop() {
              case 'latest':
              case hash:
                ret.push({
                  hash: hash,
                  file: file,
                  development: file.indexOf('_development_') != -1,
                  published: published
                });
            }
          default:
        }
      return sortedNightlies(ret);
    });
  }

  public function officialInstalled(kind):Promise<Iterable<Official>>
    return
      attempt(
        'Get installed Haxe versions',
        sortedOfficial(kind, [for (v in scope.versionDir.readDirectory())
          if (!v.isHash() && !Hxmc.isHxmc(v) && versionDir(v).isDirectory()) v
        ])
      );

  static function attempt<A>(what:String, l:Lazy<A>):Promise<A>
    return
      try
        Success(l.get())
      catch (e:Dynamic)
        Failure(new Error('Failed to $what because $e'));

  // the installed hxmc builds, by their versions (`hxmc-<version>`)
  public function hxmcInstalled():Promise<Array<String>>
    return
      attempt(
        'get installed hxmc builds',
        {
          final l = [for (v in scope.versionDir.readDirectory()) if (v.startsWith(Hxmc.PREFIX)) v];
          l.sort(Reflect.compare);
          l;
        }
      );

  public function nightliesInstalled()
    return
      attempt(
        'get installed Haxe versions',
        sortedNightlies([for (v in scope.versionDir.readDirectory().filter(UserVersion.isHash)) {
          hash: v,
          published: Date.fromString('${versionDir(v)}/$VERSION_INFO'.getContent().parse().published)
        }])
      );

  public function switchTo(version:ResolvedVersion):Promise<Noise>
    return
      if (version.id == scope.config.version) Noise;
      else scope.reconfigure({
        version: version.id,
        resolveLibs: scope.config.resolveLibs,
      }).next(_ -> ensureNeko(scope.haxeInstallation.neko, logger));

  public function resolveInstalled(version:UserVersion):Promise<ResolvedVersion>
    return resolve(version, officialInstalled, nightliesInstalled, hxmcResolveInstalled);

  public function resolveOnline(version:UserVersion):Promise<ResolvedVersion>
    return resolve(version, officialOnline, nightliesOnline, hxmcOnline);

  // (an hxmc build: installed by its exact version, online by any spec, Hxmc)
  function hxmcResolveInstalled(spec:String):Promise<ResolvedVersion>
    return
      if (versionDir(Hxmc.PREFIX + spec).exists()) RHxmc(spec)
      else new Error(NotFound, 'Unable to resolve hxmc build $spec locally, install it first with `lix install haxe ${Hxmc.PREFIX}$spec`');

  static function hxmcOnline(spec:String):Promise<ResolvedVersion>
    return Hxmc.resolve(spec).next(v -> RHxmc(v));

  static function pickFirst<A>(kind:String, make:A->ResolvedVersion, ?filter:A->Bool):Next<Iterable<A>, ResolvedVersion>
    return switch filter {
      case null:
        pickFirst(kind, make, _ -> true);
      default:
        function (i:Iterable<A>) {
          for (v in i)
            if (filter(v)) return make(v);
          return new Error(NotFound, 'No $kind build found');
        }
    }

  function resolve(version:UserVersion, getOfficial:PickOfficial->Promise<Iterable<Official>>, getNightlies:Void->Promise<Iterable<Nightly>>, getHxmc:String->Promise<ResolvedVersion>):Promise<ResolvedVersion>
    return switch version {
      case UEdge:

        getNightlies().next(pickFirst('nightly', RNightly, v -> v.development != false));

      case ULatest:

        getOfficial(IncludePrereleases).next(pickFirst('official', ROfficial));

      case UStable:

        getOfficial(StableOnly).next(pickFirst('stable', ROfficial));

      case UNightly(hash):

        getNightlies().next(function (v) {
          for (n in v)
            if (n.hash == hash)
              return RNightly(n);

          return new Error(NotFound, 'Unable to resolve nightly version $hash locally, install it first with `lix install haxe $hash`');
        });

      case UOfficial(version):

        getOfficial(IncludePrereleases).next(function (versions)
          return
            if (Lambda.has(versions, version)) ROfficial(version)
            else new Error(NotFound, 'Unable to resolve version $version locally, install it first with `lix install haxe $version`')
        );

      case UCustom(path): RCustom(path);

      case UHxmc(spec): getHxmc(spec);
    }

  function versionDir(name:String)
    return scope.getInstallation(name).path;

  function isDownloaded(r:ResolvedVersion)
    return versionDir(r.id).exists();

  function linkToOfficial(version)
    return
      'https://haxe.org/website-content/downloads/$version/downloads/haxe-$version-' + switch Sys.systemName() {
        case 'Windows':
          'win${if (version < "5") '' else '64'}.zip';
        case 'Mac': 'osx.tar.gz';
        default:
          'linux${if (version < "3") '' else '64'}.tar.gz';
      }

  function replace(target:String, replacement:String, archiveAs:String, ?beforeReplace) {
    var root = replacement;

    while (true)
      switch replacement.ls() {
        case [sub]:
          replacement = sub;
        default: break;
      }

    if (beforeReplace != null)
      beforeReplace(replacement);

    if (target.exists()) {
      var old = '$downloads/$archiveAs@${Math.floor(target.stat().ctime.getTime())}';
      target.rename(old);
      replacement.rename(target);
    }
    else {
      replacement.rename(target);
    }

    if (root.exists())
      root.delete();
  }

  public function install(version:String, options:{ force: Bool })
    return resolveAndDownload(version, options).next(switchTo);

  public function resolveAndDownload(version:String, options:{ force: Bool }) {
    return (switch ((version : UserVersion) : UserVersionData) {
      case UOfficial(_) | UHxmc(_):
        resolveInstalled(version);
      default:
        Promise.lift(new Error('$version needs to be resolved online'));
    }).tryRecover(function (_) {
      logger.info('Looking up Haxe version "$version" online');
      return resolveOnline(version).next(function (r) {
        logger.info('  Resolved to $r. Downloading ...');
        return r;
      });
    }).next(function (r) {
      return download(r, options).next(function (wasDownloaded) {

        logger.success(
          if (!wasDownloaded)
            '  ... already downloaded!'
          else
            '  ... download complete!'
        );

        return r;
      });
    });
  }


  public function download(version:ResolvedVersion, options:{ force: Bool }):Promise<Bool> {

    inline function download(url, into) {
      logger.info('Downloading Haxe: $version');
      return Download.archive(url, 0, into, logger);
    }

    final getDownloadDir = name -> '$downloads/$name@${Math.floor(Date.now().getTime())}_${js.Node.process.pid}';

    return switch version {
      case isDownloaded(_) => true if (options.force != true):

        false;

      case RCustom(_):

        new Error('Cannot download custom version');

      case RNightly({ hash: hash, published: date, file: file }):

        download(linkToNightly(hash, date, file), getDownloadDir(hash)).next(dir -> {
          replace(versionDir(hash), dir, hash, function (dir) {
            '$dir/$VERSION_INFO'.saveContent(haxe.Json.stringify({
              published: date.toString(),
            }));
          });
          true;
        });

      case ROfficial(version):

        download(linkToOfficial(version), getDownloadDir(version)).next(dir -> {
          replace(versionDir(version), dir, version);
          true;
        });

      case RHxmc(v):

        logger.info('Downloading hxmc: $v');
        Hxmc.install(v, scope.haxeshimRoot, versionDir(version.id), logger).next(_ -> true);
    }
  }

  static public function ensureNeko(neko:NekoInstallation, logger:Logger):Promise<String> {
    var path = neko.path;

    return
      if (path.exists())
        path;
      else {
        logger.info('Neko seems to be missing. Attempting download ...');

        switch getNekoUrl(neko) {
          case Success(url):
            final download = if (neko.platform.isWindows) Download.zip else Download.tar;

            download(url, 1, path, logger).next(function (x) {
              logger.success('done');
              return x;
            });

          case Failure(e):
            e;
        }
      }
  }

  static public function getNekoUrl(neko:NekoInstallation) {
    final archive = switch neko.platform {
      case Linux64: 'linux64';
      case LinuxArm64: 'linux-arm64';
      case Win32: 'win';
      case Win64: 'win64';
      case Mac64 | MacArm | MacUniversal: 'osx-universal';// wonder if this always works
      case v:
        return Failure(new Error('Unsupported platform: $v'));
    }
    return Success('https://github.com/HaxeFoundation/neko/releases/download/v${neko.version.replace('.', '-')}/neko-${neko.version}-${archive}.${if (neko.platform.isWindows) 'zip' else 'tar.gz'}');
  }

}
