package lix.api;

import tink.semver.*;

typedef ProjectName = String;
typedef Author = String;
typedef Tag = String;
typedef Dependency = tink.semver.Resolve.Dependency<ProjectName>;
typedef Constraint = tink.semver.Constraint;

typedef ProjectFilter = {
  @:optional var tags(default, never):Array<Tag>;
  @:optional var textSearch(default, never):String;
  @:optional var includeDeprecated(default, never):Bool;
  @:optional var modifiedSince(default, never):Date;
  @:optional var limit(default, never):Int;
  @:optional var offset(default, never):Int;
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

  @:put('/$version')
  @:params(body = archive)
  function submit(version:String, archive:tink.io.Source):Promise<{}>;

  @:sub('/$version')
  function version(version:Version):VersionApi;
}

interface VersionApi {
  function download():tink.io.Source;
}

typedef ProjectInfo = {
  >ProjectDescription, 
  var versions(default, never):Array<ProjectData>;
}

typedef ProjectVersion = {
  var version(default, never):Version;
  var dependencies(default, never):Array<Dependency>;
  var haxe(default, never):Constraint;
  var published(default, never):Date;
}

typedef ProjectDescription = {
  var name(default, never):ProjectName;
  var description(default, never):String;
  var authors(default, never):Array<Author>;
  @:optional var tags(default, never):Array<Tag>;
  @:optional var deprecated(default, never):Bool;
}

typedef ProjectData = {
  >ProjectVersion,
  >ProjectDescription,
}