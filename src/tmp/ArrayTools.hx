package tmp;

class ArrayTools {
  static public inline function keys<T>(a:Array<T>)
    return 0...a.length;

  static public inline function contains<T>(a:Array<T>, value:T)
    return a.indexOf(value) != -1;
}