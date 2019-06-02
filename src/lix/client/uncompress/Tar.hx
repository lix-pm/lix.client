package lix.client.uncompress;

import js.node.stream.Writable;
import js.node.stream.Readable;

using tink.CoreApi;

class Tar {
  static public function parse(source:IReadable, onentry:TarEntry->Void):Promise<Noise> 
    return Future.async(function (cb) {
      var entries = 0,
          warnings = 0;

      var parse = new TarParse({ 
        onentry: function (e) {
          entries++;
          onentry(e);
        } 
      });
      
      parse.on('warn', function () warnings++);
      parse.on('end', function () cb(
        if (entries == 0 && warnings != 0) Failure(new Error(UnprocessableEntity, 'Invalid tar archive.')) 
        else Success(Noise))
      );
      parse.on('error', function (e) cb(Failure(new Error((e.message:String)))));
      
      source.pipe(parse, { end: true });
    });
}

@:jsRequire('tar', 'Parse')
extern class TarParse extends Writable<TarParse> {
  public function new(options:{ function onentry(entry:TarEntry):Void; }):Void;
}

extern interface TarEntry extends IReadable {
  var size(default, null):Int;
  var path(default, null):String;
  var mode(default, null):Int;
  var linkpath(default, null):String;
  var type(default, null):TarEntryType;
} 

@:enum abstract TarEntryType(String) to String {
  var SymbolicLink = 'SymbolicLink';
  var File = 'File';
  var Directory = 'Directory';
}