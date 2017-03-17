package lix.api;

import tink.semver.*;

typedef ProjectName = String;
typedef Author = String;
typedef Tag = String;
typedef Dependency = tink.semver.Resolve.Dependency<ProjectName>;
typedef Constraint = tink.semver.Constraint;

typedef ProjectFilter = {
  ?tags:Array<Tag>,
  ?textSearch:String,
  ?includeDeprecated:Bool,
  ?modifiedSince:Date,
  ?limit:Int,
  ?offset:Int,
}

interface ProjectsApi {
  @:params(query = filter)
  @:get('/')
  function list(?filter:ProjectFilter):Promise<Array<ProjectDescription>>;
  
  @:sub('/$name')
  function byName(name:ProjectName):ProjectApi;
}

interface ProjectApi {
  @:get('/')
  function info():Promise<ProjectInfo>;

  @:sub('/$version')
  function version(version:Version):VersionApi;
}

interface VersionApi {
  function download():Promise<{ url:String }>;
}

typedef ProjectInfo = {
  >ProjectDescription, 
  versions:Array<ProjectData>
}

typedef ProjectVersion = {
  version:Version,
  dependencies: Array<Dependency>,
  haxe: Constraint,
  published:Date,
}

typedef ProjectDescription = {
  name:ProjectName,
  description:String,
  authors:Array<Author>,
  ?tags:Array<Tag>,
  ?deprecated:Bool,
}
typedef ProjectData = {
  >ProjectVersion,
  >ProjectDescription,
}