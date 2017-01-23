package lix.client;
import haxe.crypto.Md5;

using sys.FileSystem;
using sys.io.File;
using haxe.Json;

enum ArchiveKind {
  Zip;
  Tar;
}

typedef ArchiveJob = {
  var url(default, null):Url;
  var lib(default, null):LibVersion;
  @:optional var kind(default, null):Null<ArchiveKind>;
}

class Client {
  
  var scope:Scope;
  
  public function new(scope) {
    this.scope = scope;
  }
  
  static public function downloadArchiveInto(?kind:ArchiveKind, url:Url, tmpLoc:String):Promise<DownloadedArchive> 
    return (switch kind {
      case null: Download.archive(url, 0, tmpLoc);
      case Zip: Download.zip(url, 0, tmpLoc);
      case Tar: Download.tar(url, 0, tmpLoc);
    }).next(function (dir:String) {
      return new DownloadedArchive(url, dir);
    });
    
  public function download(a:Promise<ArchiveJob>) 
    return a.next(
      function (a) return downloadArchiveInto(a.kind, a.url, scope.haxeshimRoot + '/downloads/download@'+Date.now().getTime()).next(function (res) {
        return res.saveAs(scope.libCache, a.lib);
      })
    );
    
  static public function haxelibArchive(name:String, version:String):ArchiveJob
    return {
      url: 'https://lib.haxe.org/p/$name/$version/download/',
      kind: Zip,
      lib: { name: Some(name), versionNumber: Some(version), versionId: Some('haxelib'), }
    };
    
  static function grabGitHubCommit(owner, project, version) 
    return Download.text('https://api.github.com/repos/$owner/$project/commits?sha=$version')
      .next(function (s)          
        try 
          return(s.parse()[0].sha:String)
        catch (e:Dynamic) {
          
          var s = switch version {
            case null | '': '';
            case v: '#$v';
          }
          
          return new Error('Failed to lookup sha for github:$owner/$project#$s');
        }
      );
  
  static public function githubArchive(owner:String, project:String, ?commitish:String):Promise<ArchiveJob> 
    return switch commitish {
      case null: 
        grabGitHubCommit(owner, project, '').next(githubArchive.bind(owner, project, _));
      case sha if (sha.length == 40):
        return ({
          url: 'https://github.com/$owner/$project/archive/$sha.tar.gz',
          lib: { name: Some(project), versionNumber: None, versionId: Some(sha) }, 
        } : ArchiveJob);
      case v:
        grabGitHubCommit(owner, project, v).next(githubArchive.bind(owner, project, _));
    }
    
  //public function downloadFromHaxelib(name:String, version:String) 
    //return 
      //download(haxelibUrl(name, version), , Zip);
  
  //public function downloadFromGithub(repo:String, sha:String)
    //return
      //download('https://github.com/$repo/archive/$sha.tar.gz', {
        //name: None,
        //versionNumber: None,
        //versionId: Some('github:$sha'),
      //});
  //
  //static public function haxelibUrl(name:String, version:String) {
    //return 'https://lib.haxe.org/p/$name/$version/download/';
  //}
      
  //public function resolveHaxelibVersion(name:String):Promise<DownloadJob> {
    //return Download.text('https://lib.haxe.org/p/$name').next(function (s):DownloadJob {
      //return {
        //source: name,
        //version: s.split(')</title>')[0].split('(').pop(),
      //}
    //});
  //}
      
}

@:structInit class ArchiveInfos {
  public var name(default, null):String;
  public var version(default, null):String;
  public var classPath(default, null):String;
}

class DownloadedArchive {
  public var savedAs(default, null):Option<LibVersion> = None;
  
  public function saveAs(storageRoot:String, v:LibVersion):Promise<DownloadedArchive> {
    var name = switch v.name {
      case None:
        switch infos.name {
          case null: return new Error('unable to determine library name of $source');
          case v: v;
        }
      case Some(v):
        v;
    }
    
    var versionNumber = switch v.versionNumber {
      case None: infos.version;
      case Some(v): v;
    }
    
    var versionId = switch v.versionId {
      case None: 'http/'+ Md5.encode(source);
      case Some(v): v;
    }
    
    this.infos = {
      name: name,
      version: versionNumber,
      classPath: infos.classPath,
    }
    
    var path = '$name/$versionNumber/$versionId';
    
    var target = '$storageRoot/$path';
    if (target.exists())
      target.rename('$target-archived@${Date.now().getTime()}');
    Fs.ensureDir(target);  
    absRoot.rename(target);
    location = storageRoot;
    relRoot = path;
    return this;
  }
  /**
   * The url this archive was downloaded from
   */
  public var source(default, null):Url;
  /**
   * The (initially temporary) location this archive was downloaded to
   */
  public var location(default, null):String;
  /**
   * The root directory of this archive, relative to `tmpLoc`
   */
  public var relRoot(default, null):String;
  /**
   * The absolute path to the root of the downloaded archive
   */
  public var absRoot(get, never):String;
    inline function get_absRoot()
      return '$location/$relRoot';
     
  public var infos(default, null):ArchiveInfos;
  
  public function new(source, location) {
    this.source = source;
    this.location = location;
    this.relRoot = seekRoot(location);
    
    this.infos = readInfos(absRoot);
  }
  
  static function seekRoot(path:String) 
    return switch path.readDirectory() {
      case [v] if ('$path/$v'.isDirectory()):
        '$v/' + seekRoot('$path/$v');
      default:
        '';
    }
    
  function readInfos(root:String):ArchiveInfos {
    
    var files = root.readDirectory();
    
    function guessClassPath() 
      return 
        if (files.indexOf('src') != -1) 'src';
        else if (files.indexOf('hx') != -1) 'hx';
        else '';
        
    return 
      if (files.indexOf('haxelib.json') != -1) {
        //TODO: there's a lot of errors to be caught here
        var info:{ name: String, version:String, ?classPath:String } = '$root/haxelib.json'.getContent().parse();
        {
          name: info.name,
          version: info.version,
          classPath: switch info.classPath {
            case null: '';
            case v: v;
          },
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
          name: null,
          version: '0.0.0',
          classPath: guessClassPath(),
        }
      }
  }    
}