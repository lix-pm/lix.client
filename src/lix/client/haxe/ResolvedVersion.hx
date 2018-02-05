package lix.client.haxe;

enum ResolvedUserVersionData {
  RNightly(nightly:Nightly);
  ROfficial(version:Official);
  RCustom(path:String);
}

abstract ResolvedVersion(ResolvedUserVersionData) from ResolvedUserVersionData to ResolvedUserVersionData {
  
  public var id(get, never):String;
  
    function get_id()
      return switch this {
        case RNightly({ hash: v }): v;
        case ROfficial(v) | RCustom(v): v;
      }
  
  public function toString():String    
    return (this : UserVersion).toString();
}