<h1 align="center">✨ <a href="https://scoop-tools.abgox.com">scoop-tools</a> ✨</h1>

<p align="center">
    <a href="readme.zh-CN.md">简体中文</a> |
    <a href="readme.md">English</a> |
    <a href="https://github.com/abgox/scoop-tools">Github</a> |
    <a href="https://gitee.com/abgox/scoop-tools">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/scoop-tools">
        <img src="https://img.shields.io/github/stars/abgox/scoop-tools" alt="github stars" />
    </a>
    <a href="https://github.com/abgox/scoop-tools/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/scoop-tools" alt="license" />
    </a>
    <a href="https://img.shields.io/github/languages/code-size/abgox/scoop-tools">
        <img src="https://img.shields.io/github/languages/code-size/abgox/scoop-tools" alt="code size" />
    </a>
    <a href="https://img.shields.io/github/repo-size/abgox/scoop-tools">
        <img src="https://img.shields.io/github/repo-size/abgox/scoop-tools" alt="repo size" />
    </a>
    <a href="https://github.com/abgox/scoop-tools">
        <img src="https://img.shields.io/github/created-at/abgox/scoop-tools" alt="created" />
    </a>
</p>

---

<p align="center">
  <strong>Star ⭐️ or <a href="https://abgox.com/donate">Donate 💰</a> if you like it!</strong>
</p>

> [!Tip]
>
> [scoop/scoop-install/scoop-update completion in PSCompletions](https://github.com/abgox/PSCompletions) is recommended.

## Introduction

Enhancement tools for [Scoop](https://scoop.sh) that allow you to **dynamically replace** URLs in manifest files when installing or updating applications.

- **Faster Downloads**: Replace slow sources like Github with mirror proxies, such as [gh-proxy](https://gh-proxy.com).
- **Non-intrusive**: Temporarily modifies local manifests only during the installation process and automatically reverts them afterward.
- **Safe & Reliable**: Automatically handles uncommitted changes in local buckets using [git stash](https://git-scm.com/docs/git-stash).

## Installation

- Add the [abyss](https://abyss.abgox.com) bucket ([Github](https://github.com/abgox/abyss) or [Gitee](https://gitee.com/abgox/abyss))

  ```shell
  scoop bucket add abyss https://gitee.com/abgox/abyss
  ```

  ```shell
  scoop bucket add abyss https://github.com/abgox/abyss
  ```

- Install `scoop-install`

  ```shell
  scoop install abyss/abgox.scoop-install
  ```

- Install `scoop-update`

  ```shell
  scoop install abyss/abgox.scoop-update
  ```

## Usage

> [!Tip]
>
> Scoop Configurations
>
> - `abgox-scoop-install-url-replace-from`: The URL to replace, use regular expressions. Use `^` to match the beginning of the URL.
> - `abgox-scoop-install-url-replace-to`: The replacement URL that corresponds to `abgox-scoop-install-url-replace-from`.

1. Set the URL replacement configuration. Use `|` to separate multiple values.

   ```shell
   scoop config abgox-scoop-install-url-replace-from "^https://github.com|^https://raw.githubusercontent.com"
   ```

   ```shell
   scoop config abgox-scoop-install-url-replace-to "https://gh-proxy.com/github.com|https://gh-proxy.com/raw.githubusercontent.com"
   ```

2. Add command completions using [PSCompletions](https://gitee.com/abgox/PSCompletions)

   ```shell
   scoop install abyss/abgox.PSCompletions
   ```

   ```shell
   Import-Module PSCompletions
   ```

   ```shell
   psc add scoop-install scoop-update
   ```

3. Use `scoop-install` to install apps

   ```shell
   scoop-install abyss/abgox.scoop-i18n
   ```

4. Use `scoop-update` to update apps

   ```shell
   scoop-update abyss/abgox.scoop-i18n
   ```

## How It Works

> [!Tip]
>
> Taking `scoop-install` as an example, it executes the following logic:

1. **Status Check**: Checks if there are uncommitted changes in the local bucket. If so, automatically runs [git stash](https://git-scm.com/docs/git-stash) to stash them.
2. **Dynamic Matching**: Reads the following configurations and matches the JSON manifest of the target application via regex:
   - `abgox-scoop-install-url-replace-from`
   - `abgox-scoop-install-url-replace-to`
3. **Temporary Replacement**: Modifies the `url` in the manifest to the proxy.
4. **Invoke Native Command**: Executes the actual `scoop install`. Scoop will download from the proxy.
5. **Automatic Restoration**: After installation completes or is interrupted by `Ctrl+C`, the changes to the manifest are automatically restored.

> [!Warning]
>
> - If you **close the terminal window** directly during installation, the script will be unable to execute the cleanup logic.
> - This may leave modified remains in your local bucket (causing `scoop update` to fail).
> - **Solution**: Manually run `git reset --hard` within the corresponding bucket directory to restore it.
