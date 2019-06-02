package lix.client;

import haxe.Timer;
import lix.client.uncompress.*;
import js.node.Buffer;
import js.node.Url;
import js.node.Http;
import js.Node.*;
import js.node.stream.Readable.IReadable;
import js.node.http.ClientRequest;
import js.node.http.IncomingMessage;

using tink.CoreApi;
using StringTools;

typedef Directory = String;

private typedef Events<T> = {
  function onProgress(loaded:Int, total:Int, binary:Bool):Void;
  function done(result:Outcome<T, Error>):Void;
}

private typedef ProgressHandler<T> = String->IncomingMessage->Events<T>->Void;
private typedef Handler<T> = String->IncomingMessage->(Outcome<T, Error>->Void)->Void;

class Download {

  static public function text(url:String):Promise<String>
    return bytes(url).next(function (b) return b.toString());
    
  static public function bytes(url:String):Promise<Bytes> 
    return download(url, function (_, r, cb) buffered(r).handle(cb));
    
  static function buffered(r:IncomingMessage):Promise<Bytes> 
    return Future.async(function (cb) {
      var ret = [];
      r.on('data', ret.push);
      r.on('end', function () {
        cb(Success(Buffer.concat(ret).hxToBytes()));
      });      
    });
    
  static public function archive(url:String, peel:Int, into:String, ?progress:Bool) {
    return download(url, withProgress(progress, function (finalUrl:String, res, events) {
      if (res.headers['content-type'] == 'application/zip' || url.endsWith('.zip') || finalUrl.endsWith('.zip'))
        unzip(url, into, peel, res, events);
      else
        untar(url, into, peel, res, events);
    }));
  }
    
  static function unzip(src:String, into:String, peel:Int, res:IncomingMessage, events:Events<String>) {
    buffered(res).next(function (bytes)
      return Future.async(function (cb) {
        var pos = bytes.length - 4;
        while (pos --> 0) {
          if (
            bytes.get(pos) == 0x50 
            && bytes.get(pos+1) == 0x4b 
            && bytes.get(pos+2) == 0x05 
            && bytes.get(pos+3) == 0x06 
          ) {
            bytes.set(pos + 20, 0);
            bytes.set(pos + 21, 0);
            bytes = bytes.sub(0, pos + 22);
            break;
          }
        }
        if (pos == 0) {
          cb(Failure(new Error(UnprocessableEntity, 'Unzip failed to find central directory in $src')));
          return;
        }
        Yauzl.fromBuffer(Buffer.hxFromBytes(bytes), function (err, zip) {
          var saved = -1;//something is really weird about this lib
          function done() {
            saved += 1;
            events.onProgress(saved, zip.entryCount, false);
            if (saved == zip.entryCount)
              haxe.Timer.delay(cb.bind(Success(into)), 100);
          }
          
          if (err != null)
            cb(Failure(new Error(UnprocessableEntity, 'Failed to unzip $src because $err')));
          
          zip.on("entry", function (entry) switch Fs.peel(entry.fileName, peel) {
            case None:
            case Some(f):
              var path = '$into/$f';
              if (path.endsWith('/')) 
                done();
              else {
                Fs.ensureDir(path);
                zip.openReadStream(entry, function (e, stream) { 
                  var out:js.node.fs.WriteStream = js.Lib.require('graceful-fs').createWriteStream(path);
                  stream.pipe(out, { end: true } );
                  out.on('close', done);
                });
              }
              
          });
          zip.on("end", function () {
            zip.close();
            done();
          });
        });            
      })).handle(events.done); 
  }
  static public function untar(src:String, into:String, peel:Int, res:IReadable, events:Events<String>) 
    return Future.async(function (cb) {
      var total = 0,
          written = 0;

      var symlinks = [];

      function update()
        events.onProgress(written, total + 1, true);

      var pending = 1;
      function done(progress = 0) {
        written += progress;
        update();
        haxe.Timer.delay(function () {
          if (--pending <= 0) {
            events.onProgress(total, total, true);
            Promise.inParallel([for (link in symlinks) 
              Future.async(function (cb) 
                js.node.Fs.unlink(link.to, function (_) 
                  js.node.Fs.symlink(link.from, link.to, function (e:js.Error) cb(//TODO: figure out if mode needs to be set
                    if (e == null) Success(Noise)
                    else Failure(new Error(e.message))
                  ))
                )
              )
            ]).next(function (_) return into).handle(cb);
          }
        }, 100);
      }

      var error:Error = null;
      
      function fail(message:String)
        cb(Failure(error = new Error(message)));

      Tar.parse(res, function (entry) {
        if (error != null) return;
        total += entry.size;
        update();

        function skip() {
          entry.on('data', function () {});
        }
        switch Fs.peel(entry.path, peel) {
          case None:
            skip();
          case Some(f):
            var path = '$into/$f';
            if (path.endsWith('/')) 
              skip();
            else {
              Fs.ensureDir(path);
              if (entry.type == SymbolicLink) {
                skip();
                symlinks.push({ from: Path.join([Path.directory(path), entry.linkpath]), to: path });
              }
              else {
                pending++;
                var buffer = @:privateAccess new js.node.stream.PassThrough();
                var out:js.node.fs.WriteStream = js.Lib.require('graceful-fs').createWriteStream(path, { mode: entry.mode });
                entry.pipe(buffer, { end: true } );
                buffer.pipe(out, { end: true } );
                out.on('close', done.bind(entry.size));
              }
            }
        }      
      }).handle(function (o) switch o {
        case Failure(e): cb(Failure(e));
        default: done();
      });
    }).handle(events.done);
  
