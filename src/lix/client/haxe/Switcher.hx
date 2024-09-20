package lix.client.haxe;

using lix.client.haxe.ResolvedVersion;
using lix.client.haxe.UserVersion;

enum PickOfficial {
  StableOnly;
  IncludePrereleases;
}

class Switcher {

  public var scope(default, null):haxeshim.Scope;
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
  static var NIGHTLIES = 'https://build.haxe.org/builds/haxe';
  static var PLATFORM =
    switch [Sys.systemName(), js.Node.process.arch] {
      case ['Windows', _]: 'windows';
      case ['Mac', _]: 'mac';
      case [_, 'arm64']: 'linux-arm64';
      case _: 'linux64';
    }

  static function linkToNightly(hash:String, date:Date, ?file:String) {
    if (file == null) {
      var extension =
        // Windows builds are distributed as a zip file since 2017-05-11
        if (PLATFORM == 'windows' && date.getTime() > 1494460800000) 'zip'
        else 'tar.gz';
      file = date.format('haxe_%Y-%m-%d_development_$hash.$extension');
    }
    return date.format('$NIGHTLIES/$PLATFORM/$file');
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
    return Download.text('$NIGHTLIES/$PLATFORM/').next(function (s:String):Iterable<Nightly> {
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
          if (!v.isHash() && versionDir(v).isDirectory()) v
        ])
      );

  static function attempt<A>(what:String, l:Lazy<A>):Promise<A>
    return
      try
        Success(l.get())
      catch (e:Dynamic)
        Failure(new Error('Failed to $what because $e'));

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
      });

  public function resolveInstalled(version:UserVersion):Promise<ResolvedVersion>
    return resolve(version, officialInstalled, nightliesInstalled);

  public function resolveOnline(version:UserVersion):Promise<ResolvedVersion>
    return resolve(version, officialOnline, nightliesOnline);

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

  function resolve(version:UserVersion, getOfficial:PickOfficial->Promise<Iterable<Official>>, getNightlies:Void->Promise<Iterable<Nightly>>):Promise<ResolvedVersion>
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
    }

  function versionDir(name:String)
    return scope.getInstallation(name).path;

  function isDownloaded(r:ResolvedVersion)
    return versionDir(r.id).exists();

  function linkToOfficial(version)
    return
      'https://haxe.org/website-content/downloads/$version/downloads/haxe-$version-' + switch Sys.systemName() {
        case 'Windows':
          var arch = '';
          // #if nodejs
          //   if (js.node.Os.arch().contains('64')) arch = '64';
          // #elseif sys
          //   if (version > "3.4.3" && version != "4.0.0-preview.1") {
          //     var wmic = new sys.io.Process('WMIC OS GET osarchitecture /value');
          //     try
          //       switch wmic.stdout.readAll().toString() {
          //         case v if (v.indexOf('64') >= 0):
          //           arch = '64';
          //         case _:
          //       }
          //     catch(_:Any) {}
          //     wmic.close();
          //   }
          // #else
          //   #error
          // #end
          'win$arch.zip';
        case 'Mac': 'osx.tar.gz';
        default:
          if (version < "3")
            'linux.tar.gz';
          else
            'linux64.tar.gz';
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
      case UOfficial(_):
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
    }
  }

  static public function ensureNeko(logger:Logger):Promise<String> {

    var neko = Neko.PATH;

    return
      if (neko.exists())
        neko;
      else {

        logger.info('Neko seems to be missing. Attempting download ...');

        var getUrl = (platformArchive:String)->'https://github.com/HaxeFoundation/neko/releases/download/v2-4-0/neko-2.4.0-${platformArchive}';
        var downloadArchive:(peel:Int, into:String, logger:Logger)->Promise<Download.Directory> = switch [Sys.systemName(), js.Node.process.arch] {
          case ['Windows', _]: Download.zip.bind(getUrl('win.zip'));
          case ['Mac', _]: Download.tar.bind(getUrl('osx-universal.tar.gz'));
          case [_, 'arm64']: Download.tar.bind(getUrl('linux-arm64.tar.gz'));
          default: Download.tar.bind(getUrl('linux64.tar.gz'));
        }

        downloadArchive(1, neko, logger).next(function (x) {
          logger.success('done');
          return x;
        });
      }
  }

}
