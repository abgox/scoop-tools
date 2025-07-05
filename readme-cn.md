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
> 推荐使用 [PSCompletions 中的 scoop 和 scoop-install 命令补全](https://gitee.com/abgox/PSCompletions)

## 介绍

- 一个 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 安装应用时使用替换后的 url 而不是原始的 url
- 典型的使用场景: 如果应用的安装包来自 [Github](https://github.com)，可以配置代理地址，优化中国境内的下载体验

## 安装

```pwsh
scoop bucket add abyss https://gitee.com/abgox/abyss
scoop install abyss/abgox.scoop-install
```

## 使用

1. 设置 url 替换配置，如果有多个值，使用 `|||` 分割

   - `scoop-install-url-replace-from`: 推荐使用正则表达式，用 `^` 限制匹配行首
   - `scoop-install-url-replace-from`: 替换后的 url，必须和 `scoop-install-url-replace-to` 相对应

   ```pwsh
   scoop config scoop-install-url-replace-from "^https://github.com|||^https://raw.githubusercontent.com"
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com"
   ```

2. 使用 `scoop-install` 命令安装应用

   ```pwsh
   scoop-install abyss/Microsoft.PowerShell
   ```

---

- `scoop-install` 可以使用 `-reset` 参数和 `scoop install` 命令的所有参数

- 参考示例:

  - 如果你想撤销所有 bucket 中的本地文件更改，避免 `scoop update` 出现远程同步冲突

    - 它使用 `git stash` 实现
    - 如果你还需要这些更改，可以使用 `git stash pop`，详情参考 [git stash](https://git-scm.com/docs/git-stash)

    ```pwsh
    scoop-install -reset
    ```

  - 如果你想在安装 `abyss/Microsoft.PowerShell` 时不更新 Scoop，可以使用 `-u` 或 `--no-update-scoop`

    ```pwsh
    scoop-install abyss/Microsoft.PowerShell -u
    ```

  - 如果你还不想使用下载缓存，可以使用 `-k` 或 `--no-cache`
    ```pwsh
    scoop-install abyss/Microsoft.PowerShell -u --no-cache
    ```

## 实现原理

> [!Tip]
>
> 当你运行 `scoop-install abyss/Microsoft.PowerShell` 时，scoop-install 会执行以下逻辑

1. scoop-install 会读取以下两个配置项的值

   - `scoop-install-url-replace-from`: 需要替换的 url (正则表达式)
   - `scoop-install-url-replace-to`: 替换后的 url

2. scoop-install 会根据配置项的值替换 `abyss/Microsoft.PowerShell` 的清单文件中的 url

   - 假如你使用了以下配置

     - `scoop-install-url-replace-from` 的值为 `^https://github.com|||^https://raw.githubusercontent.com`
     - `scoop-install-url-replace-to` 的值为 `https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com`

   - 它会根据 `|||` 进行分割，然后分别对 url 进行替换

     - `^https://github.com` 匹配 `https://github.com` 开头的 url，然后替换为 `https://gh-proxy.com/github.com`
     - `^https://raw.githubusercontent.com` 匹配 `https://raw.githubusercontent.com` 开头的 url，然后替换为 `https://gh-proxy.com/raw.githubusercontent.com`

3. 替换完成后，scoop-install 才会执行实际的 `scoop install` 命令

   - 由于清单中的 url 已经替换为了 `https://gh-proxy.com`
   - 所以 Scoop 会从 `https://gh-proxy.com` 下载安装包

4. 当安装完成或使用 `Ctrl + C` 终止安装后，scoop-install 会自动撤销 `abyss/Microsoft.PowerShell` 的清单文件中的本地更改

   - 如果安装过程中，直接关掉终端，scoop-install 无法继续撤销本地更改
   - 这可能导致因为本地残留的更改，`scoop update` 无法正常的同步远程 bucket 仓库
   - 此时，你需要运行 `scoop-install -reset`，它会撤销所有 bucket 中的本地文件更改
     - 它使用 `git stash` 实现
     - 如果你还需要这些更改，可以使用 `git stash pop`，详情参考 [git stash](https://git-scm.com/docs/git-stash)
