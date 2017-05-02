package lix.client.sources;

class Haxelib {
  static public function schemes():Array<String>
    return ['haxelib'];

  static public function processUrl(url:Url):Promise<ArchiveJob> 
    return switch url.path {
      case null: new Error('invalid haxelib url $url');
      case _.parts() => [v]: getArchive(v, url.hash);
      default: new Error('invalid haxelib url $url');
    }
  
  static public function getArchive(name:String, ?version:String):Promise<ArchiveJob>
    return 
      switch version {
        case null:
          resolveVersion(name).next(getArchive.bind(name, _));
        case v:
          ({
            url: 'https://lib.haxe.org/p/$name/$version/download/',
            normalized: 'haxelib:$name#$version',
            dest: Fixed([name, version, 'haxelib']),
            kind: Zip,
            lib: { name: Some(name), version: Some(version) }
          } : ArchiveJob);
      }    
      
  static public function resolveVersion(name:String):Promise<String> 
    return Download.text('https://lib.haxe.org/p/$name').next(function (s) return s.split(')</title>')[0].split('(').pop());

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
        }).handle(cb);
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