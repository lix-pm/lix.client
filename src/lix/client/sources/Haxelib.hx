package lix.client.sources;

import tink.url.Host;

using tink.CoreApi;

private class Proxy extends haxe.remoting.AsyncProxy<lix.client.sources.haxelib.Repo> {}

@:tink class Haxelib {
  static var OFFICIAL = 'https://lib.haxe.org/';
  
  @:lazy var isOfficial:Bool = OFFICIAL == baseURL;
  var baseURL:String = @byDefault OFFICIAL;

  function getBaseUrl(?options:{ host: tink.url.Host }):Url
    return switch options {
      case null | { host: null }: baseURL;
      case { host: h }: '${if (h.port == null) 'https' else 'http'}://$h/';
    }

  function resolve(url, ?options:{ host: tink.url.Host }):Url 
    return getBaseUrl(options).resolve(url);

  public function schemes():Array<String>
    return ['haxelib'];

  public function processUrl(url:Url):Promise<ArchiveJob> 
    return switch url.path {
      case null: new Error('invalid haxelib url $url');
      case _.parts().toStringArray() => [v]: getArchive(v, url.hash, { host: url.host });
      default: new Error('invalid haxelib url $url');
    }
  

  function getArchive(name:String, ?version:String, ?options):Promise<ArchiveJob>
    return 
      switch version {
        case null:
          resolveVersion(name, options).next(getArchive.bind(name, _, options));
        case v:
          var host = switch options {
            case null | { host: null }: None;
            case { host: h }: Some(h);
          }
          
          var isCustom = !(host == None && isOfficial);

          ({
            url: resolve('/p/$name/$version/download/', options),
            normalized: Url.make({
              scheme: 'haxelib',
              host: host.orNull(),
              path: '/$name',
              hash: version,
              query: if (isCustom) { url : baseURL } else null,
            }),
            dest: Fixed([name, version, 'haxelib' + if (isCustom) '@' + getBaseUrl(options).urlEncode() else '']),
            kind: Zip,
            lib: { name: Some(name), version: Some(version) }
          } : ArchiveJob);
      }

  function resolveVersion(name:String, ?options):Promise<String> 
    return Future.async(function (cb) {
      var cnx = haxe.remoting.HttpAsyncConnection.urlConnect(resolve('/api/3.0/index.n', options));
      cnx.setErrorHandler(function (e) cb(Failure(Error.withData('Failed to get version information from haxelib because $e', e))));  
      var repo = new Proxy(cnx.api);
      repo.getLatestVersion(name, function (s) cb(Success(s)));
    });

}