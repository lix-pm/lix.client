package lix.client;

@:structInit class LibVersion {
  
  public var name(default, null):Option<String>;
  public var versionNumber(default, null):Option<String>;
  public var versionId(default, null):Option<String>;
  
  function or(a:Option<String>, b:Option<String>) 
    return switch a {
      case Some(_): a;
      default: b;
    }
  
  public function merge(as:LibVersion):LibVersion {
    if (as == null) return this;
    return {
      name: or(as.name, this.name),
      versionNumber: or(as.versionNumber, this.versionNumber),
      versionId: or(as.versionId, this.versionId),
    }
  }

  
  static public var AUTO(default, null):LibVersion = {
    name: None,
    versionNumber: None,
    versionId: None
  };
  
  static public function parse(s:String, ?versionId:Null<String>):LibVersion {
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