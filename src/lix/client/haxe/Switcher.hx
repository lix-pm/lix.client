package lix.client.haxe;

using lix.client.haxe.UserVersion;
using lix.client.haxe.ResolvedVersion;

enum PickOfficial {
  StableOnly;
  IncludePrereleases;
}

class Switcher {
  
  public var scope(default, null):haxeshim.Scope;
  public var silent(default, null):Bool;
  public var log(default, null):String->Void;
  var downloads:String;
    
  public function new(scope, silent, log) {
    this.scope = scope;
    this.silent = silent;
    this.log = log;
    
    Fs.ensureDir(scope.versionDir.addTrailingSlash());
    Fs.ensureDir(scope.haxelibRepo.addTrailingSlash());
    Fs.ensureDir(this.downloads = scope.haxeshimRoot + '/downloads/');
  }
  
  static var VERSION_INFO = 'version.json';  
  static var NIGHTLIES = 'http://hxbuilds.s3-website-us-east-1.amazonaws.com/builds/haxe';
  static var PLATFORM =
    switch Sys.systemName() {
      case 'Windows': 'windows';
      case 'Mac': 'mac';
      default: 'linux64';
    } 
  
  static function linkToNightly(hash:String, date:Date) {
    var extension = 
      // Windows builds are distributed as a zip file since 2017-05-11
      if (PLATFORM == 'windows' && date.getTime() > 1494460800000) 'zip'
      else 'tar.gz';
    return date.format('$NIGHTLIES/$PLATFORM/haxe_%Y-%m-%d_development_$hash.$extension');
  }
  
  static function sortedOfficial(kind:PickOfficial, versions:Array<Official>):Iterable<Official> {
    if (kind == StableOnly)
      versions = [for (v in versions) if (!v.isPrerelease) v];
    versions.sort(Official.compare);
    return versions;
  }
    
  static public function officialOnline(kind:PickOfficial):Promise<Iterable<Official>>
    return Download.text('https://raw.githubusercontent.com/HaxeFoundation/haxe.org/staging/downloads/versions.json')
      .next(function (s) {
        return sortedOfficial(kind, s.parse().versions.map(function (v) return v.version));
      });
      
  static function sortedNightlies(raw:Array<Nightly>):Iterable<Nightly> {
    raw.sort(function (a, b) return Reflect.compare(b.published.getTime(), a.published.getTime()));
    return raw;
  }
  
  static public function nightliesOnline():Promise<Iterable<Nightly>> {
    return Download.text('$NIGHTLIES/$PLATFORM/').next(function (s:String):Iterable<Nightly> {
      var lines = s.split('------------------\n').pop().split('\n');
      var ret = [];
      for (l in lines) 
        switch l.trim() {
          case '':
          case v:
            if (v.indexOf('_development_') != -1)
              switch v.indexOf('   ') {
                case -1: //whatever
                case v.substr(0, _).split(' ') => [
                  _.split('-').map(Std.parseInt) => [y, m, d], 
                  _.split(':').map(Std.parseInt) => [hh, mm, ss]
                ]:
                  
                  ret.push({
                    hash: v.split('_development_').pop().split('.').shift(),
                    published: new Date(y, m - 1, d, hh, mm, ss),
                  });
                  
                default:
                  
              }
            
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
          hash:v, 
          published: Date.fromString('${versionDir(v)}/$VERSION_INFO'.getContent().parse().published)
        }])
      );
    
  public function switchTo(version:ResolvedVersion):Promise<Noise>
    return 
      scope.reconfigure({
        version: version.id,
        resolveLibs: scope.config.resolveLibs,
      });

  public function resolveInstalled(version:UserVersion):Promise<ResolvedVersion>
    return resolve(version, officialInstalled, nightliesInstalled);
    
  public function resolveOnline(version:UserVersion):Promise<ResolvedVersion>
    return resolve(version, officialOnline, nightliesOnline);
  
  static function pickFirst<A>(kind:String, make:A->ResolvedVersion):Next<Iterable<A>, ResolvedVersion> 
    return function (i:Iterable<A>) 
      return switch i.iterator().next() {
        case null: new Error(NotFound, 'No $kind build found');
        case v: make(v);
      }
    
  function resolve(version:UserVersion, getOfficial:PickOfficial->Promise<Iterable<Official>>, getNightlies:Void->Promise<Iterable<Nightly>>):Promise<ResolvedVersion>
    return switch version {
      case UEdge: 
        
        getNightlies().next(pickFirst('nightly', RNightly));
        
      case ULatest:
        
        getOfficial(IncludePrereleases).next(pickFirst('official', ROfficial));
        
      case UStable: 
        
        getOfficial(StableOnly).next(pickFirst('stable', ROfficial));
        
      case UNightly(hash): 

        getNightlies().next(function (v) {
          for (n in v)
            if (n.hash == hash)
              return RNightly(n);
              
          return new Error(NotFound, 'Unable to resolve nightly version $version locally, install it first with `lix install haxe $version`');
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
      'http://haxe.org/website-content/downloads/$version/downloads/haxe-$version-' + switch Sys.systemName() {
        case 'Windows': 'win.zip';
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
      case UNightly(_) | UOfficial(_): 
        resolveInstalled(version);
      default: 
        Promise.lift(new Error('$version needs to be resolved online'));
    }).tryRecover(function (_) {
      log('Looking up Haxe version "$version" online');
      return resolveOnline(version).next(function (r) {
        log('  Resolved to $r. Downloading ...');
        return r;
      });
    }).next(function (r) {
      return download(r, options).next(function (wasDownloaded) {
        
        log(
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
    
    inline function download(url, into)
      return Download.archive(url, 0, into, !silent);
    
    return switch version {
      case RCustom(_): 

        new Error('Cannot download custom version');

      case isDownloaded(_) => true if (options.force != true):
        
        false;
        
      case RNightly({ hash: hash, published: date }):
        
        download(linkToNightly(hash, date), '$downloads/$hash@${Math.floor(Date.now().getTime())}').next(function (dir) {
          replace(versionDir(hash), dir, hash, function (dir) {
            '$dir/$VERSION_INFO'.saveContent(haxe.Json.stringify({
              published: date.toString(),
            }));
          });
          return true;
        });
        
      case ROfficial(version):
        
        var url = linkToOfficial(version),
            tmp = '$downloads/$version@${Math.floor(Date.now().getTime())}';
            
        var ret = download(url, tmp);
          
        ret.next(function (v) {
          replace(versionDir(version), v, version);
          return true;
        });
    }  
  }

  static public function ensureNeko(echo:String->Void):Promise<String> {

    var neko = Neko.PATH;

    return
      if (neko.exists()) 
        neko;
      else {
        
        echo('Neko seems to be missing. Attempting download ...');

        (switch Sys.systemName() {
          case 'Windows': Download.zip('https://github.com/HaxeFoundation/neko/releases/download/v2-2-0/neko-2.2.0-win.zip', 1, neko, true);
          case 'Mac': Download.tar('https://github.com/HaxeFoundation/neko/releases/download/v2-2-0/neko-2.2.0-osx64.tar.gz', 1, neko, true);
          default: Download.tar('https://github.com/HaxeFoundation/neko/releases/download/v2-2-0/neko-2.2.0-linux64.tar.gz', 1, neko, true);
        }).next(function (x) {
          echo('done');
          return x;
        });
      }
  }  
  
}
