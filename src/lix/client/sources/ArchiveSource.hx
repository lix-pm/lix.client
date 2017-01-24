package lix.client.sources;

typedef ArchiveSource = {
  function processUrl(url:Url):Promise<ArchiveJob>;
}