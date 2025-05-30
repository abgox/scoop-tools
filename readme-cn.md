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
> 推荐使用 [PSCompletions 中的 scoop 和 scoop-install 命令补全](https://github.com/abgox/PSCompletions)

## 介绍

一个 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 安装应用时使用替换后的 url 而不是原始的 url

## 安装

```pwsh
scoop bucket add abyss https://gitee.com/abgox/abyss
scoop install abyss/scoop-install
```

## 使用

1. 设置 url 替换配置

   ```pwsh
   scoop config scoop-install-url-replace-from "https://github.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com"
   ```

2. 使用 `scoop-install` 命令安装 `InputTip-zip`

   ```pwsh
   scoop-install InputTip-zip
   ```

   ```pwsh
   scoop-install abyss/InputTip-zip
   ```

---

- `scoop-install` 可以使用 `-reset` 参数和 `scoop install` 命令的所有参数

- 参考示例:

  - 如果你想清除所有 bucket 中的本地文件更改，避免 `scoop update` 出现远程同步冲突

    ```pwsh
    scoop-install -reset
    ```

  - 如果你想在安装 `abyss/InputTip-zip` 时不更新 Scoop，可以使用 `-u` 或 `--no-update-scoop`

    ```pwsh
    scoop-install abyss/InputTip-zip -u
    ```

  - 如果你还不想使用下载缓存，可以使用 `-k` 或 `--no-cache`
    ```pwsh
    scoop-install abyss/InputTip-zip -u --no-cache
    ```

## 实现原理

> [!Tip]
>
> 当你运行 `scoop-install abyss/InputTip-zip` 时，scoop-install 会执行以下逻辑

1. scoop-install 会读取以下两个配置项的值

   - `scoop-install-url-replace-from`: 需要替换的 url 前缀
   - `scoop-install-url-replace-to`: 替换后的 url 前缀

2. scoop-install 会根据配置项的值替换 `abyss/InputTip-zip.json` 这个清单文件中的 url

   - 假如你使用了以下配置

     - `scoop-install-url-replace-from` 的值为 `https://github.com`
     - `scoop-install-url-replace-to` 的值为 `https://gh-proxy.com/github.com`

   - 这表示要将 url 中的 `https://github.com` 替换为 `https://gh-proxy.com/github.com`

3. 替换完成后，scoop-install 才会执行 `scoop install abyss/InputTip-zip`

   - 由于清单中的 url 已经替换为了 `https://gh-proxy.com/github.com`
   - 所以 `scoop` 会从 `https://gh-proxy.com/github.com` 下载安装包

4. 当安装完成或使用 `Ctrl + C` 终止安装后，scoop-install 会清除掉 `abyss/InputTip-zip.json` 这个清单文件的本地更改

   - 如果安装过程中，直接关掉终端，scoop-install 无法继续清除本地更改
   - 这可能导致因为本地残留的更改，`scoop update` 无法正常的同步远程 bucket 仓库
   - 此时，你需要运行 `scoop-install -reset`，它会清除所有 bucket 中的本地文件更改
