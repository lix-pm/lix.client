package lix.server;

import tink.semver.*;
import lix.api.Api;
import tink.http.Request;

class Server {
  static function main() {
    var r = new tink.web.routing.Router<ProjectsRepo>(new ProjectsRepo());
    new tink.http.containers.NodeContainer(1234).run(function (req:IncomingRequest) {
      return r.route(tink.web.routing.Context.ofRequest(req)).recover(tink.http.Response.OutgoingResponse.reportError);
    });
    trace('running');
  }
}

class ProjectsRepo implements ProjectsApi {
  public function new() {}

  public function list(?filter:ProjectFilter):Promise<Array<ProjectDescription>> return [];
  
  public function byName(name:ProjectName):ProjectApi {
    return new ProjectRepo(name);
  }
}

class ProjectRepo implements ProjectApi {
  
  public function new(name:String) {}

  public function submit(version:String, archive:tink.io.Source):Promise<{}>
    return new Error('Not Implemented');

  public function info():Promise<ProjectInfo> 
    return new Error('Not Implemented');

  public function version(version:Version):VersionApi 
    return new VersionRepo(version);

}

class VersionRepo implements VersionApi {
  public function new(version) {}
  public function download():tink.io.Source return new Error('Not Implemented');
}