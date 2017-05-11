package lix.client.sources;

class Git {
  
  var github:GitHub;
  var gitlab:GitLab;

  public function schemes() return ['git'];

  public function new(github, gitlab) {
    this.github = github;
    this.gitlab = gitlab;
  }
    
  public function processUrl(url:Url):Promise<ArchiveJob> 
    return 
      switch url.payload {
        case gh if (gh.startsWith('https://github.com')):
          github.processUrl(switch url.payload {
            case v if (v.endsWith('.git')): v.substr(0, v.length - 4);
            case v: v;
          });
        case gl if (gl.startsWith('https://gitlab.com')):
          gitlab.processUrl(switch url.payload {
            case v if (v.endsWith('.git')): v.substr(0, v.length - 4);
            case v: v;
          });
        default:
          new Error('not implemented');
      }
    
}