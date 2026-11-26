# Radish 系列源码仓资产准入

规则版本为 `1.0.0`。本目录维护家族通用检查器和回归用例。各仓采用同一版本的 `.radish-assets/check.sh`，由各自的 Git 钩子与 CI 调用。版本升级时，统一同步脚本并更新各仓 `policy.tsv` 的版本行。

## 规则

| 资产 | 处理方式 |
| --- | --- |
| 运行、构建和测试所需的字体、图像、夹具 | 保留必要版本。单个二进制超过 5 MiB 时登记例外。 |
| 需要可复验的设计源和证据 | 保留必要版本。大二进制同样登记例外。 |
| 构建产物、依赖缓存、Playwright 输出、发布安装包、CHM 和归档包 | 默认移出源码仓，源码仓保留索引。必须保留的个别文件使用精确路径例外。 |
| 批量加入二进制文件 | 同批不同内容的二进制总量超过 10 MiB 时提示复核，提醒本身不会使检查失败。 |

检查只处理新增或内容发生变化的路径，也检查移入禁止路径的文件。启用基线之前的历史对象无需补登。源码仓与专门保存原件的资料仓分别管理。

## 各仓配置

`.radish-assets/policy.tsv` 使用制表符分隔字段。

| 行类型 | 字段 |
| --- | --- |
| `version` | 检查器版本 |
| `baseline` | 启用时的完整 Git 提交 ID |
| `deny` | 仓库专属输出路径模式 |
| `allow` | 精确相对路径、字节上限、SHA-256 或 `-`、用途、来源或仓库内的来源说明 |

固定版本文件登记实际 SHA-256。新增例外和更新固定版本应随同变更审阅。

## 检查入口

- `bash .radish-assets/check.sh --staged` 读取暂存区内容。
- Git `pre-push` 使用 `bash .radish-assets/check.sh --pre-push`，从标准输入接收 Git 提供的引用记录。
- CI 使用 `bash .radish-assets/check.sh --range <base> <head>`，检查范围内的每个新增提交，包含后来被删掉的文件。
- 验证本目录的回归用例使用 `bash asset-policy/v1/test.sh`。

使用 `.githooks` 的项目在新克隆中运行 `git config --local core.hooksPath .githooks`。使用 Husky 的项目沿用其既有初始化。检查器只使用 Bash、Git 和常见系统命令。

Git 钩子约束安装了钩子的副本。PR 检查在 GitHub 上保护现有合并门禁。允许直推的公开分支仍依靠本地预检。
