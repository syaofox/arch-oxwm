#!/bin/bash
# 图片格式转换脚本
# 用法: fm-convert-image.sh <目标格式> <文件1> [文件2] ...

# 检查参数
if [ $# -lt 2 ]; then
    zenity --error --text="参数不足！\n用法: fm-convert-image.sh <目标格式> <文件1> [文件2] ..."
    exit 1
fi

TARGET_FORMAT="$1"
shift

# 检查是否安装了 ImageMagick 或 ffmpeg
HAS_IMAGEMAGICK=false
HAS_FFMPEG=false

if command -v convert &> /dev/null; then
    HAS_IMAGEMAGICK=true
fi

if command -v ffmpeg &> /dev/null; then
    HAS_FFMPEG=true
fi

if [ "$HAS_IMAGEMAGICK" = false ] && [ "$HAS_FFMPEG" = false ]; then
    zenity --error --text="未找到图片转换工具！\n请安装 ImageMagick (推荐) 或 ffmpeg\n\n安装命令:\nsudo apt install imagemagick\n或\nsudo apt install ffmpeg"
    exit 1
fi

# 转换函数
convert_image() {
    local input_file="$1"
    local output_file="$2"
    local format="$3"
    
    # 检查输入文件是否存在
    if [ ! -f "$input_file" ]; then
        echo "错误: 文件不存在: $input_file"
        return 1
    fi
    
    # 检查是否为图片文件
    if ! file "$input_file" | grep -qiE "image|bitmap"; then
        echo "错误: 不是有效的图片文件: $input_file"
        return 1
    fi
    
    # 使用 ImageMagick 转换（优先）
    if [ "$HAS_IMAGEMAGICK" = true ]; then
        if convert "$input_file" "$output_file" 2>/dev/null; then
            return 0
        fi
    fi
    
    # 使用 ffmpeg 转换（备选）
    if [ "$HAS_FFMPEG" = true ]; then
        # ffmpeg 需要指定输出格式
        case "$format" in
            jpg|jpeg)
                if ffmpeg -i "$input_file" -y -q:v 2 "$output_file" 2>/dev/null; then
                    return 0
                fi
                ;;
            png)
                if ffmpeg -i "$input_file" -y -pix_fmt rgba "$output_file" 2>/dev/null; then
                    return 0
                fi
                ;;
            webp)
                if ffmpeg -i "$input_file" -y -c:v libwebp -quality 80 "$output_file" 2>/dev/null; then
                    return 0
                fi
                ;;
            *)
                if ffmpeg -i "$input_file" -y "$output_file" 2>/dev/null; then
                    return 0
                fi
                ;;
        esac
    fi
    
    return 1
}

# 处理每个文件
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FILES=""

for input_file in "$@"; do
    # 获取文件绝对路径
    ABS_INPUT=$(readlink -f "$input_file" 2>/dev/null || realpath "$input_file" 2>/dev/null || echo "$input_file")
    
    # 获取文件目录和基础名称（不含扩展名）
    DIR_NAME="$(dirname "$ABS_INPUT")"
    BASE_NAME="$(basename "$ABS_INPUT")"
    NAME_WITHOUT_EXT="${BASE_NAME%.*}"

    # 生成输出文件名
    OUTPUT_FILE="${DIR_NAME}/${NAME_WITHOUT_EXT}.${TARGET_FORMAT}"
    
    # 如果输出文件已存在，询问是否覆盖
    if [ -f "$OUTPUT_FILE" ]; then
        if ! zenity --question --text="文件已存在:\n${OUTPUT_FILE}\n\n是否覆盖？" --title="文件已存在" 2>/dev/null; then
            echo "跳过: $OUTPUT_FILE"
            continue
        fi
    fi
    
    # 执行转换
    if convert_image "$ABS_INPUT" "$OUTPUT_FILE" "$TARGET_FORMAT"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo "成功: $OUTPUT_FILE"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_FILES="${FAILED_FILES}""${BASE_NAME}"$'\n'
        echo "失败: $ABS_INPUT"
    fi
done

# 显示结果
if [ $FAIL_COUNT -eq 0 ]; then
    zenity --info --text="转换完成！\n\n成功: ${SUCCESS_COUNT} 个文件" --title="转换成功"
else
    zenity --warning --text="转换完成\n\n成功: ${SUCCESS_COUNT} 个文件\n失败: ${FAIL_COUNT} 个文件\n\n失败的文件:\n${FAILED_FILES}" --title="转换结果"
fi

exit 0
