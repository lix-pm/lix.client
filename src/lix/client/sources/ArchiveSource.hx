package lix.client.sources;

typedef ArchiveSource = {
  function schemes():Array<String>;
  function processUrl(url:Url):Promise<ArchiveJob>;
}