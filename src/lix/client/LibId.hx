package lix.client;

abstract LibId(String) from String to String {
  
  public var scheme(get, never):String;
    function get_scheme()
      return switch this.indexOf(':') {
        case -1: '';
        case v: this.substr(0, v);
      }  
      
  public var payload(get, never):String;
    function get_payload()
      return this.substr(this.indexOf(':') + 1);
}