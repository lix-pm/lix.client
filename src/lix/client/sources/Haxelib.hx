package lix.client.sources;

private class Proxy extends haxe.remoting.AsyncProxy<lix.client.sources.haxelib.Repo> {}

class Haxelib {
  static var SERVER = 'lib.haxe.org';
  static public function schemes():Array<String>
    return ['haxelib'];

  static public function processUrl(url:Url):Promise<ArchiveJob> 
    return switch url.path {
      case null: new Error('invalid haxelib url $url');
      case _.parts() => [v]: getArchive(v, url.hash, { server: url.host });
      default: new Error('invalid haxelib url $url');
    }
  
  static public function getArchive(name:String, ?version:String, ?options):Promise<ArchiveJob>
    return 
      switch version {
        case null:
          resolveVersion(name, options).next(getArchive.bind(name, _));
        case v:
          ({
            url: '$SERVER/p/$name/$version/download/',
            normalized: 'haxelib:$name#$version',
            dest: Fixed([name, version, 'haxelib']),
            kind: Zip,
            lib: { name: Some(name), version: Some(version) }
          } : ArchiveJob);
      }    
      
  static public function resolveVersion(name:String, ?options:{ server: String }):Promise<String> {
    return Future.async(function (cb) {
      var server = switch options {
        case null | { server: null }: SERVER;
        case { server: v }: v; 
      };
      
      var cnx = haxe.remoting.HttpAsyncConnection.urlConnect('https://$server/api/3.0/index.n');
      cnx.setErrorHandler(function (e) cb(Failure(Error.withData('Failed to get version information from haxelib because $e', e))));  
      var repo = new Proxy(cnx.api);
      repo.getLatestVersion(name, function (s) cb(Success(s)));
    });
    
    return Download.text('$SERVER/p/$name').next(function (s) return s.split(')</title>')[0].split('(').pop());
  }

  static public function installDependencies(haxelibs:haxe.DynamicAccess<String>, client:Client, skip:String->Bool) {
    
    var ret:Array<Promise<Noise>> = [
      for (name in haxelibs.keys()) Future.async(function (cb) {
        if (skip(name)) {
          cb(Success(Noise));
          return;
        }
        var version:Url = haxelibs[name];
        client.log('Installing dependency $name');
        (switch version.scheme {
          case null:
            client.installArchive(Haxelib.getArchive(name, switch version.payload {
              case '' | '*': null;
              case v: v;
            }), true);
          case v:
            client.installUrl(version, { name: Some(name), version: None });
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