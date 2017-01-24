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
    
  public function toString() 
    return switch name {
      case None: '';
      case Some(v):
        v + switch versionNumber {
          case Some(v):
            '#$v' + switch versionId {
              case Some(v): '/$v';
              case None: '';
            }
          case None: '';
        }
    }
  
  public function merge(as:LibVersion):LibVersion {
    if (as == null) return this;
    return {
      name: or(as.name, this.name),
      versionNumber: or(as.versionNumber, this.versionNumber),
      versionId: or(as.versionId, this.versionId),
    }
  }
  
  static public function parse(s:String):LibVersion {
    function make(name:String, version:String):LibVersion { 
      var ret:LibVersion = {
        name: Some(name),
        versionNumber: None,
        versionId: None
      }
      switch version.indexOf('/') {
        case -1:
          ret.versionNumber = Some(version);
        case v:
          ret.versionNumber = Some(version.substr(0, v));
          ret.versionId = Some(version.substr(v+1));
      }
      return ret;
    }
    
    return switch s.indexOf('#') {
      case -1:
        make(s, '');
      case v:
        make(s.substring(0, v), s.substring(v + 1));
    }
  }
}