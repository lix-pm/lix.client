package lix.client.sources;

class GitLab {

  public function schemes()
    return ['gitlab'];

  var privateToken:String;
  public function new(?privateToken:String = '') {
    this.privateToken = switch privateToken.trim() {
      case '': '';
      case v: 'private_token=$v';
    }
  }
  
  public function grabCommit(owner, project, version)
    return Download.text('https://gitlab.com/api/v4/projects/$owner%2F$project/repository/commits/$version?$privateToken')
      .next(function (s)          
        try {
          var parsed:Dynamic = s.parse();
          if(version == '') parsed = parsed[0];
          return(parsed.id:String);
        } catch (e:Dynamic) {
          var s = switch version {
            case null | '': '';
            case v: '#$v';
          }
          
          return new Error('Failed to lookup sha for gitlab:$owner/$project$s');
        }
      );
  
  public function getArchive(owner:String, project:String, ?commitish:String):Promise<ArchiveJob> 
    return switch commitish {
      case null: 
        grabCommit(owner, project, '').next(getArchive.bind(owner, project, _));
      case sha if (sha.length == 40):
        return ({
          normalized: 'https://gitlab.com/$owner/$project/repository/archive.tar.gz?ref=$sha&${privateToken}',
          dest: Computed(function (l) return [l.name, l.version, 'gitlab', sha]),
          url: 'https://gitlab.com/$owner/$project/repository/archive.tar.gz?ref=$sha&${privateToken}',
          lib: { name: Some(project), version: None }, 
        } : ArchiveJob);
      case v:
        grabCommit(owner, project, v).next(getArchive.bind(owner, project, _));
    }
    
  public function processUrl(url:Url):Promise<ArchiveJob> 
    return switch url.path {
      case null: new Error('invalid gitlab url $url');
      case _.parts() => [owner, project]: getArchive(owner, project, url.hash);
      default: new Error('invalid gitlab url $url');
    }
}