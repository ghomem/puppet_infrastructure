# README #

Common baseline Puppet Classes

### What is this repository for? ###

Common baseline Puppet Classes that automate Linux infrastructure.

### What is the License? ###

GPLv3 as defined on the LICENSE file.

### Contribution guidelines ###

* Only tested baseline best practices
* Comments on non-trivial code

### How do I install the pre-commit hook? ###

Install puppet-lint from the repository:

```sudo apt-get install puppet-lint```

In principle you already have ruby installed but if not you can do:

```sudo apt-get install ruby```

Clone the repository and change to its directory, then create a symlink to the pre-commit script:

```cd .git/hooks/ && ln --symbolic --verbose --interactive ../../pre-commit pre-commit ; cd ../..```
