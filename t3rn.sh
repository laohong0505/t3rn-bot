#!/bin/bash（全自动安装）

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[31m请使用 sudo 运行此脚本\033[0m"
    exit 1
fi

# 定义仓库地址和目录名称
REPO_URL="https://github.com/sdohuajia/t3rn-bot.git"
DIR_NAME="t3rn-bot"
PYTHON_FILE="keys_and_addresses.py"
DATA_BRIDGE_FILE="data_bridge.py"
BOT_FILE="bot.py"
VENV_DIR="t3rn-env"  # 虚拟环境目录

# 检查是否安装了必要工具
if ! command -v git &>/dev/null; then
    echo "Git 未安装，请先安装 Git。"
    exit 1
fi

if ! command -v pip3 &>/dev/null; then
    echo "pip 未安装，正在安装 python3-pip..."
    sudo apt update
    sudo apt install -y python3-pip
fi

if ! python3 -m venv --help &>/dev/null; then
    echo "python3-venv 未安装，正在安装 python3-venv..."
    sudo apt update
    sudo apt install -y python3-venv
fi

# 拉取仓库
if [ -d "$DIR_NAME" ]; then
    echo "目录 $DIR_NAME 已存在，拉取最新更新..."
    cd "$DIR_NAME" || exit
    git pull origin main
else
    echo "正在克隆仓库 $REPO_URL..."
    git clone "$REPO_URL"
    cd "$DIR_NAME" || exit
fi

echo "已进入目录 $DIR_NAME"

# 创建虚拟环境并激活
if [ ! -d "$VENV_DIR" ]; then
    echo "正在创建虚拟环境..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# 升级 pip
echo "正在升级 pip..."
pip install --upgrade pip

# 安装依赖
echo "正在安装依赖 web3 和 colorama..."
pip install web3 colorama

# 提醒用户私钥安全
echo "警告：请务必确保您的私钥安全！"
echo "私钥将存储在受限权限的文件中，仅供脚本使用。"

# 获取用户输入的私钥和标签
echo "请输入您的私钥（多个私钥以空格分隔）："
read -s private_keys_input
echo "请输入您的标签（多个标签以空格分隔，与私钥顺序一致）："
read labels_input

IFS=' ' read -r -a private_keys <<<"$private_keys_input"
IFS=' ' read -r -a labels <<<"$labels_input"

if [ "${#private_keys[@]}" -ne "${#labels[@]}" ]; then
    echo "私钥和标签数量不一致，请重新运行脚本并确保它们匹配！"
    exit 1
fi

# 写入 keys_and_addresses.py 文件
cat >$PYTHON_FILE <<EOL
# 此文件由脚本生成

private_keys = [
$(printf "    '%s',\n" "${private_keys[@]}")
]

labels = [
$(printf "    '%s',\n" "${labels[@]}")
]
EOL
chmod 600 $PYTHON_FILE

echo "$PYTHON_FILE 文件已生成并设置权限为 600（仅当前用户可读写）。"

# 获取用户输入的 Data Bridge 数据
echo "请输入 'ARB - OP SEPOLIA' 的值："
read arb_op_sepolia_value

echo "请输入 'OP - ARB' 的值："
read op_arb_value

# 写入 data_bridge.py 文件
cat >$DATA_BRIDGE_FILE <<EOL
# 此文件由脚本生成

data_bridge = {
    # Data bridge Arbitrum Sepolia
    "ARB - OP SEPOLIA": "$arb_op_sepolia_value",

    # Data bridge OP Sepolia
    "OP - ARB": "$op_arb_value",
}
EOL
chmod 600 $DATA_BRIDGE_FILE

echo "$DATA_BRIDGE_FILE 文件已生成并设置权限为 600（仅当前用户可读写）。"

# 并行运行 bot.py
echo "开始并行运行多个钱包任务（带随机延迟）..."
for private_key in "${private_keys[@]}"; do
    (
        # 生成 30 到 60 秒的随机延迟
        delay=$((RANDOM % 31 + 30))
        echo "钱包任务延迟 ${delay} 秒启动..."
        sleep "$delay"
        python3 $BOT_FILE "$private_key"
    ) &
done

# 等待所有进程完成
wait
echo "所有钱包任务已并行完成！"
