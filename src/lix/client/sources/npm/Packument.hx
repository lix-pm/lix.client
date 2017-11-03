package lix.client.sources.npm;

import tink.semver.Version;
import tink.semver.Resolve;
import tink.semver.Constraint;
import haxe.DynamicAccess;

class PackumentVersionParser {
  public function new(_) {}

  public function parse(d:{ version:Version, ?haxeDependencies:DynamicAccess<Constraint> })
    return {
      version: d.version,
      dependencies: switch d.haxeDependencies {
        case null: [];
        case deps: [for (name in deps.keys()) {
          name: name,
          constraint: deps[name],
        }];
      }
    }
}

class PackumentParser {
  
  public function new(_) {}

  public function parse(data:{ versions: DynamicAccess<PackumentVersion> }) 
    return new Infos([for (v in data.versions.keys()) data.versions[v]]);
}


@:jsonParse(lix.client.sources.npm.Packument.PackumentVersionParser)
typedef PackumentVersion = {
  version: Version,
  dependencies:Array<Dependency<String>>
}

@:jsonParse(lix.client.sources.npm.Packument.PackumentParser)
typedef Packument = Infos<String>;
// {
//   versions:DynamicAccess<{
//     version:String,
//     ?haxeDependencies:DynamicAccess<String>,
//   }>,
// }

// typedef VersionList = Array