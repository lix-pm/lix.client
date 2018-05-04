package lix.client.sources;

import tink.url.Auth;

@:tink class GitHub {

  public function schemes()
    return ['github', 'gh'];

  var credentials:Auth;
  public function new(?credentials) 
    this.credentials = credentials;
  
  public function grabCommit(owner, project, version) 
    return Download.text('https://${credentials}api.github.com/repos/$owner/$project/commits?sha=$version')
      .next(function (s)          
        try 
          return(s.parse()[0].sha:String)
        catch (e:Dynamic) {
          var s = switch version {
            case null | '': '';
            case v: '#$v';
          }
          
          return new Error('Failed to lookup sha for github:$owner/$project$s');
        }
      );
  
  public function getArchive(owner:String, project:String, ?commitish:String, ?credentials:Auth):Promise<ArchiveJob> {
    function doGet(sha)
      return getArchive(owner, project, sha, credentials);
    return switch commitish {
      case null: 
        grabCommit(owner, project, '').next(doGet);
      case sha if (sha.length == 40):
        trace('gh://${credentials}github.com/$owner/$project#$sha');
        return ({
          normalized: 'gh://${credentials}github.com/$owner/$project#$sha',
          dest: Computed(function (l) return [l.name, l.version, 'github', sha]),
          url: 'https://${credentials}github.com/$owner/$project/archive/$sha.tar.gz',
          lib: { name: Some(project), version: None }, 
        } : ArchiveJob);
      case v:
        grabCommit(owner, project, v).next(doGet);
    }
  }
    
  public function processUrl(url:Url):Promise<ArchiveJob> 
    return switch url.path {
      case null: new Error('invalid github url $url');
      case _.parts().toStringArray() => [owner, project]: 
        getArchive(owner, project, url.hash, url.auth);
      default: new Error('invalid github url $url');
    }
}