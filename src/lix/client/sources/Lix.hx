package lix.client.sources;

import tink.http.clients.*;

using tink.CoreApi;

class Lix {
  public function new() {}
  
  public function schemes():Array<String>
    return ['lix'];

  public function processUrl(url:Url):Promise<ArchiveJob> {
    return switch url.path {
      case null: new Error('invalid lix url $url');
      case _.parts().toStringArray() => [owner, project]: 
        getArchive(owner, project, url.hash);
      default: new Error('invalid lix url $url');
    }
    return new Error('todo');
  }
  
  function getArchive(owner:String, name:String, ?version:String):Promise<ArchiveJob> {
    var remote = new lix.Remote(#if (environment == "local") new NodeClient() #else new SecureNodeClient() #end);
    var versions = remote.owners().byName(owner).projects().byName(name).versions();
    var api = version == null ? versions.latest() : versions.byVersion(version);
    
    return (api.get() && api.download())
      .next(o -> {
          ({
            url: o.b.url,
            normalized: Url.make({
              scheme: 'lix',
              path: '$owner/$name',
              hash: o.a.version,
            }),
            dest: Fixed([name, o.a.version, 'lix', owner]),
            kind: Zip,
            lib: { name: Some(name), version: Some(o.a.version) }
          } : ArchiveJob);
      });
  }
}