<p align="center">
  <h1 align="center">✨scoop-install✨</h1>
</p>

<p align="center">
    <a href="readme-cn.md">简体中文</a> |
    <a href="readme.md">English</a> |
    <a href="https://github.com/abgox/scoop-install">Github</a> |
    <a href="https://gitee.com/abgox/scoop-install">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/scoop-install/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/scoop-install" alt="license" />
    </a>
    <a href="https://github.com/abgox/scoop-install">
        <img src="https://img.shields.io/github/v/release/abgox/scoop-install?label=version" alt="version" />
    </a>
    <a href="https://img.shields.io/github/languages/code-size/abgox/scoop-install.svg">
        <img src="https://img.shields.io/github/languages/code-size/abgox/scoop-install.svg" alt="code size" />
    </a>
    <a href="https://img.shields.io/github/repo-size/abgox/scoop-install.svg">
        <img src="https://img.shields.io/github/repo-size/abgox/scoop-install.svg" alt="repo size" />
    </a>
    <a href="https://github.com/abgox/scoop-install">
        <img src="https://img.shields.io/github/created-at/abgox/scoop-install" alt="created" />
    </a>
</p>

---

> [!Tip]
>
> [scoop and scoop-install completion in PSCompletions](https://github.com/abgox/PSCompletions) is recommended.

## Introduction

A PowerShell script that allows you to add Scoop configurations to use a replaced url instead of the original url when installing the app in Scoop.

## Installation

```pwsh
scoop bucket add abyss https://gitee.com/abgox/abyss
scoop install abyss/scoop-install
```

## Usage

1. Configure URL replacement settings.

   ```pwsh
   scoop config scoop-install-url-replace-from "https://github.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"
   ```

2. Use the `scoop-install` command to install `InputTip-zip`.

   ```pwsh
   scoop-install InputTip-zip
   ```

   ```pwsh
   scoop-install abyss/InputTip-zip
   ```

---

- `scoop-install` supports the `-reset` parameter and all parameters of the `scoop install` command.

- Some examples:

  - If you want to clear all local file changes in the buckets to avoid synchronization conflicts during `scoop update`.

    ```pwsh
    scoop-install -reset
    ```

  - If you want to install `abyss/InputTip-zip` without updating Scoop, you can use `-u` or `--no-update-scoop`.

    ```pwsh
    scoop-install abyss/InputTip-zip -u
    ```

  - If you don't also want to use the download cache, you can use `-k` or `--no-cache`.

    ```pwsh
    scoop-install abyss/InputTip-zip -u --no-cache
    ```

## Implementation Details

> [!Tip]
>
> When you run `scoop-install abyss/InputTip-zip`, `scoop-install` will perform the following logic:

1. `scoop-install` reads the values of the following two configuration items:

   - `scoop-install-url-replace-from`: The URL prefix to be replaced.
   - `scoop-install-url-replace-to`: The new URL prefix after replacement.

2. `scoop-install` replaces the URLs in the manifest file `abyss/InputTip-zip.json` based on the configured values.

   - For example, if you use the following configuration:
     - `scoop-install-url-replace-from` is set to `https://github.com`.
     - `scoop-install-url-replace-to` is set to `https://gh-proxy.com/github.com`.
   - It means replacing `https://github.com` with `https://gh-proxy.com/github.com` in the URLs.

3. After replacement, `scoop-install` executes `scoop install abyss/InputTip-zip`.

   - Since the URLs in the manifest have been replaced with `https://gh-proxy.com/github.com`,
   - Scoop will download the installation package from `https://gh-proxy.com/github.com`.

4. After installation is complete or terminated with `Ctrl + C`, `scoop-install` clears the local changes in the manifest file `abyss/InputTip-zip.json`.

   - If the terminal is closed during installation, `scoop-install` cannot clean up the local changes.
   - It may cause `scoop update` to fail in syncing the remote bucket repository due to residual local changes.
   - In such cases, run `scoop-install -reset` will clear all local file changes in scoop buckets.
