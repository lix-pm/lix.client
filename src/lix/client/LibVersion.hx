package lix.client;

@:structInit class LibVersion {
  
  public var name(default, null):Option<String>;
  public var versionNumber(default, null):Option<String>;
  public var versionId(default, null):Option<String>;

  //public function toString() {
    //var ret = 
  //}
  
  static public var AUTO(default, null):LibVersion = {
    name: None,
    versionNumber: None,
    versionId: None
  };
  
  static public function parse(s:String, versionId:Null<String>, ?pos):LibVersion {
    var versionId = switch versionId {
      case null: None;
      case v: Some(v);
    }
    return switch s.indexOf('#') {
      case -1:
        {
          name: Some(s),
          versionNumber: None,
          versionId: versionId,
        }
      case v:
        {
          name: Some(s.substring(0, v)),
          versionNumber: Some(s.substring(v + 1)),
          versionId: versionId,
        }
    }
  }
}