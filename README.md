<h1 align="center"><a href="https://scoop-tools.abgox.com">scoop-tools</a></h1>

<p align="center">
    <span>English</span> |
    <a href="README.zh-CN.md">简体中文</a> |
    <a href="https://github.com/abgox/scoop-tools">GitHub</a> |
    <a href="https://atomgit.com/abgox/scoop-tools">AtomGit</a> |
    <a href="https://gitee.com/abgox/scoop-tools">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/scoop-tools">
        <img src="https://img.shields.io/github/stars/abgox/scoop-tools" alt="github stars" />
    </a>
    <a href="https://github.com/abgox/scoop-tools/blob/main/LICENSE">
        <img src="https://img.shields.io/github/license/abgox/scoop-tools" alt="license" />
    </a>
    <a href="https://github.com/abgox/scoop-tools">
        <img src="https://img.shields.io/github/created-at/abgox/scoop-tools" alt="created" />
    </a>
</p>

---

<p align="center">
  <strong>Star ⭐️ or <a href="https://me.abgox.com/donate">Donate 💰</a> if you like it!</strong>
</p>

> [!TIP]
>
> [scoop/scoop-install/scoop-update completion in PSCompletions](https://pscompletions.abgox.com) is recommended.

## Introduction

Enhancement tools for [Scoop](https://scoop.sh) that allow you to **dynamically replace** URLs in manifest files when installing or updating applications.

- **Faster Downloads**: Replace slow sources like GitHub with mirror proxies, such as [gh-proxy](https://gh-proxy.com).
- **Safe & Reliable**: Temporarily modifies local manifests only during the installation process and automatically reverts them afterward.

## Installation

- Add the [abyss](https://abyss.abgox.com) bucket

  ```shell
  scoop bucket add abyss https://gitee.com/abgox/abyss
  ```

  ```shell
  scoop bucket add abyss https://atomgit.com/abgox/abyss
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

> [!TIP]
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
   scoop config abgox-scoop-install-url-replace-to "https://gh-proxy.org/github.com|https://gh-proxy.org/raw.githubusercontent.com"
   ```

2. Add command completions using [PSCompletions](https://pscompletions.abgox.com)

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

> [!NOTE]
>
> Scoop options are passed through. For example:
>
> - `scoop-install -g -a 64bit app`
> - `scoop-install -i app` (do not install dependencies)
> - `scoop-update --all`
>
> Dependencies are downloaded through the proxy as well.

## How It Works

> [!TIP]
>
> Taking `scoop-install` as an example, it executes the following logic:

1. **Resolve Manifest**: Finds the target app's manifest in the local bucket.
2. **Scoop Update Check**: If Scoop is due for an update, runs `scoop update` before touching any manifest.
3. **Dynamic Matching**: Reads the following configurations and matches the JSON manifest of the target application via regex:
   - `abgox-scoop-install-url-replace-from`
   - `abgox-scoop-install-url-replace-to`
4. **Temporary Replacement**: Modifies the `url` in the manifest to the proxy.
5. **Invoke Native Command**: Executes the actual `scoop install`. Scoop will download from the proxy.
6. **Automatic Restoration**: Restores the original manifest bytes after installation completes or is interrupted by `Ctrl + c`.

> [!WARNING]
>
> - If you **close the terminal window** directly during installation, the script will be unable to execute the cleanup logic.
> - This may leave the manifest temporarily modified.
> - **Solution**: Run `git -C <bucket> restore <manifest>` or restore it from your bucket backup.

## License

[MIT](./LICENSE) © [abgox](https://me.abgox.com)
