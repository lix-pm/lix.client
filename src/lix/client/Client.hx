package lix.client;

import haxe.DynamicAccess;
import lix.client.Archives;

using sys.FileSystem;
using sys.io.File;

using haxe.Json;

class Client {
  
  public var scope(default, null):Scope;
  
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
    
  public function download(a:Promise<ArchiveJob>, ?as:LibVersion) 
    return a.next(
      function (a) return downloadArchiveInto(a.kind, a.url, scope.haxeshimRoot + '/downloads/download@'+Date.now().getTime()).next(function (res) {
        return res.saveAs(scope.libCache, a.lib.merge(as));
      })      
    );
    
  public function install(a:Promise<ArchiveJob>, ?as:LibVersion) 
    return download(a, as).next(function (a) {
      var extra =
        switch '${a.absRoot}/extraParams.hxml' {
          case found if (found.exists()):
            found.getContent();
          default: '';
        }
        
      var hxml = Resolver.libHxml(scope.scopeLibDir, a.infos.name);
      
      Fs.ensureDir(hxml);
      
      var target = switch a.savedAs {
        case Some(v): 'as ' + v.toString();
        case None: '';
      }
      
      var deps = 
        switch '${a.absRoot}/haxelib.json' {
          case found if (found.exists()):
            var ret:DynamicAccess<String> = found.getContent().parse().dependencies;
            [for (key in ret.keys()) '-lib $key'];
          default: [];
        }
      
      hxml.saveContent([
        '# @install: lix download ${a.source.toString()} $target',
        '-D ${a.infos.name}=${a.infos.version}',
        '-cp $${HAXESHIM_LIBCACHE}/${a.relRoot}/${a.infos.classPath}',
        extra,
      ].concat(deps).join('\n'));
      return Noise;
    });
    
}