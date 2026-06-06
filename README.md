# Argivo

Declarative command-line framework for Bash scripts.

Argivo turns Bash functions into documented command-line commands through a simple annotation-based syntax.

## Features

* Function-based commands
* Declarative command metadata
* Built-in standard library
* Self-documenting scripts

## Example

```bash
#!/usr/bin/env argivo

# @desc Greet current user.
function main() {
    hello "$USER"
}

# @desc Print a greeting message for a user.
# @param name Name of the user to greet.
function hello() {
    if (($# == 0)); then
        echo "Hello, world!"
    else
        echo "Hello, $1"
    fi
}
```

Once the script is executable, it can be used directly as a command:

```bash
./hello.avo
./hello.avo -hello David
./hello.avo --help
```

No additional argument parsing, or help generation is required.

## Installation

```bash
git clone https://github.com/losedavidpb/argivo-cmd
cd argivo-cmd

./install.bash
rm -rf argivo-cmd
```
