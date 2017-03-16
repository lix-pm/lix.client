package lix.client;

@:structInit class LibVersion {
  
  public var name(default, null):Option<String>;
  public var version(default, null):Option<String>;
  
  function or(a:Option<String>, b:Option<String>) 
    return switch a {
      case Some(_): a;
      default: b;
    }
    
  public function toString() 
    return switch name {
      case None: '';
      case Some(v):
        v + switch version {
          case Some(v): '#$v';
          case None: '';
        }
    }

  public function merge(as:LibVersion):LibVersion {
    if (as == null) return this;
    return {
      name: or(as.name, this.name),
      version: or(as.version, this.version),
    }
  }    

  static public function parse(s:String):LibVersion 
    return 
      if (s == null) null;
      else switch s.indexOf('#') {
        case -1:
          { name: Some(s), version: None };
        case v:
          { name: Some(s.substring(0, v)), version: Some(s.substring(v + 1)) };
      }
  static public var UNDEFINED(default, null):LibVersion = { name: None, version: None };
}