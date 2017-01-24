package lix.client.sources;

class Web {

  static public function processUrl(url:Url):Promise<ArchiveJob> 
    return ({
      url: url,
      lib: { name: None, versionNumber: None, versionId: None },
    } : ArchiveJob);

}