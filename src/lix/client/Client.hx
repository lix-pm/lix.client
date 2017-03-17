package lix.client;

import lix.client.sources.*;
import haxe.DynamicAccess;
import lix.client.Archives;
import lix.api.Api;

using sys.FileSystem;
using sys.io.File;

using haxe.Json;

class Client {
  
  public var scope(default, null):Scope;
  
  var resolver:Array<Dependency>->Promise<Array<ArchiveJob>>;
  var urlToJob:Url->Promise<ArchiveJob>;
  
  public var log(default, null):String->Void;

  public function new(scope, urlToJob, resolver, log) {
    this.scope = scope;
    this.urlToJob = urlToJob;
    this.resolver = resolver;
    this.log = log;
  }
  
  public function downloadUrl(url:Url, ?into:String) 
    return downloadArchive(urlToJob(url), into);
    
  public function downloadArchive(a:Promise<ArchiveJob>, ?into:String):Promise<DownloadedArchive>
    return a.next(
      function (a) {
        log('downloading ${a.normalized}');
        return (switch a.kind {
          case null: Download.archive;
          case Zip: Download.zip;
          case Tar: Download.tar;
        })(a.url, 0, scope.haxeshimRoot + '/downloads/download@'+Date.now().getTime()).next(function (dir:String) {
          return new DownloadedArchive(dir, scope.libCache, a);
        });
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
        '# @install: lix download ${a.job.normalized} into ${a.relRoot}',
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