package lix.client;

import js.node.Buffer;
import js.node.Url;

/**
 * Authentication is opt-in - if no credentials are found, downloads proceed without auth.
 * currently only auth via .netrc is available
 */
class Auth {

  static public function getHostname(url:String):Null<String> {
    try {
      var parsed = Url.parse(url);
      return parsed.hostname;
    } catch (e:Dynamic) {
      return null;
    }
  }

  static public function getNetrcAuth(hostname:String):Null<{login:String, password:String}> {
    if (hostname == null) return null;

    try {
      var netrc = js.Lib.require('netrc');
      var credentials = netrc();
      var machine = Reflect.field(credentials, hostname);

      if (machine != null) {
        var login = Reflect.field(machine, 'login');
        var password = Reflect.field(machine, 'password');

        if (login != null && password != null) {
          return {
            login: login,
            password: password
          };
        }
      }
    } catch (e:Dynamic) {
      // .netrc not found, parse error, or netrc package not installed
    }

    return null;
  }

  static public function hasNetrcAuth(hostname:String):Bool {
    return getNetrcAuth(hostname) != null;
  }

  static public function createBasicAuthHeader(login:String, password:String):String {
    var auth = '$login:$password';
    var encoded = Buffer.from(auth).toString('base64');
    return 'Basic $encoded';
  }

  static public function getAuthHeaders(url:String):Dynamic {
    var headers = {};

    var hostname = getHostname(url);
    if (hostname == null) return headers;

    var netrcAuth = getNetrcAuth(hostname);
    if (netrcAuth != null) {
      Reflect.setField(headers, 'authorization',
        createBasicAuthHeader(netrcAuth.login, netrcAuth.password));
    }

    return headers;
  }
}
