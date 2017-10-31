[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/lix-pm/Lobby)

# lix - the haxe package manager that rox ... ba-dum-tss ...

In a nutshell, lix is an attempt to get dependency management right, building on lessons learnt from looking at NPM, Cargo and failure to move haxelib forward. The core proposition of lix is that **dependencies should be fully locked down and versioned, so that every state can be reliably replicated.**

To track dependencies, lix leverages [haxeshim](https://github.com/lix-pm/haxeshim). This means that for each dependency, there is a `<libName>.hxml` in the project's `haxe_libraries` folder. In addition to putting all required compiler arguments into a library's hxml, lix also leaves behind installation instructions that allow to redownload the exact same version on another machine. If you check out any particular state of a project, then `lix download` will download any missing library versions.

## Installing Lix

You will require [haxeshim](https://github.com/lix-pm/haxeshim) for lix to function. Because on its own haxeshim cannot compile haxe code, it is advisable to use [switchx](https://github.com/lix-pm/switchx).
  
A simple setup using npm:
  
```
npm i haxeshim -g
npm i switchx -g
switchx install latest
npm i lix.pm -g
```

When installing haxeshim on Windows, please make sure that no haxe processes are currently running. When installing on other platforms, please make sure that the `haxe` command installed by haxeshim has precedence over other commands you may have installed.

### Local installation

It is possible to install the whole stack through npm without `-g` - just keep in mind that you will have to invoke `haxe` through npm then. 

## Scoping

The scope for versioning is based on the location of the `.haxerc` file that is used by haxeshim. Use `switchx scope create` to create a new scope.

## Downloading and Installing Libraries

Currently, you can download and install libraries from urls, with the following schemes:
  
- `http:<url>` or `https:<url>` - will get the library from an arbitrary URL ... you MUST BE reasonably sure that the targeted resource NEVER changes.
- `haxelib:<name>[#<version>]` - will get the library from haxelib, either the specific version or the latest
- `github:<owner>/<repo>[#<brach|tag|sha>]` - will get the library from GitHub
- `gh:...` an alias for `github`
- `gitlab:<owner>/<repo>[#<brach|tag|sha>]` - will get the library from GitLab

Note that for github and gitlab you can specify credentials using the `--gh-credentials` and `--gl-private-token` parameters respectively. Be warned though that these credentials are then baked into the hxmls as well. Be very careful about using this option.

### Aliasing

You can always download a library under a different name and version, example:
  
```
lix install gh:lix-pm/lix as othername#1.2.3
```

You will find the following `othername.hxml` in your `haxe_libraries`:

```
lix download github:lix-pm/lix#9f16f8c0f73262b076f1b5d7b41e514ebfc24fa9 into lix/github/9f16f8c0f73262b076f1b5d7b41e514ebfc24fa9
-D othername=1.2.3
-cp ${HAXESHIM_LIBCACHE}/lix/github/9f16f8c0f73262b076f1b5d7b41e514ebfc24fa9/src
```
