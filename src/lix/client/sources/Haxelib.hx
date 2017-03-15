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
            kind: Zip,
            lib: { name: Some(name), versionNumber: Some(version), versionId: Some('haxelib'), }
          } : ArchiveJob);
      }    
      
  static public function resolveVersion(name:String):Promise<String> 
    return Download.text('https://lib.haxe.org/p/$name').next(function (s) return s.split(')</title>')[0].split('(').pop());
      
}