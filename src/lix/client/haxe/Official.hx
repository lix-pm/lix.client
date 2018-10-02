package lix.client.haxe;

abstract Official(String) from String to String {
  public var isPrerelease(get, never):Bool;
    function get_isPrerelease()
      return this.indexOf('-') != -1;
      
  static var SPLITTER = ~/[^0-9a-z]/g;
  
  static function isNumber(s:String)
    return ~/^[0-9]*$/.match(s);
            
  static function fragment(a:String, b:String)
    return 
      if (isNumber(a) && isNumber(b))
        Std.parseInt(a) - Std.parseInt(b);
      else
        Reflect.compare(a, b);
            
  static public function compare(a:Official, b:Official):Int {
    
    var a = (a:String).split('-'),
        b = (b:String).split('-'),
        i = 0;
            
    while (i < a.length && i < b.length) {
      var a = a[i].split('.'),
          b = b[i++].split('.'),
          i = 0;
      while (i < a.length && i < b.length) 
        switch fragment(a[i], b[i]) {
          case 0: i++;
          case v: return -v;
        }
        
      switch a.length - b.length {
        case 0:
        case v: return -v;
      }
    }
    
    return 
      (a.length - b.length) * (if (i == 1) 1 else -1);
  }
}
