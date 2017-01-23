package lix.client;

import lix.client.Archives;

using haxe.Json;

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
    
  public function download(a:Promise<ArchiveJob>, ?as:LibVersion) 
    return a.next(
      function (a) return downloadArchiveInto(a.kind, a.url, scope.haxeshimRoot + '/downloads/download@'+Date.now().getTime()).next(function (res) {
        return res.saveAs(scope.libCache, a.lib.merge(as));
      })      
    );
    
  static public function webArchive(url:Url):ArchiveJob {
    return {
      url: url,
      lib: { name: None, versionNumber: None, versionId: None },
    }
  }
    
  static public function haxelibArchive(name:String, ?version:String):Promise<ArchiveJob>
    return 
      switch version {
        case null:
          resolveHaxelibVersion(name).next(haxelibArchive.bind(name, _));
        case v:
          ({
            url: 'https://lib.haxe.org/p/$name/$version/download/',
            kind: Zip,
            lib: { name: Some(name), versionNumber: Some(version), versionId: Some('haxelib'), }
          } : ArchiveJob);
      }
    
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
      
  static public function resolveHaxelibVersion(name:String):Promise<String> 
    return Download.text('https://lib.haxe.org/p/$name').next(function (s) return s.split(')</title>')[0].split('(').pop());
      
}