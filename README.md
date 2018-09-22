# compile node helper

<p>
  <a href="https://travis-ci.org/Thomazella/compile-node-helper"><img src="https://img.shields.io/travis/Thomazella/compile-node-helper/master.svg?style=flat-square" alt="Build Status" /></a>
  <a href="https://github.com/prettier/prettier">
    <img alt="code style: prettier" src="https://img.shields.io/badge/code_style-prettier-ff69b4.svg?style=flat-square">
  </a>
</p>
<br/>

> Helps you compile Node.js from source by automating what should be automated

## Usage

Clone the repo and `cd` into it.

To start and choose version interactively.

```sh
./main.bash
```

To skip interaction and download version.

```sh
./main.bash --version=x.x.x
```

Clean script files on `~/.compile-node-helper`

_includes previously compiled node versions!_

```sh
./main.bash --clean
```
