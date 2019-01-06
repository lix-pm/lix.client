package lix.client.sources;

class Git {
  
  var github:GitHub;
  var gitlab:GitLab;
  var scope:Scope;
  var submodules:Bool;

  public function schemes() return ['git'];

  public function new(github, gitlab, scope, submodules) {
    this.github = github;
    this.gitlab = gitlab;
    this.scope = scope;
    this.submodules = submodules;
  }

  static function eval(cmd:String, cwd:String, args:Array<String>, ?env:Env) 
    return switch js.node.ChildProcess.spawnSync(cmd, args, { cwd: cwd, stdio:['inherit', 'pipe', 'inherit'], env: Exec.mergeEnv(env) } ) {
      case x if (x.error == null):
        Success({
          status: x.status,
          stdout: (x.stdout:js.node.Buffer).toString(),
        });
      case { error: e }:
        Failure(new Error('Failed to call $cmd because $e'));
    }  

  static function cli(cwd:String) {
    Fs.ensureDir(cwd.addTrailingSlash());
    return {
      call: function (args:Array<String>) {
        return Promise.lift(Exec.sync('git', cwd, args)).next(
          function (code) return if (code == 0) Noise else new Error(code, 'git ${args[0]} failed')
        );
      },
      eval: function (args:Array<String>) {
        return Promise.lift(eval('git', cwd, args)).next(
          function (o) return switch o {
            case { status: 0 }: o.stdout.toString();
            default: new Error(o.status, 'git ${args[0]} failed');
          }
        );  
      }
    }
  }
    
  public function processUrl(raw:Url):Promise<ArchiveJob> 
    return 
      switch raw.payload {
        case gh if (gh.startsWith('https://github.com')):
          github.processUrl(switch gh {
            case v if (v.endsWith('.git')): v.substr(0, v.length - 4);
            case v: v;
          });
        case gl if (gl.startsWith('https://gitlab.com')):
          gitlab.processUrl(switch gl {
            case v if (v.endsWith('.git')): v.substr(0, v.length - 4);
            case v: v;
          });
        case (_:Url) => url:
          var origin = url.resolve(''),
              version = switch url.hash {
                case null | '': 'HEAD';
                case v: v;
              };

          var git = cli('.');
              
          var sha = 
            if (version.length != 40) 
              git.eval(['ls-remote', origin, version])
                .next(function (s) return switch s.trim() {
                  case '': new Error('Cannot resolve version $version');
                  case v: v.substr(0, 40); 
                })
            else 
              Promise.lift(version);
          
          sha.next(function (sha):ArchiveJob return {
            url: raw,
            arguments: submodules ? ['--submodules'] : [],
            normalized: raw.scheme + ':' + url.resolve('#$sha'),
            dest: Computed(function (l) return [l.name, l.version, 'git', sha]),
            lib: { name: None, version: None },
            kind: Custom(function (ctx) return {
              var repo = Path.join([scope.libCache, '.gitrepos', DownloadedArchive.escape(origin)]);
              var git = cli(repo);
              git.call(
                if ('$repo/.git'.exists()) ['fetch', origin]
                else ['clone', origin, '.']
              )
                .next(function (_)
                  return git.call(['checkout', sha])
                )
                .next(function (_)
                  return submodules ? git.call(['submodule', 'update', '--init', '--recursive']) : Noise
                )
                .next(function (_) {
                  Fs.copy(repo, ctx.dest, function (name) return name != '$repo/.git');
                  return Noise;
                })
                .next(function (_)
                  return ctx.dest
                );
            })
          });
      }    
}