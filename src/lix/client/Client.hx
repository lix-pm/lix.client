package lix.client;

import lix.client.sources.*;
import haxe.DynamicAccess;
import lix.client.Archives;

using sys.FileSystem;
using sys.io.File;

using haxe.Json;

class Client {
  
  public var scope(default, null):Scope;
  
  var urlToJob:Url->Promise<ArchiveJob>;

  public function new(scope, urlToJob) {
    this.scope = scope;
    this.urlToJob = urlToJob;
  }
  
  static public function downloadArchiveInto(?kind:ArchiveKind, url:Url, tmpLoc:String):Promise<DownloadedArchive> 
    return (switch kind {
      case null: Download.archive(url, 0, tmpLoc);
      case Zip: Download.zip(url, 0, tmpLoc);
      case Tar: Download.tar(url, 0, tmpLoc);
    }).next(function (dir:String) {
      return new DownloadedArchive(url, dir);
    });

  public function downloadUrl(url:Url, ?as:LibVersion) 
    return download(urlToJob(url), as);
    
  public function download(a:Promise<ArchiveJob>, ?as:LibVersion) 
    return a.next(
      function (a) return downloadArchiveInto(a.kind, a.url, scope.haxeshimRoot + '/downloads/download@'+Date.now().getTime()).next(function (res) {
        return res.saveAs(scope.libCache, a.lib.merge(as));
      })      
    );

  public function installUrl(url:Url, ?as:LibVersion)
    return install(urlToJob(url), as);
    
  public function install(a:Promise<ArchiveJob>, ?as:LibVersion):Promise<Noise> 
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
      
      var haxelibs:DynamicAccess<String> = null;

      var deps = 
        switch '${a.absRoot}/haxelib.json' {
          case found if (found.exists()):
            haxelibs = found.getContent().parse().dependencies;
            [for (name in haxelibs.keys()) '-lib $name'];
          default: [];
        }
      
      hxml.saveContent([
        '# @install: lix download ${a.source.toString()} $target',
        '-D ${a.infos.name}=${a.infos.version}',
        '-cp $${HAXESHIM_LIBCACHE}/${a.relRoot}/${a.infos.classPath}',
        extra,
      ].concat(deps).join('\n'));
      
      if (haxelibs == null)
        return Noise;

      for (file in scope.scopeLibDir.readDirectory())
        if (file.endsWith('.hxml')) 
          haxelibs.remove(file.substr(0, file.length - 5));
      
      var ret:Array<Promise<Noise>> = [
        for (name in haxelibs.keys()) {
          var version:Url = haxelibs[name];
          switch version.scheme {
            case null:
              install(Haxelib.getArchive(name, switch version.payload {
                case '' | '*': null;
                case v: v;
              }));
            case v:
              installUrl(version);
          }
        }
      ];

      return Future.ofMany(ret).map(function (results) {

        var errors = [];
        
        for (r in results) switch r {
          case Failure(e):
            errors.push(e);
          default:
        }

        return switch errors {
          case []: 
            Success(Noise);
          case v:
            Failure(Error.withData('Failed to install dependencies:\n  ' + errors.map(function (e) return e.message).join('\n  '), errors));
        }
      });
    });
    
}