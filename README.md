# Cscope Module for Textadept

This is a Textadept module for using [Cscope], a tool for developers to quickly search C source code.

> :warning: **WARNING** :warning:
>
> This is an alpha version and I am rebasing on this branch!


## Installation

Install it in your `~/.textadept/modules/` directory and load it from your `~/.textadept/init.lua` as follows:

```lua
_M.cscope = require('cscope')
```


## Cscope Binaries for Windows

You can find Cscope binaries for Windows from the [Cscope-win32 port download page](https://code.google.com/archive/p/cscope-win32/downloads).


## Create a Cscope Index

```
cscope -b -q
```



[Cscope]: http://cscope.sourceforge.net/ "Cscope Homepage"
