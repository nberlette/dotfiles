# <img src="https://cdn.berlette.com/svg/dotfiles.svg" alt="." height="44" align="left"> `dotfiles`

These are just my personal dotfiles that I've converted into a starter template for other developers like yourself. If you like everything the way it is, just use this repository as-is. However, you're probably better off [generating your own dotfiles reposistory](https://github.com/nberlette/dotfiles/generate) using this as a template, so you can freely add/remove files and tweak things exactly as you like.

## Gitpod: Automated Install

The setup is really simple - just add this repository URL to your [Preferences in Gitpod's Dashboard](https://gitpod.io/preferences). 

> Screenshot of the dotfiles option's location in the dashboard is included below.

Whenever you fire up a new workspace, Gitpod will clone and install the dotfiles for you ahead of time. This means you can get right into coding, rather than being forced to configure your terminal and such on each new workspace.

**Open your [Gitpod Dashboard](https://gitpod.io/dashboard)**, and add this url to the field at the **bottom of the page**:

       https://github.com/nberlette/dotfiles.git
       
All the files will be located in `~/.dotfiles` (`/home/gitpod/.dotfiles`) inside a Gitpod Workspace. You'll nice the `.git` folder is still intact, giving you access to the commit history and remote origin, so it's really hassle-free to commit and push some changes right from with a running workspace!

### Updating while in a running workspace

If you're running a workspace already and for some reason your remote origin has updated externally, try this:

```bash
cd ~/.dotfiles && git pull
```

### Something broken? Check the logs.

If you're encountering a bug or something just isn't working correctly, you can check logs in two places. Gitpod stores a log file located at `~/.dotfiles.log`, which may shed some light on what's going on during the install process when your workspaces are being built. Otherwise, the `install.sh` script pipes its stderr to timestamped files inside of the `~/.dotfiles` folder:

```bash
# logs are stored in timestamped files
cd ~/.dotfiles
ls .*.log

# .install.1650326691.log
# .install.1650325105.log
```

### Location in the Gitpod Dashboard 

<img width="600" alt="Screen Shot 2022-04-18 at 4 24 54 PM" src="https://user-images.githubusercontent.com/11234104/163892596-e240193e-9fe0-442c-8f71-329c6d69dfe3.png">

---  

## Manual Installation

Want to install these dotfiles on an already-running workspace? That's cool too! Before proceeding to install them manually, you need to copy the files from this repository to your workspace.

### Clone the repo

```bash
gh repo clone nberlette/dotfiles ~/.dotfiles
```

```bash
git clone --depth 1 https://github.com/nberlette/dotfiles.git ~/.dotfiles
```

### Run `install.sh`

```bash
cd ~/.dotfiles && ./install.sh
```

---

MIT © [Nicholas Berlette](https://github.com/nberlette). Overly inspired by [`jessfraz/dotfiles`](https://github.com/jessfraz/dotfiles). Thanks Jess!