  static public function tar(url:String, peel:Int, into:String, ?progress:Bool):Promise<Directory>
    return download(url, withProgress(progress, untar.bind(_, into, peel)));
    
  static public function zip(url:String, peel:Int, into:String, ?progress:Bool):Promise<Directory>
    return download(url, withProgress(progress, unzip.bind(_, into, peel)));

  static function withProgress<T>(?progress:Bool, handler:ProgressHandler<T>):Handler<T> {
    return 
      function (url:String, msg:IncomingMessage, cb:Outcome<T, Error>->Void) {
        if (progress != true || !process.stdout.isTTY) {
          handler(url, msg, {
            onProgress: function (_, _, _) {},
            done: cb,
          });          
          return;
        }
        
        var size = Std.parseInt(msg.headers.get('content-length')),
            loaded = 0,
            saved = 0,
            total = 1;
        
        var last = null;

        function progress(s:String) {
          if (s == last) return;
          last = s;
          untyped {
            process.stdout.clearLine(0);
            process.stdout.cursorTo(0);
          }
          process.stdout.write(s);
        }

        function pct(f:Float) {
          if (!(f <= 1.0))
            f = 1;
          return (switch Std.string(Math.round(1000 * f) / 10) {
            case whole = _.indexOf('.') => -1: '$whole.0';
            case v: v;
          }).lpad(' ', 5) + '%';
        }

        var lastUpdate = Date.fromTime(0).getTime();

        function update() {
          if (saved == total || (saved / total) >= 1.0) progress('Done!\n');
          else {
            var now = Date.now().getTime();
            if (now > lastUpdate + 137) {
              
              lastUpdate = now;
              var messages = [];
              if (loaded < size) messages.push('Downloaded: ${pct(loaded / size)}');
              if (saved > 0) messages.push('Saved: ${pct(saved / total)}');
              progress(messages.join('   '));
            }
          }
        }

        msg.on('data', function (buf) {
          loaded += buf.length;
          update();
        });

        var last = .0;
        handler(url, msg, {
          onProgress: function (_saved, _total, binary) {
            saved = _saved;
            total = _total;
            /**
              The following is truly hideous, but there's no easy way 
              to actually KNOW how much of a .tar.gz you have unpacked, because apparently:

              - tar was made for freaking TAPE WRITERS and is just a stream of entries, with no real
                beginning where the number of files might be mentioned (see https://en.wikipedia.org/wiki/Tar_(computing)#Random_access)
              - gzip doesn't seem to give any hints as to how big the file should be when uncompressed
            **/
            if (binary) {
              var downloaded = loaded / size;
              var decompressed = saved / total;
              var estimate = downloaded * decompressed;
              if (estimate < last)
                estimate = last;
              last = estimate;
              saved = Math.round(estimate * 1000);
              total = 1000;
            }
            update();
          },
          done: function (r) {
            saved = total;
            update();
            cb(r);
          },
        });
      }
  }
      
  static function download<T>(url:String, handler:Handler<T>):Promise<T>
    return Future.async(function (cb) {
      
      var options:HttpRequestOptions = cast Url.parse(url);
      
      options.agent = false;
      if (options.headers == null)
        options.headers = {};
      options.headers['user-agent'] = Download.USER_AGENT;
      
      function fail(e:js.Error)
        cb(Failure(tink.core.Error.withData('Failed to download $url because ${e.message}', e)));
        
      var req = 
        if (url.startsWith('https:')) js.node.Https.get(cast options);
        else js.node.Http.get(options);
      
      req.setTimeout(30000);
      req.on('error', fail);
      
      req.on(ClientRequestEvent.Response, function (res) {
        if (res.statusCode >= 400) 
          cb(Failure(Error.withData(res.statusCode, res.statusMessage, res)));
        else
          switch res.headers['location'] {
            case null:
              res.on('error', fail);
              
              handler(url, res, function (v) {
                switch v {
                  case Success(x): cb(Success(x));
                  case Failure(e): cb(Failure(e));
                }
              });
            case v:
              
              download(switch Url.parse(v) {
                case { protocol: null }:
                  options.protocol + '//' + options.host + v;
                default: v;
              }, handler).handle(cb);
          }
        });
    });
    
  static public var USER_AGENT = 'switchx';
}
