[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/lix-pm/Lobby)

# lix - a dependable package manager for your Haxe projects

lix is a package manager that makes it easy for you to track dependencies used in your Haxe project, and to make sure everyone always has the right versions when they build your app.

- lix tracks everything in version control so you know exactly when and how a dependency changed. As a result:
  - lix helps you avoid "software erosion", so that when you come back to a project 6 months later on a different computer, you can still get things compiling exactly as they did last time you were working on it.
  - lix makes it easy to collaborate with other developers even when dependencies are changing regularly.
- lix works with all existing haxelibs, as well as dependencies hosted on GitHub or GitLab.
- lix lets you switch branches and update the dependencies much faster than haxelib.
- lix installs dependencies faster than haxelib.

The core proposition of lix is that **all dependencies should be fully locked down and versioned, so that every state can be reliably replicated.**

To track dependencies, lix leverages the conventions put forth by [haxeshim](https://github.com/lix-pm/haxeshim). This means that for each dependency, there is a `<libName>.hxml` in the project's `haxe_libraries` folder. In addition to putting all required compiler arguments into a library's hxml, lix also leaves behind installation instructions that allow to redownload the exact same version on another machine. If you check out any particular state of a project, then `lix download` will download any missing library versions.

You can depend on lix to manage your haxe dependencies.

---

## Contents

- [Installation](#installation)
- [Usage](#usage)
    - [Downloading all dependencies](#downloading-all-dependencies)
    - [Adding a new dependency](#adding-a-new-dependency)
    - [Aliasing](#aliasing)
    - [HXML files](#hxml-files)
    - [Version control](#version-control)
    - [Local development](#local-development)
- [Concepts](#concepts)
- [FAQ](#faq)
- [Help and support](#help-and-support)
- [Contributing](#contributing)

---

## Haxe Shim

Before we get started: lix is made to work on top of Haxe Shim. [You can read more about it here](https://github.com/lix-pm/haxeshim), but essentially, you can think of it just normal Haxe with a slightly tweaked cli. What it does is to replace the tight coupling in the haxe toolchain in favor of simple conventions:

- decouple the haxe command from the haxe compiler (which are right now the very same thing) and instead use project specific configuration of the Haxe version, meaning that you can seamlessly have different Haxe versions in different projects on the same machine and also ensure that the same project will use the same Haxe version across different machines
- decouple Haxe from Haxelib (which are right now tied at the hip) and instead use project specific configuration of dependencies in a simple hxml-based format. Any tool capable of writing these hxmls can thus supply dependencies to the project. Moreover, this setup also ensures frictionless use of different dependency  versions in different projects and reliable replication of dependency versions across separate machines.

## Installation

lix is installed through npm (or yarn). If you don't have one of these installed, you can find out [how to install NodeJS and NPM here](https://nodejs.org/en/download/).

To install lix:

    npm install --global lix

After this you will have the commands `lix`, `haxe`, `haxelib` and `neko` available.

For each project you want to use lix for, you should create a "scope":

    lix scope create
    lix use haxe stable

This will create a ".haxerc" in the cwd, saying we should use the current stable Haxe version for this project. It will also tell Haxe Shim that this project should expect to find information about haxelibs in the "haxe_libraries" folder.

## Usage

### Downloading all dependencies

    lix download

This will make sure all dependencies are installed and on the right versions. It will also fetch neko and the project specific haxe version.

You should use this after using `git clone`, `git pull`, `git checkout` and similar commands.

### Adding a new dependency

    lix install <scheme>:<library>

The schemes you can use include haxelib, github, gitlab, and http/https:

- `haxelib:<name>[#<version>]` - will get the library from haxelib, either the specific version or the latest. Use `--haxelib-url <url>` (either an https or http url) to use a different server consistently. You may also use `haxelib://custom.server[:<port>]/<name>[#<version>]`, but in that case further dependencies will again be resolved against the official haxelib. If you leave the port unspecified, https assumed, otherwise http.
- `github:<owner>/<repo>[#<branch|tag|sha>]` - will get the library from GitHub, either master or a specific branch/tag/commit.
- `gh:...` an alias for `github`
- `gitlab:<owner>/<repo>[#<branch|tag|sha>]` - will get the library from GitLab. Use `gitlab://custom.server/<owner>/<repo>[#<branch|tag|sha>]` to get it from a server of your choice.
- `http:<url>` or `https:<url>` - will get the library from an arbitrary URL, pointing to a haxelib zip file... you MUST BE reasonably sure that the targeted resource NEVER changes. (For example, if the filename is "mylib-latest.zip", it will probably change. If it is "mylib-v1.0.0.zip", it is reasonably likely to not change).

Note that for github and gitlab you can specify credentials using the `--gh-credentials` and `--gl-private-token` parameters respectively. Be warned though that these credentials are then baked into the hxmls as well. Be very careful about using this option.

### Aliasing

You can always download a library under a different name and version, example:

```
lix install haxelib:tink_core as othername#1.2.3
```

You will find something like the following `othername.hxml` in your `haxe_libraries`:

```hxml
# @install: lix --silent download "haxelib:tink_core#1.16.1" into tink_core/1.16.1/haxelib
-D othername=1.2.3
-cp ${HAXESHIM_LIBCACHE}/tink_core/1.16.1/haxelib/src
```

### Hxml files

Once you've installed a dependency with lix and it exists in your `haxe_libraries` folder, you can add it to your haxe build (hxml file) with:

    -lib mylibrary

where "mylibrary" has a valid file in `haxe_libraries/mylibrary.hxml`.

It's worth noting that we don't include the haxelib version in the hxml anymore, so doing this:

    -lib mylibrary:1.0.0

is no longer accepted.

### Version control

We recommend you add the entire `haxe_libraries` folder to your version control. For example, if you're using git:

    git add haxe_libraries

Then every time you change a dependency with lix, you should commit those changes to git.

Every time you switch branches, pull, merge, or clone a new repo, if the files in "haxe_libraries" have changed, you should re-run:

    lix download

(A fun fact: despite the name, `lix download` often doesn't have to download anything, especially if you've used those dependencies before, as they will be cached. This makes switching branches and syncing dependencies incredibly fast and painless).

### Local development

If you develop your own haxelibs, you might be used to using `haxelib dev` to tell haxelib to use a local folder rather than a downloaded library while you develop your library, so that changes you make in the local folder are always used in the next build.

With lix, there is no command to do this, you just edit the relevant hxml file.

For example, change `haxe_libraries/tink_core.hxml` from:

```hxml
# @install: lix --silent download "haxelib:tink_core#1.15.0" into tink_core/1.15.0/haxelib
-D tink_core=1.15.0
-cp ${HAXESHIM_LIBCACHE}/tink_core/1.15.0/haxelib/src
```

to:

```hxml
# @install: lix --silent download "haxelib:tink_core#1.15.0" into tink_core/1.15.0/haxelib
-D tink_core=1.15.0
-cp /home/jason/workspace/tink_core/src/
```

When you do this, it will show up as a modified file in git. You should avoid commiting this change, as it won't work for anyone else who wants to use your project but doesn't have the exact same project in the exact same location.

Instead, once you've finished the work on your dependency, (even if it's a work in progress), push your changes to Github, and then use that:

    lix install github:haxetink/tink_core#my_work_in_progress_branch

This way if anyone else wants to use your work-in-progress, they'll be able to.

## Concepts

lix was designed based on a few key concepts that we believe have helped package managers for other languages be successful. Understanding these concepts can help you understand the way lix works.

- **Every haxe dependency is easy to find, look in `haxe_libraries/${libName}.hxml`.**

    We learned this lesson from NodeJS, where there are simple rules to find dependencies - NodeJS expects each dependency to be a folder inside "node_modules". Because NodeJS just looks in that folder, it has allowed both NPM and Yarn, competing package managers, to operate side by side, allowing innovation, competition and collaboration between the projects.

    In Haxe, this was hard because the Haxe compiler didn't know how to find the dependencies, it ran haxelib to find out where they are. Breaking this apart is one of the things Haxe Shim does, by intercepting any "-lib" arguments and replacing them with "-cp" arguments based on a simple standard.

    What's the standard Haxe Shim expects (and that lix provides)?

    There is a "haxe_libraries" folder, and inside it is one hxml file for each dependency. When haxe wants to use "tink_core", it looks for "haxe_libraries/tink_core.hxml", and then uses all of the arguments, class paths and defines from that hxml file in the haxe build.

- **You can run one command, `lix download` to get all of your dependencies installed after cloning, pulling or checking out a branch.**

    The hxml files lix generates have information about how to install the dependency - from haxelib, GitHub, GitLab, or Http. This allows it to rebuild the exact same environment it is expecting, whether you are switching branches, revisiting old code or cloning a repo for the first time.

    Just run `lix download` and your dependencies will be perfectly in sync.

    On top of downloading the necessary libraries, lix will also download the right Haxe version and make sure neko is available too.

- **Your entire `haxe_libraries` folder should be tracked in version control.**

    NPM and Yarn have a package.json file. Yarn has a yarn.lock file. Hmm has a "hmm.json" file. With lix, you just commit the whole "haxe_libraries" folder to version control, making it easy to track any changes to dependency versions.

    This means whenever you switch branches, pull an update or merge changes it is easy to get the exact dependencies in sync.

    It also means that if you are hacking away on a development version of a library, `git status` will remind you that the library you're editing is using a non-standard classpath, a hint that you should correct it before pushing your changes.

- **Dependency versions should be scoped to each project, rather than global.**

    Haxelib eventually supported this with `haxelib newrepo` and a hidden `.haxelib/` folder.

    With lix and Haxe Shim, we look for the `haxe_libraries/` folder in the same place as the `.haxerc` file.

    This is why you call `lix scope create` when you introduce lix to your project - it creates the `.haxerc` file that tells Haxe Shim to look here for the `haxe_libraries/` folder.

## FAQ

### What does this do differently to haxelib?

Haxelib was built many years ago, before npm even existed. It was great at first, but suffers from a few limitations:

- The only thing tracked in version control is your hxml files, which works when you install libraries directly from Haxelib, but is very hard to manage when installing dependencies from GitHub etc.
    - This made it difficult to use when you had to use unreleased versions of a library, or a fork of a library.
    - This also failed to track the exact versions of dependencies, meaning even if the right version of `tink_macro` was installed, the wrong version of `tink_core` might be installed, etc.
- The way haxe and haxelib are tightly coupled makes it difficult to maintain, so development has really stalled for several years. (Haxe Shim breaks this dependency by instead using a standardised way to locate information about dependencies, making it much easier to build a tool like lix.)
- Juraj, who started lix, was actually the main maintainer of Haxelib for about two years, and resolved that replacing it was a more effective plan than trying to improve it.

### How does this compare to hmm?

Hmm is another tool that aims to improve package management for haxe projects. It does this by storing version information and installation instructions in "hmm.json", allowing you to restore state based on those instructions.

It's a big step forward from Haxelib, but we think lix is a step forward again.

Reasons you might prefer hmm:

- you do not want to install NodeJS or NPM.
- you do not want to use Haxe Shim, you'd prefer to use normal Haxe and normal Haxelib.

Reasons you might prefer lix:

- Hmm install tracks the dependencies you installed directly, but it doesn't track the sub dependencies, so it's possible when you restore a project the sub-dependency versions might change. In this way builds aren't reproducible and your project might still be subject to "software erosion"
- Hmm still uses Haxelib to run the installs, and lix is much faster than Haxelib.

### Is this similar to npm / yarn / cargo / $packageManager?

lix has taken inspiration from each of these package managers, and tries to learn lessons from each. It is not exactly the same in its implementation as any other package manager.

For example, like npm lix will know how to install dependencies from GitHub, which is great for using unreleased development versions.

Like yarn, lix will cache the exact versions installed, including the exact versions of all dependencies, the exact commit SHAs for any dependencies loaded from Github, and more, meaning you have a reproducible build.

Unlike either, lix does not make a local copy of each library inside a folder in your project, preferring instead to keep the source code in a global folder, to save install time and disk space.

### Can I use these tools without installing them globally?

Yes, assuming your project has a `package.json`. If not, you can create it by:

- `echo "{}" > package.json` (will just create an empty file)
- `npm init` (will take you through the whole setup process)

With that in place, install lix just skipping the "-g" option:

    npm install lix --save

And then you can run each of the commands with:

```
npx lix
npx haxe
npx haxelib
npx neko
```

Not that npx requires you to either have npm >= 5.2.0 or installing it via `npm i -g npx` (use sudo as appropriate).

If you prefer yarn:

    yarn add lix

And then

    yarn lix
    yarn haxe
    yarn haxelib
    yarn neko

Consider adding this to your `package.json`, for frictionless intallation:

```json
"scripts": {
    "postinstall": "lix download"
}
```

This will make sure lix installs its packages every time npm or yarn installs their packages.

## Help and support

If you find a bug or have an issue, please [file an issue on GitHub](https://github.com/lix-pm/lix.client/issues/new).

If you would like to chat through an issue, you can often find someone helpful [on our Gitter channel](https://gitter.im/lix-pm/Lobby).

We try to be friendly!

## Contributing

We welcome contributions - whether it's to help triage GitHub issues, write new features, support other users or improve documentation.

If you would like to know how to help, or would like to discuss a feature you're considering implementing, please reach out to us on Gitter.

Your help will be much appreciated!

# Acknowledgements

Very special thanks to [Geir](https://github.com/zrrrzzt) who was kind to hand over the lix package on npm. From this point forward, that package is now available as [lix-index](https://www.npmjs.com/package/lix-index).
