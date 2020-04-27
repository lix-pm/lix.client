package lix.client.sources;

import tink.url.Auth;
import tink.url.Path;

@:tink class GitHub {

  static function isArchive(p:Path)
    return switch p.parts() {
      case [_, _, (_:String) => 'archive', _]: true;
      default: false;
    }

  public function intercept(url:Url)
    return return switch url {
      case { scheme: 'https', host: { name: 'github.com' }, path: isArchive(_) => false }:
        Some(processUrl(url));
      default:
        None;
    }

  public function schemes()
    return ['github', 'gh'];

  var credentials:Auth;
  public function new(?credentials)
    this.credentials = credentials;

  public function grabCommit(owner, project, version)
    return switch credentials {
      case null if (version == '' || !lix.client.haxe.UserVersion.isHash(version)): // short hashes will have to be resolved via API
        Download.bytes('https://github.com/$owner/$project.git/info/refs?service=git-upload-pack')
          .mapError(e -> switch e.code {
            case Unauthorized:
              new Error(e.code, e.message + ' - Possible typo in "$owner/$project"');
            default:
              e;
          })
          .next(function (s) {
            if (version == '')
              return s.toString().split(' HEAD')[0].substr(-40);

            var buf = new StringBuf(),
                data = s.getData();

            for (i in 0...s.length)
              switch haxe.io.Bytes.fastGet(data, i) {
                case 0:
                case v: buf.addChar(v);
              }


            for (l in buf.toString().split('\n')) {
              switch l.split(' ') {
                case [_.substr(-40) => sha, ref] if (sha.length == 40 && ref.endsWith('/$version')):
                  return sha;
                default:
              }
            }
            return new Error('Failed to lookup sha for github:$owner/$project$s');
          });
      default:
        Download.text('https://${credentials}api.github.com/repos/$owner/$project/commits?sha=$version')
          .next(function (s)
            try
              return(s.parse()[0].sha:String)
            catch (e:Dynamic) {
              var s = switch version {
                case null | '': '';
                case v: '#$v';
              }

              return new Error('Failed to lookup sha for github:$owner/$project$s');
            }
          );
    }


  public function getArchive(owner:String, project:String, ?commitish:String, ?credentials:Auth):Promise<ArchiveJob> {
    function doGet(sha)
      return getArchive(owner, project, sha, credentials);
    return switch commitish {
      case null:
        grabCommit(owner, project, '').next(doGet);
      case sha if (sha.length == 40):
        return ({
          normalized: 'gh://${credentials}github.com/$owner/$project#$sha',
          dest: Computed(function (l) return [l.name, l.version, 'github', sha]),
          url: 'https://${credentials}github.com/$owner/$project/archive/$sha.tar.gz',
          lib: { name: Some(project), version: None },
        } : ArchiveJob);
      case v:
        grabCommit(owner, project, v).next(doGet);
    }
  }

  public function processUrl(url:Url):Promise<ArchiveJob>
    return switch url.path {
      case null: new Error('invalid github url $url');
      case _.parts().toStringArray() => [owner, project]:
        getArchive(owner, Git.strip(project), url.hash, url.auth);
      default: new Error('invalid github url $url');
    }
}