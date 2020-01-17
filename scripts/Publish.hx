package ;

class Publish {
  static function main() {
    var version = switch Sys.args()[0] {
      case null: 'patch';
      case v: v;
    }
    cmd('npm version $version');
    cmd('git push origin --tags');
  }
}