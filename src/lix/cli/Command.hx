package lix.cli;

import Sys.*;

using StringTools;
using tink.CoreApi;

abstract CommandExpander(Array<String>->Option<Array<String>>) from Array<String>->Option<Array<String>> {

  public inline function expand(args:Array<String>)
    return this(args);

  @:from static public function ofString(s:String):CommandExpander
    return switch s.indexOf(' ') {
      case -1:
        throw 'invalid expander syntax in "$s"';
      case v:
        make(s.substr(0, v), s.substr(v + 1));
    }

  static public function make(prefix:String, rule:String):CommandExpander {

    var replacer = ~/\$\{([0-9]+)\}/g;
    var parts = [];
    var highest = -1;
    replacer.map(rule, function (e) {

      parts.pop();

      var left = e.matchedLeft(),
          right = e.matchedRight();

      parts.push(function (_) return left);

      var pos = Std.parseInt(e.matched(1));

      if (pos > highest)
        highest = pos;

      parts.push(function (args:Array<String>) return args[pos]);
      parts.push(function (_) return right);

      return '';
    });

    function apply(args:Array<String>)
      return
        [for (res in [for (p in parts) p(args)].join('').split(' '))
          switch res.trim() {
            case '': continue;
            case v: v;
          }
        ];

    return function (args:Array<String>) {
      for (i in 0...args.length)
        if (args[i] == prefix)
          return Some(
            args.slice(0, i)
              .concat(apply(args.slice(i + 1, i + highest + 2)))
              .concat(args.slice(i + highest + 2))
          );
      return None;
    }
  }
}

abstract CommandName(Array<String>) from Array<String> {

  @:from static function ofString(s:String):CommandName
    return [s];

  @:to public function toString()
    return switch this {
      case [v]: v;
      case a: a.join(' / ');
    }

  @:op(a == b) static public function eq(a:CommandName, b:String)
    return (cast a : Array<String>).indexOf(b) != -1;
}

class Command {

  public var name(default, null):CommandName;
  public var args(default, null):String;
  public var doc(default, null):String;
  public var exec(default, null):Array<String>->Promise<Noise>;

  public function new(name, args, doc, exec) {
    this.name = name;
    this.args = args;
    this.doc = doc;
    this.exec = exec;
  }

  static public function attempt<T>(p:Promise<T>, andThen:Callback<T>)
    p.recover(Command.reportError).handle(andThen);

  public function as(alias:CommandName, ?doc:String)
    return new Command(alias, args, if (doc == null) this.doc else doc, exec);

  static public function reportError(e:Error):Dynamic {
    stderr().writeString(e.message + '\n\n');
    Sys.exit(e.code);
    return null;
  }

  static public function reportOutcome(o:Outcome<Noise, Error>)
    switch o {
      case Failure(e): reportError(e);
      default:
    }

  static public function expand(args:Array<String>, expanders:Array<CommandExpander>) {
    var changed = true;
    while (changed) {
      changed = false;

      for (e in expanders)
        switch e.expand(args) {
          case Some(nu):
            args = nu;
            changed = true;
          default:
        }
    }
    return args;
  }

  static public function dispatch(args:Array<String>, title:String, commands:Array<Command>, extras:Array<Named<Array<Named<String>>>>, ?fallback:Array<String>->Option<() -> Promise<Noise>>):Promise<Noise>
    return
      switch args.shift() {
        case null | '--help':
          println(title);
          println('');
          var prefix = 0;

          for (c in commands) {
            var longest = {
              var v = 0;
              for (line in c.args.split('\n'))
                if (line.length > v) v = line.length;
              v;
            }
            var cur = c.name.toString().length + longest;
            if (cur > prefix)
              prefix = cur;
          }

          prefix += 7;

          function pad(s:String)
            return s.lpad(' ', prefix);

          println('  Supported commands:');
          println('');

          for (c in commands) {
            var leftCol = c.args.split('\n');

            leftCol[0] = '  ' + c.name + (switch leftCol[0] { case '' | null: ''; case v: ' $v'; }) + ' : ';
            for (i in 1...leftCol.length)
              leftCol[i] = leftCol[i] + '   ';
            var rightCol = c.doc.split('\n');

            while (leftCol.length < rightCol.length)
              leftCol.push('');

            while (leftCol.length > rightCol.length)
              rightCol.push('');

            for (i in 0...leftCol.length)
              println(pad(leftCol[i]) + rightCol[i]);
          }

          for (e in extras) {
            println('');
            println('  ${e.name}');
            println('');
            for (e in e.value)
              println(pad('${e.name} : ') + e.value);
          }
          println('');
          Noise;

        case command:

          for (canditate in commands)
            if (canditate.name == command)
              return canditate.exec(args);

          if (fallback != null) {
            args.unshift(command);
            switch fallback(args) {
              case Some(v): return v();
              default:
            }
          }

          return new Error(NotFound, 'unknown command $command');
      }
}
