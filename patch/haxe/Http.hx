package haxe;

using tink.CoreApi;

class Http {
  var url:tink.Url;
  var headers = new DynamicAccess<Array<String>>();
  var params = new tink.url.Query.QueryStringBuilder();
  var rawPostData:String;

  public var responseHeaders:Map<String, String>;
  
  public function new(url:String) {
    this.url = url;
  }
  
  public function setHeader(header:String, value:String):Http {
    switch headers[header] {
      case null: headers[header] = [value];
      case v: v.push(value);
    }
    return this;
  }

  public function setPostData(data:String)
    this.rawPostData = data;

  public function setParameter(header:String, value:String):Http {
    params.add(header, value);
    return this;
  }
  
  dynamic public function onData(s:String) {}
  dynamic public function onError(s:String) {}
  dynamic public function onStatus(i:Int) {}
  
  public function request(?post:Bool) {
    if (rawPostData != null)
      post = true;
    if (post == null) 
      post = false;

    var params = params.toString();
    
    (switch url.scheme {
      case 'https':
        js.node.Https.request;
      default:   
        js.node.Http.request;
    })(
      {
        hostname: url.host.name,
        port: url.host.port,
        protocol: url.scheme + ':',
        method: if (post) 'POST' else 'GET',
        path: url.pathWithQuery + switch [params, post] {
          case ['', _] | [_, true]: '';
          case [v, _]:
            (if (url.query == null) '?' else '&') + v;
        },
        headers: headers,
      }, 
      function (res) {
        var parts = [];
        res.on('end', function () onData(js.node.Buffer.concat(parts).toString()));
        res.on('data', parts.push);
        res.on('error', function (e) onError(Std.string(e)));
      }
    ).on('error', function (e) onError(Std.string(e))).end(switch rawPostData {
      case null: 
        if (post) params else null;
      case v: v;
    });
  }
}