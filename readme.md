# <img src="https://cdn.berlette.com/svg/dotfiles.svg" alt="." height="44" align="left"> `dotfiles`

Some personal preferences for my dev workspaces on Gitpod.io (and local macOS machines).

## Installation

Before installing, you need to copy the files from this repository to your development machine.

### Automated (thanks to Gitpod)

This cloning (and install process) can now be done automatically by Gitpod for **every workspace**! Open your [Gitpod Dashboard](https://gitpod.io/dashboard), and add this url to the `Dotfiles` preference input field at the bottom of the page:

    https://github.com/nberlette/dotfiles.git

Whenever you fire up a new workspace, Gitpod will copy the latest version of `dotfiles` and pre-install everything for you ahead of time.

### Manually Installing

Want to install these dotfiles on an already-running workspace? That's cool too! Before proceeding to install them manually, you need to copy the files from this repository to your workspace.

Here's a few popular methods:

<details open><summary><strong><code>degit</code></strong> (recommended)</summary>

```bash
degit nberlette/dotfiles ~/.dotfiles
```

</details>
<details open><summary><strong><code>gh</code></strong> (github cli)</summary>

```bash
gh repo clone nberlette/dotfiles ~/.dotfiles
```

</details>
<details><summary><strong><code>git</code></strong> (available almost everywhere)</summary>

```bash
git clone --depth 1 https://github.com/nberlette/dotfiles.git ~/.dotfiles
```

</details>

---

<br>

## Run the installer

```bash
cd ~/.dotfiles && ./install.sh
```

Have fun!

If you have any ideas or find a bug, please submit a PR - contributions are welcome!!

---

MIT © [Nicholas Berlette](https://github.com/nberlette). Overly inspired by [`jessfraz/dotfiles`](https://github.com/jessfraz/dotfiles). Thanks Jess!

