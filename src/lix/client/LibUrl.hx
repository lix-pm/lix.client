package lix.client;

abstract LibUrl(String) from String to String {
  
  static inline var SEPARATOR = '#';
  
  public function new(id:LibId, version:Option<String>) 
    this = id + switch version {
      case Some(v): SEPARATOR + v;
      case None: '';
    }
  
  public var id(get, never):LibId;
    function get_id():LibId
      return switch this.indexOf('#') {
        case -1: this;
        case v: this.substr(0, v);
      }
      
  public var version(get, never):Option<String>;
    function get_version()
      return switch this.indexOf('#') {
        case -1: None;
        case v: switch this.substr(v + SEPARATOR.length) {
          case '': None;
          case v: Some(v);
        }
      }
}