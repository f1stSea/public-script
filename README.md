# public-script

各项目的公开部署脚本，从对应私有仓库通过 GitHub Actions 自动同步。

## 结构

```
public-script/
├── evergreen/          # Evergreen Dashboard 部署脚本
│   ├── deploy.sh       # 一键部署/更新
│   └── docker-compose.yml
└── (其它项目)/
```

## Evergreen Dashboard

```bash
# 首次部署 / 更新
curl -fsSL https://raw.githubusercontent.com/f1stSea/public-script/main/evergreen/deploy.sh | bash
```

需要先登录 GHCR（镜像为私有包）：

```bash
echo "YOUR_PAT" | sudo docker login ghcr.io -u f1stSea --password-stdin
```

## 说明

各项目脚本均由对应仓库的 GitHub Actions 自动同步，不在此处直接修改。
