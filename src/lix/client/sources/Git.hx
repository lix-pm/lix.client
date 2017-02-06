package lix.client.sources;

class Git {
  
  var github:GitHub;

  public function new(github) {
    this.github = github;
  }
    
  public function processUrl(url:Url):Promise<ArchiveJob> 
    return 
      switch url.payload {
        case gh if (gh.startsWith('https://github.com')):
          github.processUrl(switch url.payload {
            case v if (v.endsWith('.git')): v.substr(0, v.length - 4);
            case v: v;
          });
        default:
          new Error('not implemented');
      }
    
}