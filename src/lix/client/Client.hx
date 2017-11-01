package lix.client;

import lix.client.sources.*;
import haxe.DynamicAccess;
import lix.client.Archives;
import lix.api.Api;

using sys.FileSystem;
using sys.io.File;

using haxe.Json;

@:tink class Client {
  
  public var scope(default, null):Scope = _;
  
  var urlToJob:Url->Promise<ArchiveJob> = _;
  var resolver:Array<Dependency>->Promise<Array<ArchiveJob>> = _;

  public var log(default, null):String->Void = _;
  public var force(default, null):Bool = _;
  public var silent(default, null):Bool = _;
  
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
              cacheFile = '${scope.libCache}/.cache/libNames/${DownloadedArchive.escape(a.url)}';
              if (cacheFile.exists()) 
                into = cacheFile.getContent();
          }
        
        var exists = into != null && '${scope.libCache}/$into'.exists();
        return 
          if (exists && !force) {
            log('already downloaded: ${a.normalized}');
            DownloadedArchive.existent(into, scope.libCache, a);
          }
          else {
            log('${if (exists) "forcedly redownloading" else "downloading"} ${a.normalized}');
            (switch a.kind {
              case null: Download.archive;
              case Zip: Download.zip;
              case Tar: Download.tar;
            })(a.url, 0, scope.haxeshimRoot + '/downloads/download@' + Date.now().getTime(), !silent)
              .next(dir => {
                var ret = DownloadedArchive.fresh(dir, scope.libCache, into, a);

                if (cacheFile != null) {
                  Fs.ensureDir(cacheFile);
                  cacheFile.saveContent(ret.relRoot);
                }

                return ret;
              });
          }
      }
    );     

  public function installMany(projects:Array<Dependency>):Promise<Noise>
    return resolver(projects).next(function (jobs) {
      return Promise.inSequence([for (j in jobs) installArchive(j)]).noise();
    });

  public function install(lib:ProjectName, ?constraint:Constraint):Promise<Noise>
    return installMany([{ name: lib, constraint: constraint }]);

  public function installUrl(url:Url, ?as:LibVersion):Promise<Noise> 
    return installArchive(urlToJob(url), as, true);
    
  public function installArchive(a:Promise<ArchiveJob>, ?as:LibVersion, ?withHaxeLibDependencies:Bool):Promise<Noise> 
    return downloadArchive(a).next(function (a) {
      var extra =
        switch '${a.absRoot}/extraParams.hxml' {
          case found if (found.exists()):
            found.getContent();
          default: '';
        }
      
      if (as == null)
        as = { name: None, version: None };

      var infos:ArchiveInfos = a.infos;
      
      var name = as.name.or(infos.name),
          version = as.version.or(infos.version);

      if (name == null)
        return new Error('Could not determine library name for ${a.job.normalized}');

      var hxml = Resolver.libHxml(scope.scopeLibDir, name);
      
      Fs.ensureDir(hxml);

      log('mounting as $name#$version');  
      
      var haxelibs:DynamicAccess<String> = null;

      var deps = 
        switch '${a.absRoot}/haxelib.json' {
          case found if (found.exists()):
            haxelibs = found.getContent().parse().dependencies;
            [for (name in haxelibs.keys()) '-lib $name'];
          default: [];
        }
      
      hxml.saveContent([
        '# @install: lix --silent download "${a.job.normalized}" into ${a.relRoot}',
        '-D $name=$version',
        '-cp $${HAXESHIM_LIBCACHE}/${a.relRoot}/${infos.classPath}',
        extra,
      ].concat(deps).join('\n'));
      
      return 
        switch haxelibs {
          case null: Noise;
          default:
            Haxelib.installDependencies(haxelibs, this, function (s) return '${scope.scopeLibDir}/$s.hxml'.exists());
        }
    });
  
}