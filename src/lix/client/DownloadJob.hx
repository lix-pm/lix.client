package lix.client;

@:structInit class DownloadJob {
  
  public var source(default, null):LibUrl;
  @:optional public var target(default, null):LibVersion;
  
  public function toString()
    return source + switch target {
      case null: '';
      case v: ' $SEPARATOR $v';
    }
    
  static public inline var SEPARATOR = 'as';
  
}