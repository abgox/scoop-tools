<h1 align="center">✨ <a href="https://scoop-tools.abgox.com">scoop-tools</a> ✨</h1>

<p align="center">
    <a href="readme.md">English</a> |
    <a href="readme.zh-CN.md">简体中文</a> |
    <a href="https://github.com/abgox/scoop-tools">Github</a> |
    <a href="https://gitee.com/abgox/scoop-tools">Gitee</a>
</p>

<p align="center">
    <a href="https://github.com/abgox/scoop-tools/blob/main/license">
        <img src="https://img.shields.io/github/license/abgox/scoop-tools" alt="license" />
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
  <strong>喜欢这个项目？请给它一个 ⭐️ 或 <a href="https://abgox.com/donate">赞赏 💰</a></strong>
</p>

> [!Tip]
>
> 推荐使用 [PSCompletions 中的 scoop/scoop-install/scoop-update 命令补全](https://gitee.com/abgox/PSCompletions)

## 介绍

- 用于 Scoop 的 PowerShell 脚本，它允许你添加 Scoop 配置，在 Scoop 安装和更新应用时使用替换后的 url 而不是原始的 url
  - `scoop-install`
  - `scoop-update`
- 典型的使用场景: 如果应用的安装包来自 [Github](https://github.com)，可以配置代理地址，优化中国境内的下载体验

## 安装

- 添加 bucket

  ```shell
  scoop bucket add abyss https://gitee.com/abgox/abyss
  ```

- 安装 scoop-install

  ```shell
  scoop install abyss/abgox.scoop-install
  ```

- 安装 scoop-update

  ```shell
  scoop install abyss/abgox.scoop-update
  ```

## 使用

> [!Tip]
> Scoop 配置项
>
> - `scoop-install-url-replace-from`: 需要被替换的 url，使用正则表达式，用 `^` 限制匹配行首
> - `scoop-install-url-replace-to`: 用于替换的 url，必须和 `scoop-install-url-replace-from` 相对应

1. 设置 url 替换配置，如果有多个值，使用 `|||` 分割

   ```shell
   scoop config scoop-install-url-replace-from "^https://github.com|||^https://raw.githubusercontent.com"
   ```

   ```shell
   scoop config scoop-install-url-replace-to "https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com"
   ```

2. 使用 [PSCompletions](https://gitee.com/abgox/PSCompletions) 添加命令补全

   ```shell
   scoop install abyss/abgox.PSCompletions
   ```

   ```shell
   Import-Module PSCompletions
   ```

   ```shell
   psc add scoop-install scoop-update
   ```

3. 使用 `scoop-install` 命令安装应用

   ```shell
   scoop-install abyss/abgox.scoop-i18n
   ```

4. 使用 `scoop-update` 命令更新应用

   ```shell
   scoop-update abyss/abgox.scoop-i18n
   ```

---

- `scoop-install` 可以使用 `-reset` 参数和 `scoop install` 命令的所有参数
- `scoop-update` 可以使用 `-reset` 参数和 `scoop update` 命令的所有参数

- 参考示例:

  - 如果你想撤销所有 bucket 中的本地文件更改，避免 `scoop update` 出现远程同步冲突

    - 它使用 `git stash` 实现
    - 如果你还需要这些更改，可以使用 `git stash pop`
    - 详情参考 [git stash](https://git-scm.com/docs/git-stash)

    ```shell
    scoop-install -reset
    ```

  - 如果你想在安装 `abyss/abgox.scoop-i18n` 时不更新 Scoop，可以使用 `-u` 或 `--no-update-scoop`

    ```shell
    scoop-install abyss/abgox.scoop-i18n -u
    ```

  - 如果你还不想使用下载缓存，可以使用 `-k` 或 `--no-cache`
    ```shell
    scoop-install abyss/abgox.scoop-i18n -u --no-cache
    ```

## 实现原理

> [!Tip]
>
> 当你运行 `scoop-install abyss/abgox.scoop-i18n` 时，scoop-install 会执行以下逻辑

1. scoop-install 会读取以下两个配置项的值

   - `scoop-install-url-replace-from`
   - `scoop-install-url-replace-to`

2. scoop-install 会根据配置项的值替换 `abyss/abgox.scoop-i18n` 的清单文件中的 url

   - 假如你使用了以下配置

     - `scoop-install-url-replace-from` 的值为 `^https://github.com|||^https://raw.githubusercontent.com`
     - `scoop-install-url-replace-to` 的值为 `https://gh-proxy.com/github.com|||https://gh-proxy.com/raw.githubusercontent.com`

   - 它会根据 `|||` 进行分割，然后分别对 url 进行替换

     - `^https://github.com` 匹配 `https://github.com` 开头的 url，然后替换为 `https://gh-proxy.com/github.com`
     - `^https://raw.githubusercontent.com` 匹配 `https://raw.githubusercontent.com` 开头的 url，然后替换为 `https://gh-proxy.com/raw.githubusercontent.com`

3. 替换完成后，scoop-install 才会执行实际的 `scoop install` 命令

   - 由于清单中的 url 已经替换为了 `https://gh-proxy.com`
   - 所以 Scoop 会从 `https://gh-proxy.com` 下载安装包

4. 当安装完成或使用 `Ctrl + C` 终止安装后，scoop-install 会自动撤销 `abyss/abgox.scoop-i18n` 的清单文件中的本地更改

   - 如果安装过程中，直接关掉终端，scoop-install 无法继续撤销本地更改
   - 这可能导致因为本地残留的更改，`scoop update` 无法正常的同步远程 bucket 仓库
   - 此时，你需要运行 `scoop-install -reset`，它会撤销所有 bucket 中的本地文件更改
     - 它使用 `git stash` 实现
     - 如果你还需要这些更改，可以使用 `git stash pop`
     - 详情参考 [git stash](https://git-scm.com/docs/git-stash)
