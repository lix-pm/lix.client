package lix.data;

typedef Manifest = {
  var name(default, null):ProjectName;
  var dependencies(default, null):Array<Dependency>;
}

#if false
{
    "name": "coconut.vdom",
    "dependencies": [
        "gh:MVCoconut/coconut.ui#^1.2.3",
    ]
}
#end