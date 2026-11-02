
#!/usr/bin/env bash
SHELL_PATH=$(readlink -f "${BASH_SOURCE[0]}"); SHELL_DIR=$(dirname "$SHELL_PATH"); cd "$SHELL_DIR" || { echo "切换工作目录失败"; exit 1; }

set -Eeuo pipefail

# 镜像映射文件
IMAGE_FILE="images.txt"

# 检查文件是否存在
if [[ ! -f "$IMAGE_FILE" ]]; then
    echo "[ERROR] 文件不存在: $IMAGE_FILE"
    exit 1
fi

SUCCESS=0
FAILED=0
TOTAL=0

while IFS= read -r line || [[ -n "$line" ]]; do
    # 去除首尾空白
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # 跳过空行和注释
    [[ -z "$line" || "$line" == \#* ]] && continue

    # 检查映射格式
    if [[ "$line" != *"->"* ]]; then
        echo "[WARN] 无效格式，跳过: $line"
        ((FAILED+=1))
        continue
    fi

    # 分割源镜像和目标镜像
    SOURCE_IMAGE="${line%%->*}"
    TARGET_IMAGE="${line#*->}"

    # 去除首尾空白
    SOURCE_IMAGE="${SOURCE_IMAGE%"${SOURCE_IMAGE##*[![:space:]]}"}"
    TARGET_IMAGE="${TARGET_IMAGE#"${TARGET_IMAGE%%[![:space:]]*}"}"

    if [[ -z "$SOURCE_IMAGE" || -z "$TARGET_IMAGE" ]]; then
        echo "[WARN] 镜像名称为空，跳过: $line"
        ((FAILED+=1))
        continue
    fi

    ((TOTAL+=1))

    echo
    echo "========================================"
    echo "[INFO] 源镜像: $SOURCE_IMAGE"
    echo "[INFO] 目标镜像: $TARGET_IMAGE"
    echo "========================================"

    # 拉取源镜像
    if ! docker pull --quiet "$SOURCE_IMAGE"; then
        echo "[ERROR] 拉取失败: $SOURCE_IMAGE"
        ((FAILED+=1))
        continue
    fi

    # 标记目标镜像
    if ! docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"; then
        echo "[ERROR] Tag 失败: $TARGET_IMAGE"
        ((FAILED+=1))
        continue
    fi

    # 推送目标镜像
    if ! docker push --quiet "$TARGET_IMAGE"; then
        echo "[ERROR] 推送失败: $TARGET_IMAGE"
        ((FAILED+=1))
        continue
    fi
    
    # 清理缓存
    docker image prune --all --force
    
    echo "[SUCCESS] 镜像同步成功: $TARGET_IMAGE"
    ((SUCCESS+=1))

done < "$IMAGE_FILE"

echo
echo "========================================"
echo "镜像同步任务完成"
echo "总数: $TOTAL"
echo "成功: $SUCCESS"
echo "失败: $FAILED"
echo "========================================"

[[ "$FAILED" -eq 0 ]]
