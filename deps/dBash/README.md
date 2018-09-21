# dBash
Declarative bash

## Motivation

Bash is a great tool but it's started to show it's age.
It feels like working with quirky old machine you know all too well.
If only it could be better, smoother, easier to read, some of the boilerplate abstracted away...
Well, dBash is a step in that direction.
It's a collection of simple functions that aim to make your life easier.

## Functions provided

### noop

A function that exits with `0`. Works just like `true`.

### exitwith

Returns the argument as an exit code.
```sh
exitwith 33
echo $?
# 33
```

### exitstatus

Returns the last command's exit code. Wrapper around `$?`.
```sh
false
if exitstatus; then echo "won't run"; fi
```

### iflast

Runs a command if the last command exited with `0`.
```sh
cd ~
cd /some/dir/iwant/gone
iflast rm -rf * .*
# don't delete your home.
```

### not
Runs a command and returns the opposite exit code: `0` for non-zero and vice-versa.
Works just like `!`.
```sh
if not false; then echo "will run"; fi
```

### ok
Takes a [predicate](https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html) and evaluates it with `test`. Works just like `[ predicate ]`.
```sh
if ok -f ~/myfile; then echo "do things with ~/myfile"; fi
```

### ternary
C, JavaScript style conditional _aka ternary_ operator. `condition ? true expression : false expression`. If `expression` is a command, it's run. Else it's appended to `printf` and it works like a value.
```sh
# commands
ternary "$maybeNull" ? echo "not null" : exitmessage "invalid value"
ternary "${#word}" -gt 10 ? warning "word too long" : save "$word"
# assignment
local name=$(ternary $user ? ${user[name]} : "you")
```
No support for regexes, yet.<br/>
`?` and `:` must be surrounded by whitespace.

### ifdo
Takes arguments `condition : command`. Command is run if condition is true. Condition is a [test predicate](https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html). Works just like a one-line if [ ] statement.
```sh
ifdo -f ~/myfile : echo "do things with ~/myfile"
```
`:` must be surrounded by whitespace.

### status
Runs a command and prints it's exit status. Supply command to run as argument or call status after it.
```sh
fail() {
  # exits with 129
}

status fail "is this failing? what's the exit code?"
# 129

fail; status
# 129

unalias la
status la
# 127
```
Command `sdtout` and `stderr` are redirected away.

### mute
Runs a command and suppresses it's output. Takes the file descriptor to mute as first argument. Defaults to muting `stdout` and `stderr`.

```sh
mute echo "nope"
# nothing prints

mute somethinginvalid
# nothing prints

mute 2 echo "nope"
# prints "nope", stderr is redirected away

mute 1 somethinginvalid
# prints "command not found", stdout is redirected away

```
Command `sdtout` and `stderr` are redirected away.

### and
Evals arguments until one exits with `> 0`. Works just like `&&`.
```sh
and true true true false; status
# prints 1

and 'printf hello' 'printf _' 'printf world\n'
# prints hello_world
```

### or
Evals arguments until one exits with `0`. Works just like `||`.
```sh
or true true true false; status
# prints 0

or 'printf hello' 'printf _' 'printf world\n'
# prints hello
```

### iscommand
Exits with `0` if command is a system executable. Works just like `command -v`.
```sh
iscommand curl && curl -o #make some downloads
```