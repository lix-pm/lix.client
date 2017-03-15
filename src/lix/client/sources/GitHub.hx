package lix.client.sources;

class GitHub {

  public function schemes()
    return ['github', 'gh'];

  var credentials:String;
  public function new(?credentials:String = '') {
    this.credentials = switch credentials.trim() {
      case '': '';
      case v: '$v@';
    }
  }
  
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
  
  public function getArchive(owner:String, project:String, ?commitish:String):Promise<ArchiveJob> 
    return switch commitish {
      case null: 
        grabCommit(owner, project, '').next(getArchive.bind(owner, project, _));
      case sha if (sha.length == 40):
        return ({
          normalized: 'github:$owner/$project#$sha',
          url: 'https://${credentials}github.com/$owner/$project/archive/$sha.tar.gz',
          lib: { name: Some(project), versionNumber: None, versionId: Some(sha) }, 
        } : ArchiveJob);
      case v:
        grabCommit(owner, project, v).next(getArchive.bind(owner, project, _));
    }
    
  public function processUrl(url:Url):Promise<ArchiveJob> 
    return switch url.path {
      case null: new Error('invalid github url $url');
      case _.parts() => [owner, project]: getArchive(owner, project, url.hash);
      default: new Error('invalid github url $url');
    }
}