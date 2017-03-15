package lix.client.sources;

class Web {
  static public function schemes() 
    return ['http', 'https'];

  static public function processUrl(url:Url):Promise<ArchiveJob> 
    return ({
      url: url,
      dest: None,
      normalized: url,
      lib: { name: None, version: None },
    } : ArchiveJob);

}