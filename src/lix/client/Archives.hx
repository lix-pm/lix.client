package lix.client;

import haxe.crypto.Md5;

using haxe.io.Path;

using sys.FileSystem;
using sys.io.File;
using haxe.Json;

enum ArchiveKind {
  Zip;
  Tar;
}

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

@:structInit class ArchiveInfos {
  public var name(default, null):String;
  public var version(default, null):String;
  public var classPath(default, null):String;
  @:optional public var runAs(default, null):String;
  @:optional public var postDownload(default, null):String;
  @:optional public var postInstall(default, null):String;
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
    var infos = readInfos(curRoot, job.lib);
    
    var relRoot = 
      if (targetLoc == null) 
        path(switch job.dest {
          case Fixed(path): path;
          case Computed(f): f(infos);
        });
      else targetLoc;
    
    var ret = new DownloadedArchive(relRoot, storageRoot, job, infos);
    ret.alreadyDownloaded = false;

    var archive = null;

    switch ret.absRoot {
      case old if (old.exists()):
        old.rename(archive = '$old-archived@${Date.now().getTime()}');
      default:
    }
      
    Fs.ensureDir(ret.absRoot);  
    curRoot.rename(ret.absRoot);
    
    if (archive != null)
      Fs.delete(archive);

    if (tmpLoc.exists())
      Fs.delete(tmpLoc);
    return ret;
  }

  static public function existent(path:String, storageRoot:String, job:ArchiveJob) {
    return new DownloadedArchive(path, storageRoot, job);
  }

  function new(relRoot:String, storageRoot:String, job:ArchiveJob, ?infos) {
    
    this.storageRoot = storageRoot;
    this.relRoot = relRoot;
    
    this.job = job;
    this.infos = switch infos {
      case null: readInfos(absRoot, job.lib); 
      case v: v;
    }
  }
  
  static function seekRoot(path:String) 
    return switch path.readDirectory() {
      case [v] if ('$path/$v'.isDirectory()):
        '$v/' + seekRoot('$path/$v');
      default:
        '';
    }
  
  static function readInfos(root:String, lib:LibVersion):ArchiveInfos {
    
    var files = root.readDirectory();
    
    function guessClassPath() 
      return 
        if (files.indexOf('src') != -1) 'src';
        else if (files.indexOf('hx') != -1) 'hx';
        else '';

    if (lib == null)
      lib = LibVersion.UNDEFINED;

    return 
      if (files.indexOf('haxelib.json') != -1) {
        //TODO: there's a lot of errors to be caught here
        var info:{ 
          name: String, 
          version:String, 
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
          runAs: 
            if (files.indexOf('run.n') != -1 || info.mainClass != null) "haxelib run-dir ${DOWNLOAD_LOCATION}"
            else null,
          postInstall: info.postInstall,
          postDownload: info.postDownload,
        }
      }
      else if (files.indexOf('package.json') != -1) {
        var info:{ name: String, version:String, } = '$root/package.json'.getContent().parse();
        {
          name: info.name,
          version: info.version,
          classPath: guessClassPath(),
        }
      }
      else {        
        {
          name: lib.name.orNull(),
          version: lib.version.or('0.0.0'),
          classPath: guessClassPath(),
        }
      }
  }    
}