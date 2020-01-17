package lix.client.sources;

import lix.client.sources.haxelib.*;
import tink.url.Host;

using tink.CoreApi;

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
    return
      switch url.query.toMap()['url'].toString() {
        case _ == null || _ == baseURL => true:
          switch url.path {
            case null: new Error('invalid haxelib url $url');
            case _.parts().toStringArray() => [v]: getArchive(v, url.hash, { host: url.host });
            default: new Error('invalid haxelib url $url');
          }
        case v:
          new Haxelib(v).processUrl(url);
      }

  static inline function esc(s:String)
    return s.replace('.', ',');

  function getArchive(name:String, ?version:String, ?options):Promise<ArchiveJob>
    return
      getInfos(name, options)
        .next(function (infos) {
          var host = switch options {
            case null | { host: null }: None;
            case { host: h }: Some(h);
          }

          var isCustom = !(host == None && isOfficial);
          var name = infos.name;
          if (version == null) {
            function getVersions(?filter) {
              var ret = [for (v in infos.versions) switch tink.semver.Version.parse(v.name) {
                case Success(v) if (filter == null || filter(v)): v;
                default: continue;
              }];
              ret.sort((a, b) -> b.compare(a));
              return ret;
            }

            version =
              switch getVersions(v -> v.preview == null) {
                case []:
                  getVersions()[0];
                case v: v[0];
              }
          }
          else {
            var found = false;
            for (v in infos.versions)
              if (v.name == version) {
                found = true;
                break;
              }
            if (!found)
              return new Error('Library $name has no version $version');
          }
          return ({
            url: resolve('/files/3.0/${esc(name)}-${esc(version)}.zip', options),
            normalized: Url.make({
              scheme: 'haxelib',
              host: host.orNull(),
              path: '/$name',
              hash: version,
              query: if (isCustom) { url : baseURL } else null,
            }),
            dest: Fixed([name, version, 'haxelib' + if (isCustom) '@' + getBaseUrl(options).toString().urlEncode() else '']),
            kind: Zip,
            lib: { name: Some(name), version: Some(version) }
          } : ArchiveJob);
        }
      );

  function getInfos(name:String, ?options):Promise<ProjectInfos>
    return Future.async(function (cb) {
      var cnx = haxe.remoting.HttpAsyncConnection.urlConnect(resolve('/api/3.0/index.n', options));
      cnx.setErrorHandler(function (e) cb(Failure(Error.withData('Failed to get version information from haxelib because $e', e))));
      var repo = new Proxy(cnx.resolve('api'));
      repo.infos(name, function (s) cb(Success(s)));
    });

}