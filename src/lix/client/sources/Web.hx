package lix.client.sources;

class Web {
  
  var interceptors:Array<Url->Option<Promise<ArchiveJob>>>;
  public function new(interceptors)
    this.interceptors = interceptors;

  public function schemes() 
    return ['http', 'https'];

  public function processUrl(url:Url):Promise<ArchiveJob> {

    for (i in interceptors)
      switch i(url) {
        case Some(p): return p;
        default:
      }

    return ({
      url: url,
      dest: Computed(function (l) return [l.name, l.version, url]),
      normalized: url,
      lib: null,
    } : ArchiveJob);
  }
}