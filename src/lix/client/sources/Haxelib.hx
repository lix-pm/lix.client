package lix.client.sources;

private class Proxy extends haxe.remoting.AsyncProxy<lix.client.sources.haxelib.Repo> {}

class Haxelib {
  static var HOST = 'lib.haxe.org';
  static public function schemes():Array<String>
    return ['haxelib'];

  static public function processUrl(url:Url):Promise<ArchiveJob> 
    return switch url.path {
      case null: new Error('invalid haxelib url $url');
      case _.parts() => [v]: getArchive(v, url.hash, { host: url.host });
      default: new Error('invalid haxelib url $url');
    }
  
  static public function getArchive(name:String, ?version:String, ?options):Promise<ArchiveJob>
    return 
      switch version {
        case null:
          resolveVersion(name, options).next(getArchive.bind(name, _, options));
        case v:
          ({
            url: 'https://$HOST/p/$name/$version/download/',
            normalized: 
              if (options != null && options.host != null) 'haxelib://${options.host}/$name#$version'
              else 'haxelib:$name#$version',
            dest: Fixed([name, version, 'haxelib']),
            kind: Zip,
            lib: { name: Some(name), version: Some(version) }
          } : ArchiveJob);
      }    

  static function getHost(?options:{ host: String })
    return switch options {
      case null | { host: null }: HOST;
      case { host: v }: v; 
    };

  static public function resolveVersion(name:String, ?options:{ host: String }):Promise<String> 
    return Future.async(function (cb) {
      var cnx = haxe.remoting.HttpAsyncConnection.urlConnect('https://${getHost(options)}/api/3.0/index.n');
      cnx.setErrorHandler(function (e) cb(Failure(Error.withData('Failed to get version information from haxelib because $e', e))));  
      var repo = new Proxy(cnx.api);
      repo.getLatestVersion(name, function (s) cb(Success(s)));
    });

  static public function installDependencies(haxelibs:haxe.DynamicAccess<String>, libs:Libraries, skip:String->Bool) {
    
    var ret:Array<Promise<Noise>> = [
      for (name in haxelibs.keys()) Future.async(function (cb) {
        if (skip(name)) {
          cb(Success(Noise));
          return;
        }
        var version:Url = haxelibs[name];
        libs.log('Installing dependency $name');
        (switch version.scheme {
          case null:
            libs.installArchive(Haxelib.getArchive(name, switch version.payload {
              case '' | '*': null;
              case v: v;
            }), true);
          case v:
            libs.installUrl(version, { name: Some(name), version: None });
        }).handle(function (o) cb(switch o {
          case Failure(e):
            Failure(Error.withData(e.code, '$name: ${e.message}', e.data));
          default: o;
        }));
      }, true)
    ];

    return Future.ofMany(ret).map(function (results) {

      var errors = [];
      
      for (r in results) switch r {
        case Failure(e):
          errors.push(e);
        default:
      }

      return switch errors {
        case []: 
          Success(Noise);
        case v:
          Failure(Error.withData('Failed to install dependencies:\n  ' + errors.map(function (e) return e.message).join('\n  '), errors));
      }
    });    
  }

}