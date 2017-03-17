package lix.server;

import tink.semver.*;
import lix.api.Api;

class Server {
  static function main() {
    
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

  public function info():Promise<ProjectInfo> return new Error('Not Implemented');
  public function version(version:Version):VersionApi return new VersionRepo(version);

}

class VersionRepo implements VersionApi {
  public function new(version) {}
  public function download():Promise<{ url:String }> return new Error('Not Implemented');
}