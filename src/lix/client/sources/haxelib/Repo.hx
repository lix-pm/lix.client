package lix.client.sources.haxelib;

interface Repo {
  function getLatestVersion(project:String):String;
  function infos( project : String ) : ProjectInfos;
}

typedef SemVer = String;

typedef VersionInfos = {
	var date : String;
	var name : SemVer;//TODO: this should eventually be called `number`
	var downloads : Int;
	var comments : String;
}

typedef ProjectInfos = {
	var name : String;
	var desc : String;
	var website : String;
	var owner : String;
	var contributors : Array<{ name:String, fullname:String }>;
	var license : String;
	var curversion : String;
	var downloads : Int;
	var versions : Array<VersionInfos>;
	var tags : List<String>;
}
