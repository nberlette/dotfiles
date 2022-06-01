---
title: 'dotfiles.ml'
home: true
heroImage: /hero.jpg
heroAlt: 'nberlette/dotfiles'
heroText: 'dotfiles.ml'
tagline: One config to rule them all.
actionText: Get Started
actionLink: /#gitpod-automated-install
features:
  - title: 'Starship Prompt'
    details: 'Have a beautifully consistent shell prompt on any platform.'
  - title: 'GnuPG Ready'
    details: 'Configured for GPG-signed commits right out of the box.'
  - title: 'Gitpod Friendly'
    details: 'Ready to use in Gitpod Workspaces, with zero configuration.'
footer: 'MIT © Nicholas Berlette'
---

# `@nberlette/dotfiles`

## Disclaimers

These are just my personal dotfiles that I've converted into a starter template for other developers like yourself. If
you like everything the way it is, just use this repository as-is.

However, **you're probably better off**
[**_generating your own dotfiles reposistory_**](https://github.com/nberlette/dotfiles/generate). In that scenario,
since this repository will just be the template yours is generated from, you have a lot more freedom to tweak things and
get it exactly as you like.

<br>

> Personally, I really like being able to test the limits of different configurations (typically breaking some stuff in
> the process). I'm not allowed to behave like that in someone else's codebase 😜

<br>

## Gitpod: Automated Install

The setup is really simple - just add this repository URL to your
[Preferences in Gitpod's Dashboard](https://gitpod.io/preferences).

Whenever you fire up a new workspace, Gitpod will clone and install the dotfiles for you ahead of time. This means you
can get right into coding, rather than being forced to configure your terminal and such on each new workspace.

<br>

### Updating Gitpod Preferences

**Open your [Gitpod Dashboard](https://gitpod.io/dashboard)**, and add this url to the field at the **bottom of the
page**:

       https://github.com/nberlette/dotfiles.git

<img width="600" alt="" src="https://user-images.githubusercontent.com/11234104/163892596-e240193e-9fe0-442c-8f71-329c6d69dfe3.png">

<br>

### Locating the dotfiles

All the files will be located in `~/.dotfiles`, or `/home/gitpod/.dotfiles` inside a Gitpod Workspace.

You might notice the `.git` folder is still intact; this gives you access to a truncated commit history, but more
importantly it allows us to pull/push new commits from our remote origin right from a running workspace. This makes it
pretty painless to make changes, test them out in a real-world container, and push them upstream to Git. All from within
a sandboxed environment. Dope.

<br>

### Updating a running workspace

If you realize the remote origin received a new commit after you spun up a workspace, and you don't like to be running
out-of-date code, just `cd` into the `.dotfiles` directory and pull the new commit(s):

```bash
cd ~/.dotfiles && git pull

# you most likely will want to to re-initialize the updated files...
./install.sh

# now you're running a fully updated workspace - just like new!
# to return to the root workspace folder:
cd $THEIA_WORKSPACE_ROOT
```

<br>

### Something broken? Check the logs.

If you're encountering a bug or something just isn't working correctly, you can check logs in two places. Gitpod stores
a log file located at `~/.dotfiles.log`, which may shed some light on what's going on during the install process when
your workspaces are being built. Otherwise, the `install.sh` script pipes its stderr to timestamped files inside of the
`~/.dotfiles` folder:

```bash
# logs files are timestamped (seconds elapsed since unix epoch)
cd ~/.dotfiles

ls .*.log
# .install.1650326691.log  .install.1650325105.log   ...

# if you'd rather jump right into the logs:
less .*.log
```

<br>

## Manual Installation

Want to install these dotfiles on an already-running workspace? That's cool too! Before proceeding to install them
manually, you need to copy the files from this repository to your workspace.

### 1. Clone the repo

There's numerous methods available for this step. Use whichever is best fit to your scenario:

#### GitHub CLI

```bash
gh repo clone nberlette/dotfiles ~/.dotfiles
```

#### Git Clone

```bash
git clone --depth 1 https://github.com/nberlette/dotfiles.git ~/.dotfiles
```

#### Degit

```bash
npx degit nberlette/dotfiles ~/.dotfiles --force
```

### 2. Run `install.sh`

```bash
cd ~/.dotfiles
pnpm install && ./install.sh
```

### 3. Reset your terminal, or open a new instance

```bash
source ~/.bashrc
```

<style>
details>summary {
  font-size: 1.3em;
  font-weight: 700;
  padding: 5px 10px;
  margin: 25px 0 6px 0;
  border-radius: 6px;
  border: 1px solid var(--c-divider-dark);
  border-bottom: 2px solid var(--c-divider-dark);
  cursor: pointer;
}
details:not([open])>summary {
  background-color:var(--c-divider-light);
}
@media (prefers-color-scheme: dark) {
  :root {
    --c-bg: #112233 !important;
    --c-text: #f0f0f0 !important;
    --c-text-light-3: #2c3e50 !important;
    --c-text-light-2: #476582 !important;
    --c-text-light-1: #90a4b7 !important;
    --c-white: #112233 !important;
    --c-white-dark: #000000 !important;
    --c-black: #f0f0f0 !important;
    --c-divider-light: rgba(230, 230, 230, .12) !important;
    --c-divider-dark: rgba(200, 200, 200, .48) !important;
  }
}
</style>
