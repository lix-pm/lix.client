package lix.client.sources;

class Web {
  static public function schemes() 
    return ['http', 'https'];

  static public function processUrl(url:Url):Promise<ArchiveJob> {
    var lib = LibVersion.parse(url.hash);
    if (lib != null)
      url = url.toString().split('#')[0];

    return ({
      url: url,
      dest: Computed(function (l) return [l.name, l.version, url]),
      normalized: url,
      lib: lib,
    } : ArchiveJob);
  }
}