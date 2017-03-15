package lix.client.sources;

class Web {
  static public function schemes() 
    return ['http', 'https'];

  static public function processUrl(url:Url):Promise<ArchiveJob> 
    return ({
      url: url,
      normalized: url,
      lib: { name: None, versionNumber: None, versionId: None },
    } : ArchiveJob);

}