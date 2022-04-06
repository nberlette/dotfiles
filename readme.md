# `gitpod + dotfiles = `***`podfiles`***

Some personal preferences for workspaces on Gitpod.io

## Installation

Before installing, you need to copy the files from this repository to your development machine.  

### Automated (by Gitpod)

This cloning (and install process) can now be done automatically by Gitpod for **every workspace**! Open your [Gitpod Dashboard](https://gitpod.io/dashboard), and add this url to the `Dotfiles` preference input field at the bottom of the page:

    https://github.com/nberlette/podfiles.git

Whenever you fire up a new workspace, Gitpod will copy the latest version of `podfiles` and pre-install everything for you ahead of time.

### Manually Installing

Want to install these dotfiles on an already-running workspace? That's cool too! Before proceeding to install them manually, you need to copy the files from this repository to your workspace.

Here's a few popular methods:  

<details open><summary><strong><code>degit</code></strong> (recommended)</summary>

```bash
degit nberlette/podfiles ~/.dotfiles && cd ~/.dotfiles
```

</details>
<details><summary><strong><code>gh</code></strong> (github cli)</summary>

```bash
gh repo clone nberlette/podfiles ~/.dotfiles && cd ~/.dotfiles
```

</details>
<details><summary><strong><code>git</code></strong> (available almost everywhere)</summary>

```bash
git clone --depth 1 nberlette/podfiles ~/.dotfiles && cd ~/.dotfiles
```

</details>


## Run the installer

You can directly run the `install.sh` script, or use the `make` command to cherrypick features.

```bash
./install.sh

# or using make:
make install
```

## License

MIT © [Nicholas Berlette](https://github.com/nberlette).

### Acknowledgements

Heavily inspired by [`jessfraz/dotfiles`](https://github.com/jessfraz/dotfiles). Thanks Jessica!

