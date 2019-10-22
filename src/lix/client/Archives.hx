package lix.client;

using haxe.io.Path;

using sys.FileSystem;
using sys.io.File;
using haxe.Json;

enum ArchiveKind {
  Zip;
  Tar;
  Custom(load:CustomLoader);
}

typedef CustomLoader = CustomLoaderContext->Promise<String>;
typedef CustomLoaderContext = { source:Url, dest:String, logger:Logger, scope:Scope };

enum ArchiveDestination {
  Fixed(path:Array<String>);
  Computed(f:ArchiveInfos->Array<String>);
}

typedef ArchiveJob = {

  var normalized(default, null):Url;
  var url(default, null):Url;
  var lib(default, null):LibVersion;
  var dest(default, null):ArchiveDestination;

  @:optional var kind(default, null):Null<ArchiveKind>;
}

enum ArchiveDependency {
  FromUrl(u:Url);
  FromHxml(path:String);
}

typedef HxmlPath = String;

@:structInit class ArchiveInfos {
  public var name(default, null):String;
  public var version(default, null):String;
  public var classPath(default, null):String;
  public var runAs(default, null):{ libRoot: String }->Option<String>;
  public var dependencies(default, null):ArchiveDependencies;
  public var haxeshimDependencies(default, null):HaxeshimDependencies;
  @:optional public var postDownload(default, null):String;
  @:optional public var postInstall(default, null):String;
}


abstract HaxeshimDependencies(Null<Map<String, HxmlPath>>) from Map<String, HxmlPath> {
  @:arrayAccess public inline function get(libName:String):Null<HxmlPath>
    return switch this {
      case null: null;
      case v: v[libName];
    }

  public function keyValueIterator()
    return switch this {
      case null: [].iterator();
      case v: v.keyValueIterator();
    }
}

@:forward(iterator)
abstract ArchiveDependencies(Array<Named<ArchiveDependency>>) {
  inline function new(deps) {
    this = deps;
    this.sort((a, b) -> Reflect.compare(a.name, b.name));
  }

  @:from static function ofHaxeshim(d:HaxeshimDependencies)
    return new ArchiveDependencies([for (lib => hxml in d) new Named(lib, FromHxml(hxml))]);

  @:from static function ofMap(m:Map<String, ArchiveDependency>) 
    return new ArchiveDependencies([for (lib => dep in m) new Named(lib, dep)]);
}

class DownloadedArchive {
  
  /**
   * The job the archive originated from
   */
  public var job(default, null):ArchiveJob;

  public var alreadyDownloaded(default, null):Bool = true;

  var storageRoot:String;

  /**
   * The root directory of this archive, relative to the library cache
   */
  public var relRoot(default, null):String;
  /**
   * The absolute path to the root of the downloaded archive
   */
  public var absRoot(get, never):String;
    inline function get_absRoot()
      return getAbsRoot(storageRoot, relRoot);
     
  static function getAbsRoot(storageRoot, relRoot)
    return '$storageRoot/$relRoot'.removeTrailingSlashes();

  static var RESERVED = "!#$&'()*+,/:;=?@[]";

  static public function escape(s:String) {
    if (s == null) return null;
    for (i in 0...RESERVED.length)
      s = s.replace(RESERVED.charAt(i), '_');
    return s;
  }

  static public function path(parts:Array<String>)
    return parts.map(escape).join('/');
    
  public var infos(default, null):ArchiveInfos;

  static public function fresh(tmpLoc:String, storageRoot:String, targetLoc:String, job:ArchiveJob) {
    var curRoot = '$tmpLoc/${seekRoot(tmpLoc)}';
    return readInfos(curRoot, job.lib)
      .next(infos -> {
        var relRoot = 
          if (targetLoc == null) 
            path(switch job.dest {
              case Fixed(path): path;
              case Computed(f): f(infos);
            });
          else targetLoc;

        var ret = new DownloadedArchive(relRoot, storageRoot, job, infos);
        ret.alreadyDownloaded = false;

        var absRoot = ret.absRoot;
        if (infos.haxeshimDependencies != null) {
          var curRootLength = curRoot.removeTrailingSlashes().length;
          ret.infos = {
            name: infos.name,
            version: infos.version,
            classPath: infos.classPath,
            runAs: infos.runAs,
            dependencies: infos.dependencies,
            haxeshimDependencies:
              [for (dep in infos.dependencies)
                dep.name => absRoot + infos.haxeshimDependencies[dep.name].substr(curRootLength)
              ],
            postDownload: infos.postDownload,
            postInstall: infos.postInstall
          };
        }

        var archive = null,
            old = ret.absRoot;
        return Fs.exists(old)
          .next(exists ->
            if (exists) Fs.move(old, archive = '$old-archived@${Date.now().getTime()}')
            else Noise
          )
          .next(_ -> Fs.move(curRoot, ret.absRoot))
          .next(_ -> Fs.delete(archive))
          .next(_ -> Fs.delete(tmpLoc))
          .swap(ret);
      });
  }

