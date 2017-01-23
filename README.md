# lix - the haxe package manager that rox ... ba-dum-tss ...

Lix is an attempt to get dependency management right, build on lessons learnt from looking at NPM, Cargo and failure to move haxelib forward.

The core proposition of Lix is that dependencies should be fully locked down and versioned, so that every state can be reliably replicated. To do this, it leverages [haxeshim](https://github.com/lix-pm/haxeshim), while creating the necessary directives for a reinstallation.
  
Currently it misses many features that you would expect in a package manager, because its development is still in a very early stage. Most importantly, after installing a library it does not install its dependencies automatically.