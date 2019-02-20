# environment tools

We find our selves doing the same things over and over, no?

This tries to solve that.

## Please, explain.

Ok here is the situation, doing some research and you want to keep a link you found in the project `README`. As you should.

The project folder is not open, so you need to go to that project and open the `README` find were to place the link and formatted in markdown style with the `[ ]()`.

**It's kinda of annoying.**

So you think a simple script like this could fix it

```bash
#!/usr/bin/env bash
URL=$1
DESCRIPTION=$2
FILE=$3

echo "- [${DESCRIPTION}](${URL})" >> $FILE
```

**perfect**

...Now you just need to somehow make it available everywhere right?
No problem, use the install-local, and it will create a symlink in the `/urs/local/bin` pointing to where ever your script is.

```bash
install-local mdlink
```

and now next time you want to quickly store a link you can just call

```bash
mdlink tellart.com tellart README.md
```

## what else is here

#### aliashere
Simply add an alias to the current directory
```
aliashere mydir
```
and next you log in you can just type `mydir` and it will take you to that directory.

#### install-local

If you developed a new script and want to make it global, from the directory where this script is do:
```bash
install-local my-script
```
- [check if directory exist](https://tecadmin.net/bash-shell-test-if-file-or-directory-exists/)
