package lix.client.haxe;

using StringTools;
using haxe.io.Path;


abstract UserVersion(UserVersionData) from UserVersionData to UserVersionData {
  
  static var hex = [for (c in '0123456789abcdefABCDEF'.split('')) c.charCodeAt(0) => true];
  
  @:from static function ofResolved(v:ResolvedVersion):UserVersion
    return switch v {
      case ROfficial(version): UOfficial(version);
      case RNightly({ hash: version }): UNightly(version);
      case RCustom(v): UCustom(v);
    }
  
  static public function isHash(version:String) {
    
    for (i in 0...version.length)
      if (!hex[version.fastCodeAt(i)])
        return false; 
        
    return true;
  }  

  public function toString()
    return switch this {
      case UEdge:   'latest nightly build';
      case ULatest: 'latest official';
      case UStable: 'latest stable release';
      case UNightly(v): 'nightly build $v';
      case UOfficial(v): 'official release $v';
      case UCustom(v): 'custom version at `$v`';
    }

  static public function isPath(v:String)
    return v.isAbsolute() || v.charAt(0) == '.';
  
  @:from static public function ofString(s:Null<String>):UserVersion
    return 
      if (s == null) null;
      else switch s {
        case 'auto': null;
        case 'edge' | 'nightly': UEdge;
        case 'latest': ULatest;
        case 'stable': UStable;
        case isHash(_) => true: UNightly(s);
        case isPath(_) => true: UCustom(s);
        default: UOfficial(s);//TODO: check if this is valid?
      }
  
}

enum UserVersionData {
  UEdge;
  ULatest;
  UStable;
  UNightly(hash:String);
  UOfficial(version:Official);
  UCustom(path:String);
}