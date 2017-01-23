package lix.client.sources;

class Web {

  static public function getArchive(url:Url):Promise<ArchiveJob> 
    return ({
      url: url,
      lib: { name: None, versionNumber: None, versionId: None },
    } : ArchiveJob);

}