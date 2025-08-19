<h1 align="center">✨ <a href="https://scoop-tools.abgox.com">scoop-tools</a> ✨</h1>

<p align="center">
    <a href="readme.zh-CN.md">简体中文</a> |
    <a href="readme.md">English</a> |
    <a href="https://github.com/abgox/scoop-tools">Github</a> |
    <a href="https://gitee.com/abgox/scoop-tools">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/scoop-tools/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/scoop-tools" alt="license" />
    </a>
    <a href="https://github.com/abgox/scoop-tools">
        <img src="https://img.shields.io/github/v/release/abgox/scoop-tools?label=version" alt="version" />
    </a>
    <a href="https://img.shields.io/github/languages/code-size/abgox/scoop-tools.svg">
        <img src="https://img.shields.io/github/languages/code-size/abgox/scoop-tools.svg" alt="code size" />
    </a>
    <a href="https://img.shields.io/github/repo-size/abgox/scoop-tools.svg">
        <img src="https://img.shields.io/github/repo-size/abgox/scoop-tools.svg" alt="repo size" />
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

- Some PowerShell scripts that allows you to add Scoop configurations to use a replaced url instead of the original url when installing the app in Scoop.
  - `scoop-install`
  - `scoop-update`
- Typical case: if app come from [GitHub](https://github.com), you can configure a proxy URL to improve download experience in China.

## Installation

- Add bucket

  ```shell
  scoop bucket add abyss https://gitee.com/abgox/abyss
  ```

- Install scoop-install

  ```shell
  scoop install abyss/abgox.scoop-install
  ```

- Install scoop-update

  ```shell
  scoop install abyss/abgox.scoop-update
  ```

## Usage

> [!Tip]
> Scoop Config
>
> - `scoop-install-url-replace-from`: The URL to replace, use regular expressions. Use `^` to match the beginning of the URL.
> - `scoop-install-url-replace-to`: The replacement URL that corresponds to `scoop-install-url-replace-from`.

1. Set URL replacement configurations. Use `|||` as a delimiter if there are multiple values.

   ```shell
   scoop config scoop-install-url-replace-from "^https://github.com|||^https://raw.githubusercontent.com"
   ```

   ```shell
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com"
   ```

2. Install [PSCompletions](https://gitee.com/abgox/PSCompletions) to add command completion.

   ```shell
   scoop install abyss/abgox.PSCompletions
   ```

   ```shell
   Import-Module PSCompletions
   ```

   ```shell
   psc add scoop-install scoop-update
   ```

3. Install apps using the `scoop-install` command.

   ```shell
   scoop-install abyss/abgox.scoop-i18n
   ```

4. Update apps using the `scoop-update` command.

   ```shell
   scoop-update abyss/abgox.scoop-i18n
   ```

---

- `scoop-install` supports the `-reset` parameter and all parameters of the `scoop install` command.
- `scoop-update` supports the `-reset` parameter and all parameters of the `scoop update` command.

- Examples:

  - If you want to undo all local file changes in the buckets to avoid synchronization conflicts during `scoop update`.

    - It uses `git stash` to undo.
    - If you still need these changes, you can use `git stash pop`.
    - For details, refer to [git stash](https://git-scm.com/docs/git-stash).

    ```shell
    scoop-install -reset
    ```

  - If you want to install `abyss/abgox.InputTip-zip` without updating Scoop, you can use `-u` or `--no-update-scoop`.

    ```shell
    scoop-install abyss/abgox.scoop-i18n -u
    ```

  - If you don't also want to use the download cache, you can use `-k` or `--no-cache`.

    ```shell
    scoop-install abyss/abgox.scoop-i18n -u --no-cache
    ```

## How It Works

> [!Tip]
>
> When you run `scoop-install abyss/abgox.scoop-i18n`, it goes through the following process:

1. `scoop-install` reads the following two configuration values:

   - `scoop-install-url-replace-from`
   - `scoop-install-url-replace-to`

2. It replaces `url` in the manifest file of `abyss/abgox.scoop-i18n` based on these configurations.

   - For example, if you use the following configuration:

     - `scoop-install-url-replace-from` is set to `^https://github.com|||^https://raw.githubusercontent.com`
     - `scoop-install-url-replace-to` is set to `https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com`

   - It will split the values by `|||` and replace the `url` accordingly:

     - `^https://github.com` matches `url` starting with `https://github.com` and replaces them with `https://gh-proxy.com/github.com`.
     - `^https://raw.githubusercontent.com` is replaced with `https://gh-proxy.com/raw.githubusercontent.com`.

3. After replacement, `scoop-install` runs the actual `scoop install` command.

   - Since `url` of the manifest have been replaced with `https://gh-proxy.com`, Scoop will download the installation packages from `https://gh-proxy.com`.

4. Once the installation is complete (or interrupted with `Ctrl + C`), `scoop-install` automatically undos the changes made to the manifest file.

   - If you close the terminal during installation, it cannot undo the changes.
   - This may cause issues with `scoop update` due to local file modifications conflicting with the remote bucket.
   - In that case, you can run `scoop-install -reset`, which will undo local file changes in all buckets via `git stash`.

     - It uses `git stash` to undo.
     - If you still need these changes, you can use `git stash pop`.
     - For details, refer to [git stash](https://git-scm.com/docs/git-stash)
