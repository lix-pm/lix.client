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
  
  static public function parse(s:String):Outcome<LibVersion, Error> {
    function make(name:String, version:String):Outcome<LibVersion, Error> { 
      var ret:LibVersion = {
        name: Some(name),
        versionNumber: None,
        versionId: None
      }
      switch version.split('/') {
        case ['']:
        case [v]:
          ret.versionNumber = Some(v);
        case [num, id]:
          ret.versionNumber = Some(num);
          ret.versionId = Some(id);
        default: 
          return Failure(new Error(422, 'invalid alias version $s'));
      }
      return Success(ret);
    }
    
    return switch s.indexOf('#') {
      case -1:
        make(s, '');
      case v:
        make(s.substring(0, v), s.substring(v + 1));
    }
  }
}