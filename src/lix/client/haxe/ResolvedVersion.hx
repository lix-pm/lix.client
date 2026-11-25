package lix.client.haxe;

enum ResolvedUserVersionData {
  RNightly(nightly:Nightly);
  ROfficial(version:Official);
  RCustom(path:String);
  // (hxmc's build: an exact npm version, Hxmc)
  RHxmc(version:String);
}

abstract ResolvedVersion(ResolvedUserVersionData) from ResolvedUserVersionData to ResolvedUserVersionData {
  
  public var id(get, never):String;
  
    function get_id()
      return switch this {
        case RNightly({ hash: v }): v;
        case ROfficial(v) | RCustom(v): v;
        case RHxmc(v): Hxmc.PREFIX + v;
      }
  
  public function toString():String    
    return switch this {
      case RNightly(nightly): nightly.hash;
      case ROfficial(version): version;
      case RCustom(path): path;
      case RHxmc(version): Hxmc.PREFIX + version;
    }
}