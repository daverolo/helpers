# Helper Scripts

This repo contains just a few (for example bash) scripts that makes setups, updates, backups or similar tasks a bit easier.

The "global" folder contains scripts that can be executed on almost any machine with bash support (e.g: `installdocker.sh`).
Folders starting with `machine-*` contain scripts that are used for a specific machine.

## Example to run scripts via download

```
cd ~
wget https://github.com/daverolo/helpers/blob/main/core/myscript.sh
bash myscript.sh
```

## Example to run a scripts via checkout

```
cd ~
git clone https://github.com/daverolo/helpers.git
cd helpers/machine-x
bash myscript.sh
```
