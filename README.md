# Passphraser Scripts
Passphraser is an application which can be used to generate passwords which are both secure and memorable.

A sample generated passphrase looks like this:

```
*password2023security-INCREASED
```

By default, generated passphrases have 3 words, 2 special characters, and a 4-digit number. This provides 78 bits of entropy, which is equivalent to the strength of a fully-random 12-character ASCII password.

The benefit of using Passphraser is that a password like `*password2023security-INCREASED` is much more memorable than `tZ0e4Sc#63$h`, yet it provides the same level of security and only requires you to remember 6 distinct items instead of 12.

If you're looking for the main Passphraser application or want guidance on using Passphraser, you can reference the [Passphraser CLI](https://github.com/80columns/passphraser-cli).

## Setting up Passphraser
This repository contains scripts which implement the Passphraser features & algorithm. Sometimes when working in IT environments, you will be unable to install new applications on a server or workstation. In this situation it's useful to have self-contained scripts which can be copied to the target system as a text file and run in a shell using the built-in operating system utilities. The following scripts are available:

| Shell | Version | File |
| :------: | :-----: | :--: |
| Bash | 5.x | [passphraser.sh](https://github.com/80columns/passphraser-scripts/blob/main/passphraser.sh) |
| PowerShell | 7.x | [passphraser.ps1](https://github.com/80columns/passphraser-scripts/blob/main/passphraser.ps1) |

## Contributing
Any additional script implementations of Passphraser are welcome and appreciated! In order to maintain project consistency, any scripts must implement identical features & the algorithm used by the CLI and existing scripts. You can read about the details of the algorithm at [Passphraser Paper](#).

## Questions
Any questions not answered in this README can be sent to pdf _at_ 80columns.com
