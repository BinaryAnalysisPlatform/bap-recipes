Note: this repository is currently being updated, expect lots of changes in the upcoming few days. This README
is also WIP.

# Introduction

This repository provides a collection of ready to use binary analysis tools,
as well as a framework and a conventional repository structure for developing
new tools. Think of it as BAP on Rails. This repository should be seen as a collaboration
platform encouraging everyone to fork it, implement an analysis, and share it back with
the community. PRs are very welcomed and accepted with no questions asked.

# Table of Contents

- [Installation](#installation) - how to install all or some tools
- [Usage](#usage) - how to run tools and analyze results
- [Developing](#developing) - how to develop a new tool
- [Contributing](#contributing) - how to contribute a new tool
- Tools
  - checks from the [Joint Strike Fighter coding standards](http://stroustrup.com/JSF-AV-rules.pdf)
    - [av-rule-3](av-rule-3/descr) - all functions have a cyclomatic complexity less than 20
    - [av-rule-17](av-rule-17/descr) - `errno` is not used as an error indicator
    - [av-rule-19](av-rule-19/descr) - `setlocale` et all functions are not be used
    - [av-rule-20](av-rule-20/descr) - `setjmp`/`longjmp` are not be used
    - [av-rule-21](av-rule-21/descr) - signal handling facilities of `<signal.h>` are not be used
    - [av-rule-22](av-rule-22/descr) - The input/output library `<stdio.h>` shall not be used
    - [av-rule-23](av-rule-23/descr) - `atof`, `atoi`, and `atol` are not be used
    - [av-rule-24](av-rule-24/descr) - `abort`, `exit`, `getenv` and `system` are not be used
    - [av-rule-25](av-rule-25/descr) - the `<time.h>` interface is not used
    - [av-rule-174](av-rule-174/descr) - potential null pointer dereferencings
    - [av-rule-189](av-rule-189/descr) - `goto` statements are not used
  - checks from the [JPL Institutional Coding Standard](http://bsivko.pbworks.com/w/file/fetch/68132300/JPL_Coding_Standard_C.pdf)
    - [jpl-rule-4](jpl-rule-4/descr) - no recursive functions
    - [jpl-rule-11](jpl-rule-11/descr) - `goto` statements are not used
    - [jpl-rule-14](jpl-rule-14/descr) - return values of all non-void functions are used
  - [defective-symbols](defect-symbol/descr) - detects all defective symbols from the av-rule-{3,17,19,20,21,22,23,24,25,189} and jpl-rule-4
  - [primus-checks](primus-checks/descr) - an all-in-one analysis that uses Primus to identify the following CWE:
    - CWE-122 (Buffer Overwrite)
    - CWE-125 (Buffer Overread)
    - CWE-416 (Use after free)
    - CWE-415 (Double free)
    - CWE-798 (Use of Hard-coded Credentials)
    - CWE-259 (Use of Hard-coded Password)
    - CWE-822 (Untrusted Pointer Dereference)
    - CWE-291 (Relience on IP Address for Authentication)
    - CWE-170 (Improper Null Termination)
    - CWE-138 (Improper Neutralization)
    - CWE-74  (Command Injection)
    - CWE-476 (NULL pointer dereference)
    - CWE-690 (Unchecked Return Value to NULL Pointer Dereference)
    - CWE-252 (Unchecked Return Value)



## Installation

Although the recipes from this repository are installed by default in
binary and opam installations, it is useful to update them, as it is this
repository could move faster than the BAP release cycle. To install all
recipes to the default share folder just do


        ./install.sh


The script will install to the currently activated OPAM switch, if such
exits, otherwise it will install to the `/usr/local/share/bap` folder. To install
to a specific folder just pass it to the script, e.g.,

       ./install.sh <destination>

To install a specific recipe pass its name (the folder name) after the destination,
e.g.,

       ./install.sh <destination> <recipe>


# Usage

To use the installed recipe just pass its name to the `--recipe` option, e.g.,

       bap ./exe --recipe=primus-checks


To list available recipes, use

       bap --list-recipes

To peek into the details of a recipe pass its name to the `--show-recipe` option, e.g.,

       bap --show-recipe=primus-checks

If a recipe has parameters then they could be specified as colon
separated list of <key>=<value> pairs. See the --recipe parameter in
`bap --help` for more information.


# Developing

## Making Recipes

A recipe is either a single file or a directory (optionally zipped)
that contains a parametrized specification of command line parameters
and support files if necessary.

The main (and the only necessary) part of a recipe is the recipe
specification, that is a file that contains a list of recipe items in
an arbitrary order. Each item is either a command line option, a
parameter, or a reference to another recipe. All items share the same
syntax - they are flat s-expressions, i.e., a whitespace separated list
of strings enclosed in parentheses. The first string in the list
denotes the type of the item, e.g.,

        (option run-entry-points malloc calloc free)


The `option` command requires one mandatory parameter, the option name,
and an arbitrary number of arguments that will be passed to the
corresponding command line option. If there are more than one argument
then they will be concatenated with the comman symbol, e.g.,

        (option opt a b c d)

will be translated to

        --opt=a,b,c,d

Option arguments may contain _substitution symbols_. A subsitution
symbol starts with the dollar sign, that is followed by a named
(optionally delimited with curly braces, to disambiguate it from the
rest of the argument). There is one built in parameter `prefix`,
that is substituted with the path to the recipe top folder.

The `parameter` command introduces a parameter to the recipe, i.e., a
variable ingredient that could be changed when the recipe is used. The
`parameter` command has 3 arguments, all required. The first argument is
the parameter name, the second is the default value, that is used if
the parameter wasn't set, and the last argument is the parameter
description. The substitution symbol will be replaced with the default
value of a parameter, if a value of the parameter wasn't passed through
the command line. Example,

    (parameter depth 128 "maximum depth of analysis")
    (option analysis-depth $depth)


If the parameter is not set through the command line, then it will be
substituted with `128` otherwise it will receive whatever value a user
has passed.

Finally, the `extend` command is like the `#include` statement in the C
preprocessor as it includes all the ingredients from another
recipe. (Make sure that you're not introducing loops!). The command
has one mandatory argument, the name of the recipe to include.

## The recipe file grammar

           recipe ::= {<recipe-item>}
           recipe-item ::= <option> | <parameter> | <extend>
           option ::= (option <atom> {<atom>})
           parameter ::= (parameter <atom> <atom> <atom>)
           extend ::= (extend <atom>)
