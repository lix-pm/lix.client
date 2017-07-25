package lix.client.sources.haxelib;

interface Repo {
  function getLatestVersion(project:String):String;
}