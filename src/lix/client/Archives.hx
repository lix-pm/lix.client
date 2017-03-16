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

typedef ArchiveJob = {
  
  var normalized(default, null):Url;
  var url(default, null):Url;
  var lib(default, null):LibVersion;
  var dest(default, null):Option<Array<String>>;

  @:optional var kind(default, null):Null<ArchiveKind>;
}

@:structInit class ArchiveInfos {
  public var name(default, null):String;
  public var version(default, null):String;
  public var classPath(default, null):String;
}

class DownloadedArchive {
  
  /**
   * The job the archive originated from
   */
  public var job(default, null):ArchiveJob;

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

  static function escape(s:String) {
    for (i in 0...RESERVED.length)
      s = s.replace(RESERVED.charAt(i), '_');
    return s;
  }
    
  public var infos(default, null):ArchiveInfos;
  
  public function new(tmpLoc:String, storageRoot:String, job:ArchiveJob) {
    
    this.storageRoot = storageRoot;

    var curRoot = '$tmpLoc/${seekRoot(tmpLoc)}';

    this.job = job;
    this.infos = readInfos(curRoot, job.lib);


    this.relRoot = [for (part in job.dest.or(["$NAME", "$VERSION", job.normalized.toString()])) switch part {
      case "$NAME":
        if (infos.name == null) continue;
        infos.name;
      case "$VERSION":
        if (infos.version == null) continue;
        infos.version;
      case v: v;
    }].map(escape).join('/');
    
    trace(relRoot);

    var archive = null;
    if (absRoot.exists())
      absRoot.rename(archive = '$absRoot-archived@${Date.now().getTime()}');
      
    Fs.ensureDir(absRoot);  
    curRoot.rename(absRoot);
    
    if (archive != null)
      Fs.delete(archive);

    if (tmpLoc.exists())
      Fs.delete(tmpLoc);
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

    function name(found:String)
      return lib.name.or(found);

    function version(found:String)
      return lib.version.or(found);


    return 
      if (files.indexOf('haxelib.json') != -1) {
        //TODO: there's a lot of errors to be caught here
        var info:{ name: String, version:String, ?classPath:String } = '$root/haxelib.json'.getContent().parse();
        {
          name: name(info.name),
          version: version(info.version),
          classPath: switch info.classPath {
            case null: '';
            case v: v;
          },
        }
      }
      else if (files.indexOf('package.json') != -1) {
        var info:{ name: String, version:String, } = '$root/package.json'.getContent().parse();
        {
          name: name(info.name),
          version: version(info.version),
          classPath: guessClassPath(),
        }
      }
      else {        
        {
          name: name(null),
          version: version('0.0.0'),
          classPath: guessClassPath(),
        }
      }
  }    
}