  static public function existent(path:String, storageRoot:String, job:ArchiveJob) 
    return 
      readInfos(getAbsRoot(storageRoot, path), job.lib)
        .next(infos -> new DownloadedArchive(path, storageRoot, job, infos));

  function new(relRoot, storageRoot, job, infos) {
    
    this.storageRoot = storageRoot;
    this.relRoot = relRoot;
    
    this.job = job;
    this.infos = infos;
  }
  
  static function seekRoot(path:String) 
    return switch path.readDirectory() {
      case [v] if ('$path/$v'.isDirectory()):
        '$v/' + seekRoot('$path/$v');
      default:
        '';
    }
  
  static function readInfos(root:String, lib:LibVersion):Promise<ArchiveInfos> {
    
    var files = root.readDirectory();
    
    function guessClassPath() 
      return 
        if (files.indexOf('src') != -1) 'src';
        else if (files.indexOf('hx') != -1) 'hx';
        else '';

    if (lib == null)
      lib = LibVersion.UNDEFINED;

    var haxeshimDependencies:HaxeshimDependencies = 
      if (files.contains('.haxerc') && files.contains('haxe_libraries')) {
        var libs = '$root/haxe_libraries';
        [for (f in libs.readDirectory()) 
          if (f.extension() == 'hxml') 
            f.withoutExtension() => '$libs/$f'
        ];
      }
      else null;

    var ret:ArchiveInfos =  
      if (files.contains('haxelib.json')) {
        //TODO: there's a lot of errors to be caught here
        var info:{ 
          name: String, 
          version:String, 
          ?dependencies:haxe.DynamicAccess<String>,
          ?classPath:String, 
          ?mainClass:String,
          ?postInstall: String, 
          ?postDownload: String, 
        } = '$root/haxelib.json'.getContent().parse();
        
        {
          name: info.name,
          version: info.version,
          classPath: switch info.classPath {
            case null: '';
            case v: v;
          },
          runAs: function (ctx) return 
            if ('${ctx.libRoot}/run.n'.exists() || info.mainClass != null)
              Some('haxelib run-dir ${info.name} $${DOWNLOAD_LOCATION}');
            else 
              None
          ,
          dependencies: switch info.dependencies {
            case null: new Map();//haxeshimDependencies; - maybe the best default
            case deps: 
              [for (name => value in deps) 
                name => FromUrl(
                  switch value {
                    case '' | '*': 'haxelib:$name';
                    case version = (_:Url).scheme => null: 'haxelib:$name#$version';
                    case (_:Url) => { scheme: 'git', payload: (_:Url) => url = { scheme: 'https', host: { name: 'github.com' | 'gitlab.com' }} }:
                      url;
                    case u: u;
                  })
              ]; 
          },
          haxeshimDependencies: haxeshimDependencies,
          postInstall: info.postInstall,
          postDownload: info.postDownload,
        }
      }
      else if (files.contains('package.json')) {
        var info:{ name: String, version:String, } = '$root/package.json'.getContent().parse();
        {
          name: info.name,
          version: info.version,
          classPath: guessClassPath(),
          runAs: function (_) return None,
          dependencies: haxeshimDependencies,
          haxeshimDependencies: null,
        }
      }
      else {        
        {
          name: lib.name.or('untitled'),
          version: lib.version.or('0.0.0'),
          classPath: guessClassPath(),
          runAs: function (_) return None,
          dependencies: haxeshimDependencies,
          haxeshimDependencies: null,
        }
      }
    return ret;
  }    
}