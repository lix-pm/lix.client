package lix.client.sources.haxelib;

interface Repo {
  function infos( project : String ) : ProjectInfos;
}