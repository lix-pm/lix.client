# lix - the haxe package manager that rox ... ba-dum-tss ...

In a nutshell, lix is an attempt to get dependency management right, building on lessons learnt from looking at NPM, Cargo and failure to move haxelib forward.

The core proposition of lix is that dependencies should be fully locked down and versioned, so that every state can be reliably replicated. To do this, it leverages [haxeshim](https://github.com/lix-pm/haxeshim), while creating the necessary directives for a reinstallation. This is (to the best of my understanding) pretty similar to how Rust's Cargo works.
  
Currently lix misses many features that you would expect in a package manager, because its development is still in a very early stage. Most notably, after installing a library, it does not install its dependencies automatically. There are two reasons for that:
  
1. This is not particularly hard to do *somehow* but getting it *right* is a different matter.
2. It's actually just a nice comfort feature. Installing missing libraries is super boring, yes, but it's not hard in any way. Making sure that your whole team and the CI server has the exact same versions is a bit more of a challenge. This is what lix really focuses on.

In fact lix's dependencies were installed with lix. The result are the `*.hxml` files found in the [haxe_libaries](https://github.com/lix-pm/lix/tree/master/haxe_libraries) folder. You can look at the history of every file individually, for example the [dependency on haxeshim](https://github.com/lix-pm/lix/commits/master/haxe_libraries/haxeshim.hxml).

What this means is that for every single commit, your dependencies are entirely locked down. Switch branches and you have the dependencies configured there. Assuming you have already installed them, you're good to go. Otherwise you will need to either `lix download` or `haxe --run install-libs` (which both do *exactly* the same) to grab the files. If the dependencies were installed through lix, then it left enough information behind to download missing sources.

## Installation

You will require [haxeshim](https://github.com/lix-pm/haxeshim) for lix to function. Because on its own haxeshim cannot compile haxe code, it is advisable to use [switchx](https://github.com/lix-pm/switchx).
  
A simple setup using npm:
  
```
npm i haxeshim -g
npm i switchx -g
switchx install latest
npm i lix.pm -g
```

When installing haxeshim on Windows, please make sure that no haxe processes are currently running. When installing on other platforms, please make sure that the `haxe` command installed by haxeshim has precedence over other commands you may have installed.

## Scoping

The scope for versioning is based on the location of the `.haxerc` file that is used by haxeshim. Use `switchx scope create` to create a new scope.

## Downloading and Installing Libraries

Currently, you can download and install libraries from urls, with the following schemes:
  
- `http:<url>` or `https:<url>` - will get the library from an arbitrary URL ... you should be reasonably sure that the targeted resource never changes.
- `haxelib:<name>[#<version>]` - will get the library from haxelib, either the specific version 
- `github:<owner>/<repo>[#<brach|tag|sha>]` - will get the library from GitHub
- `gh:...` an alias for `github`

Note that for github you can specify credentials using --gh-credentials parameter. Be warned though that these credentials are then baked into the hxmls as well. Be very careful about using this option.

### Aliasing

You can always download a library under a different name and version, example:
  
```
lix install gh:lix-pm/lix as othername#1.2.3
```

You will find the following `othername.hxml` in your `haxe_libraries`:

```
# @install: lix download https://github.com/lix-pm/lix/archive/e8a1984b20f8ee38a5e9362fd602b377eceff50e.tar.gz as othername#1.2.3/e8a1984b20f8ee38a5e9362fd602b377eceff50e
-D othername=1.2.3
-cp ${HAXESHIM_LIBCACHE}/othername/1.2.3/e8a1984b20f8ee38a5e9362fd602b377eceff50e/src
```
