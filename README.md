iectrl
======

Command line interface and [Node](http://nodejs.org) module for managing
[ievms](http://xdissent.github.io/ievms) virtual machines.

[![NPM version](https://badge.fury.io/js/iectrl.png)](http://badge.fury.io/js/iectrl)


Requirements
------------

For ievms:

* [VirtualBox](http://virtualbox.org)
* Curl (Ubuntu: `sudo apt-get install curl`)
* Linux Only: unar (Ubuntu: `sudo apt-get install unar`)

For iectrl:

* [Node](http://nodejs.org)


Installation
------------

Globally:

```sh
$ sudo npm install -g iectrl
```

Locally:

```sh
$ npm install iectrl
```


Usage
-----

### Command Line Interface

The `iectrl` command provides various sub-commands for manipulating one or many
ievms virtual machines. The optional `names` argument may be a comma-separated
(**no spaces**) list of virtual machine identifiers. The identifiers consist of 
a number representing a given version of IE, an OS name 
(`WinXP/Vista/Win7/Win8`), or an exact virtual machine name (`IE6 - WinXP`, 
`IE7 - Vista`). See `iectrl <sub-command> --help` for more information:

```sh
$ iectrl --help

  Usage: iectrl [options] [command]

  Commands:

    clean [names] restore virtual machines to the clean snapshot
    close [names] close all running IE processes in virtual machines
    install [options] [names] install virtual machines with ievms
    nuke [names] remove all traces of virtual machines
    list         list available virtual machines
    open [options] [names] [url] open a URL in IE
    rearm [options] [names] rearm virtual machines
    reinstall [options] [names] reinstall virtual machines
    restart [options] [names] restart virtual machines
    screenshot [names] [output] save screenshots for virtual machines
    shrink [options] [names] shrink disk usage for virtual machines
    start [options] [names] start virtual machines
    status [options] [names] report the status of one or more vms
    stop [options] [names] stop virtual machines
    uninstall [options] [names] uninstall virtual machines
    uploaded [names] report the last time the VM was uploaded to modern.ie

  Options:

    -h, --help     output usage information
    -V, --version  output the version number
```


### Node Module

See the [annotated source](http://xdissent.github.io/iectrl) or [karma-ievms](http://xdissent.github.io/karma-ievms) for usage examples.


Examples
--------

Install all `WinXP` virtual machines from ievms (`IE6 - WinXP`, `IE7 - WinXP`, 
`IE8 - WinXP`):

```sh
$ iectrl install WinXP
```

Reinstall all `Win7` virtual machines, plus IE 6 (`IE6 - WinXP`):

```sh
$ iectrl reinstall 6,Win7
```

Shrink the disk usage for IE10 by removing the `.ova` file used during install:

```sh
$ iectrl shrink 10
```

Open IE version 6 and 8 and navigate to `http://modern.ie` auto-starting the
virtual machines if necessary:

```sh
$ iectrl open -s 6,8 http://modern.ie
```

Take a screenshot of the `IE7 - Vista` virtual machine, saving it to 
`./shots/IE7 - Vista.png`:

```sh
$ iectrl screenshot 'IE7 - Vista' ./shots
```

Close all open IE browser windows:

```sh
$ iectrl close
```
