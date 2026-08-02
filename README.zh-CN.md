<h1 align="center">✨<a href="https://scoop-tools.abgox.com">scoop-tools</a>✨</h1>

<p align="center">
    <a href="README.md">English</a> |
    <a href="https://github.com/abgox/scoop-tools">GitHub</a> |
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
  <strong>喜欢这个项目？请给它 Star ⭐️ 或 <a href="https://me.abgox.com/donate">赞赏 💰</a></strong>
</p>

> [!TIP]
>
> 推荐使用 [PSCompletions 中的 scoop/scoop-install/scoop-update 命令补全](https://pscompletions.abgox.com)

## 介绍

为 [Scoop](https://scoop.sh) 打造的增强工具，允许你在安装或更新应用时，**动态替换** 清单文件中的下载 URL

- **加速下载**：将 GitHub 等慢速源替换为镜像代理，例如 [gh-proxy](https://gh-proxy.com)
- **非侵入性**：仅在安装瞬间修改本地清单，完成后自动还原
- **安全可靠**：自动使用 [git stash](https://git-scm.com/docs/git-stash) 处理本地 bucket 的未提交更改

## 安装

- 添加 [abyss](https://abyss.abgox.com) bucket ([GitHub](https://github.com/abgox/abyss) 或 [Gitee](https://gitee.com/abgox/abyss))

  ```shell
  scoop bucket add abyss https://gitee.com/abgox/abyss
  ```

  ```shell
  scoop bucket add abyss https://github.com/abgox/abyss
  ```

- 安装 `scoop-install`

  ```shell
  scoop install abyss/abgox.scoop-install
  ```

- 安装 `scoop-update`

  ```shell
  scoop install abyss/abgox.scoop-update
  ```

## 使用

> [!TIP]
>
> Scoop 配置
>
> - `abgox-scoop-install-url-replace-from`: 需要被替换的 url，使用正则表达式，用 `^` 限制匹配行首
> - `abgox-scoop-install-url-replace-to`: 用于替换的 url，必须和 `abgox-scoop-install-url-replace-from` 相对应

1. 设置 url 替换配置，如果有多个值，使用 `|` 分割

   ```shell
   scoop config abgox-scoop-install-url-replace-from "^https://github.com|^https://raw.githubusercontent.com"
   ```

   ```shell
   scoop config abgox-scoop-install-url-replace-to "https://gh-proxy.com/github.com|https://gh-proxy.com/raw.githubusercontent.com"
   ```

2. 使用 [PSCompletions](https://pscompletions.abgox.com) 添加命令补全

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

## 实现原理

> [!TIP]
>
> 以 `scoop-install` 为例，它会执行以下逻辑

1.  **状态检查**：检查本地 bucket 是否有未提交的更改。如果有，自动执行 [git stash](https://git-scm.com/docs/git-stash) 暂存
2.  **动态匹配**：读取以下配置，通过正则匹配目标应用的 JSON 清单
    - `abgox-scoop-install-url-replace-from`
    - `abgox-scoop-install-url-replace-to`

3.  **临时替换**：修改清单中的 `url` 为代理地址
4.  **调用原生**：执行真正的 `scoop install`，此时 Scoop 会从代理地址下载
5.  **自动恢复**：安装完成或 `Ctrl+C` 中断后，自动撤销清单修改

> [!WARNING]
>
> - 如果在安装过程中直接**关闭终端窗口**，脚本将无法执行清理逻辑
> - 这可能导致本地 bucket 存在修改残留（导致 `scoop update` 报错）
> - **解决方法**：在对应的 bucket 目录下手动执行 `git reset --hard` 进行恢复

## License

[MIT](./LICENSE) © [abgox](https://me.abgox.com)
