package lix.server;

import tink.semver.*;
import lix.api.Api;
import tink.http.Request;

class Server {
  static function main() {
    
    var r = new tink.web.routing.Router<ProjectsApi>(new ProjectsRepo());

    new tink.http.containers.NodeContainer(1234).run(function (req:IncomingRequest) {
      return r.route(tink.web.routing.Context.ofRequest(req)).recover(tink.http.Response.OutgoingResponse.reportError);
    });

    trace('running');

    var db = new Db('lix', new tink.sql.drivers.MySql({ user: 'root', password: '' }));
    db.Project.where(Project.id == 'tink_core').all().handle(function (x) trace(x));
  }
}

class ProjectsRepo implements ProjectsApi {
  public function new() {}

  public function list(?filter:ProjectFilter):Promise<Array<ProjectDescription>> return [];
  
  public function byName(name:ProjectName):ProjectApi {
    return new ProjectRepo(name);
  }
}

typedef Project = {
  var id(default, never):ProjectName;
  var deprecated(default, never):Bool;
}

typedef ProjectName = String;
typedef TagName = String;

typedef Tags = {
  var project(default, never):ProjectName;
  var tag(default, never):TagName;
}

typedef User = {
  var id(default, never):Int;
  var nick(default, never):String;
}

typedef ProjectVersion = {
  var project(default, never):ProjectName;
  var version(default, never):String;
  var published(default, never):Date;
}

typedef ProjectContributor = {
  var user(default, never):Int;
  var project(default, never):ProjectName;
  var role(default, never):ContributorRole;
}

@:enum abstract ContributorRole(String) {
  var Owner = 'owner';
  var Admin = 'admin';
  var Publisher = 'publisher';
}

@:tables(Project, User, ProjectVersion, Tags, ProjectContributor)
class Db extends tink.sql.Database {
}

class ProjectRepo implements ProjectApi {

  var path:String;
  
  public function new(name:String) {
    this.path = '/libraries/$name';
  }

  public function submit(version:String, archive:tink.io.Source):Promise<{}> {
    return new Error('Not Implemented');
  }

  public function info():Promise<ProjectInfo> 
    return new Error('Not Implemented');

  public function version(version:Version):VersionApi 
    return new VersionRepo(version);

}

class VersionRepo implements VersionApi {
  public function new(version) {}
  public function download():tink.io.Source return new Error('Not Implemented');
}