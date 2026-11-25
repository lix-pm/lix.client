package lix.client.haxe;

import haxe.DynamicAccess;
import js.node.Buffer;

using StringTools;

/**
 * Builds of hxmc (https://github.com/benmerckx/hxmc, the Haxe compiler ported to Haxe) from npm's registry, read
 * directly (no npm client): `@hxmc/cli` and this machine's `@hxmc/<platform>-<arch>` (one of its optional
 * dependencies, as npm picks it), unpacked as npm would install them under `<root>/hxmc/<version>/node_modules`,
 * set up by the package's own `postinstall.mjs`, and `<root>/versions/hxmc-<version>` a link to the package's
 * `dist/`, the installation it ships for lix.
 *
 * As a version: `hxmc-<npm version>` (pinned, what `.haxerc` holds), `hxmc-<dist-tag>` (`latest`, `next`) or
 * `hxmc-<commit>` (a nightly's, the last part of its version), and `hxmc` alone for `hxmc-latest`.
 */
// npm's document of a package: its versions' metadata (`dist`, `optionalDependencies`) and `dist-tags`
private typedef Packument = {
  final versions:DynamicAccess<Dynamic>;
}

class Hxmc {

  static public inline var PREFIX = 'hxmc-';
  static inline var CLI = '@hxmc/cli';
  static inline var REGISTRY = 'https://registry.npmjs.org/';

  static public function isHxmc(version:String)
    return version == 'hxmc' || version.startsWith(PREFIX);

  // the spec after `hxmc-` (`latest` for `hxmc`)
  static public function spec(version:String)
    return if (version == 'hxmc') 'latest' else version.substr(PREFIX.length);

  // (typed: a function giving `Dynamic` to `next` would be taken as giving a promise)
  static function packument(name:String):Promise<Packument>
    return Download.text(REGISTRY + name.replace('/', '%2F')).next(function (s):Packument return haxe.Json.parse(s));

  // the npm version a spec names: an exact version, a dist-tag, or a commit that ends exactly one version
  static public function resolve(spec:String):Promise<String>
    return packument(CLI).next(function (p):Promise<String> {
      final versions:DynamicAccess<Dynamic> = p.versions,
            tags:DynamicAccess<String> = Reflect.field(p, 'dist-tags');
      if (tags != null && tags.exists(spec)) return tags[spec];
      if (versions.exists(spec)) return spec;
      return switch [for (v in versions.keys()) if (v.endsWith('.$spec')) v] {
        case [v]: v;
        case []: new Error(NotFound, 'No hxmc build $spec on npm (neither a version of $CLI, a dist-tag, nor a commit)');
        case several: new Error(Conflict, 'hxmc build $spec is ambiguous: ${several.join(', ')}');
      }
    });

  // npm's name of this machine's platform package (its `os` and `cpu`, as npm matches them)
  static function platformPackage()
    return '@hxmc/${js.Node.process.platform}-${js.Node.process.arch}';

  // version of package name as a tarball
  static function tarball(name:String, version:String, logger:Logger):Promise<Bytes>
    return packument(name).next(function (p):Promise<Bytes> {
      final versions:DynamicAccess<Dynamic> = p.versions;
      final meta = versions[version];
      if (meta == null) return new Error(NotFound, '$name has no version $version');
      final dist = meta.dist;
      logger.info('  $name@$version');
      return Download.bytes(dist.tarball);
    });

  static function unpack(bytes:Bytes, into:String):Promise<Noise>
    return Future.async(cb -> {
      final stream = new js.node.stream.PassThrough();
      stream.end(Buffer.hxFromBytes(bytes));
      // (npm's tarballs hold the package in `package/`)
      Download.untar(into, into, 1, stream, {
        onProgress: (_, _, _) -> {},
        done: o -> cb(switch o {
          case Success(_): Success(Noise);
          case Failure(e): Failure(e);
        }),
      });
    });

  /**
   * Installs version (an exact npm version) into `<root>/hxmc/<version>` and links `target` (the version's
   * directory in `<root>/versions`) to its installation.
   */
  static public function install(version:String, root:String, target:String, logger:Logger):Promise<Noise> {
    final base = '$root/hxmc/$version/node_modules';
    final cliDir = '$base/$CLI';
    return packument(CLI)
      .next(function (p):Promise<Noise> {
        final versions:DynamicAccess<Dynamic> = p.versions;
        final meta = versions[version];
        if (meta == null) return new Error(NotFound, '$CLI has no version $version');
        final optional:DynamicAccess<String> = meta.optionalDependencies;
        final platform = platformPackage();
        return
          if (optional == null || !optional.exists(platform))
            new Error(NotFound, 'hxmc $version has no build for this machine ($platform)');
          else Promise.inParallel([
            tarball(CLI, version, logger).next(b -> unpack(b, cliDir)),
            tarball(platform, version, logger).next(b -> unpack(b, '$base/$platform')),
          ]).noise();
      })
      .next(function (_):Promise<Noise> {
        // (the package's own setup: dist/std, dist/platform.txt, the native compiler in place of its launcher)
        final r = js.node.ChildProcess.spawnSync(js.Node.process.execPath, ['$cliDir/hxmc/bootstrap/postinstall.mjs'], { stdio: 'inherit' });
        final dist = '$cliDir/dist';
        return
          if (r.error != null) new Error('hxmc $version: its setup failed: ${r.error}');
          else if (!'$dist/std'.exists()) new Error('hxmc $version: its setup made no installation in $dist');
          else {
            try js.node.Fs.unlinkSync(target) catch (_:Dynamic) {}
            js.node.Fs.symlinkSync(dist, target, if (js.Node.process.platform == 'win32') 'junction' else 'dir');
            Noise;
          }
      });
  }
}
