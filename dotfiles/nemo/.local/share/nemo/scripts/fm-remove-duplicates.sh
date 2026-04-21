#!/bin/bash

# 如果没有参数，退出
if [ $# -eq 0 ]; then
    exit 0
fi

# 选择条件：
# - 至少选中一个文件夹，或者
# - 选中多个（>=2）文件或文件夹
items=("$@")
count=${#items[@]}

has_dir=0
for p in "${items[@]}"; do
    if [ -d "$p" ]; then
        has_dir=1
        break
    fi
done

if [ "$has_dir" -eq 0 ] && [ "$count" -lt 2 ]; then
    zenity --error --title="重复文件清理" --text="请至少选中一个文件夹，或者选中多个文件/文件夹后再运行\"删除重复项\"。" --width=360
    exit 0
fi

# 将选中的路径展开成"要检查的文件列表"：
# - 普通文件：直接加入
# - 目录：递归 find 目录下的所有普通文件
files_to_check=()
for p in "${items[@]}"; do
    if [ -f "$p" ]; then
        files_to_check+=("$p")
    elif [ -d "$p" ]; then
        while IFS= read -r -d '' f; do
            files_to_check+=("$f")
        done < <(find "$p" -type f -print0)
    fi
done

# 如果最终没有可检查的文件，给出提示后退出
if [ ${#files_to_check[@]} -eq 0 ]; then
    zenity --info --title="重复文件清理" --text="选中的项目中没有可用的普通文件可供检查。" --width=360
    exit 0
fi

# 临时文件
HASH_TO_FILES_FILE=$(mktemp)  # 存储哈希值到文件列表的映射（格式：hash|file）
DUPLICATES_FILE=$(mktemp)

# 标题
TITLE="重复文件清理"

# 进度条处理
(
    total=${#files_to_check[@]}
    processed=0
    
    # 第一步：按文件大小分组（只有相同大小的文件才可能是重复的）
    echo "# 第一步：按文件大小分组..."
    declare -A size_groups
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
            if [ -n "$size" ]; then
                size_groups["$size"]+="$file"$'\n'
            fi
        fi
        ((processed++))
        progress=$((processed * 30 / total))
        echo "$progress"
        echo "# 正在分组: $(basename "$file")"
    done
    
    # 统计需要比对的文件数量（相同大小的文件组中，每组至少2个文件）
    files_to_hash=0
    for size in "${!size_groups[@]}"; do
        mapfile -t same_size_files < <(echo -n "${size_groups[$size]}" | grep -v '^$')
        if [ ${#same_size_files[@]} -gt 1 ]; then
            files_to_hash=$((files_to_hash + ${#same_size_files[@]}))
        fi
    done
    
    # 第二步：对相同大小的文件进行比对
    echo "# 第二步：比对可能重复的文件..."
    processed=0
    
    for size in "${!size_groups[@]}"; do
        # 获取该大小下的所有文件
        mapfile -t same_size_files < <(echo -n "${size_groups[$size]}" | grep -v '^$')
        
        # 如果只有一个文件，跳过（不可能有重复）
        if [ ${#same_size_files[@]} -le 1 ]; then
            continue
        fi
        
        # 按修改时间分组（优化：相同修改时间的文件更可能是重复的，优先处理）
        declare -A mtime_groups
        declare -A processed_files  # 记录已处理的文件，避免重复计算MD5
        
        for file in "${same_size_files[@]}"; do
            mtime=$(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file" 2>/dev/null)
            if [ -n "$mtime" ]; then
                mtime_groups["$mtime"]+="$file"$'\n'
            fi
        done
        
        # 第一步：优先处理相同修改时间的文件组（这些更可能是重复的，效率更高）
        # 对于相同修改时间的多个文件，组内比对可以快速发现重复
        for mtime in "${!mtime_groups[@]}"; do
            mapfile -t same_mtime_files < <(echo -n "${mtime_groups[$mtime]}" | grep -v '^$')
            
            # 如果只有一个文件，跳过组内比对，但后续仍会与其他修改时间的文件比对
            if [ ${#same_mtime_files[@]} -le 1 ]; then
                continue
            fi
            
            # 对相同大小和相同修改时间的文件进行MD5比对
            for file in "${same_mtime_files[@]}"; do
                # 计算MD5，只取哈希值
                sum=$(md5sum "$file" 2>/dev/null | cut -d ' ' -f 1)
                
                if [ -z "$sum" ]; then
                    continue
                fi
                
                # 标记为已处理
                processed_files["$file"]=1
                
                # 将文件添加到对应哈希值的文件列表中（格式：hash|file）
                echo "$sum|$file" >> "$HASH_TO_FILES_FILE"
                
                ((processed++))
                if [ $files_to_hash -gt 0 ]; then
                    progress=$((30 + processed * 70 / files_to_hash))
                else
                    progress=100
                fi
                echo "$progress"
                echo "# 正在比对: $(basename "$file")"
            done
        done
        
        # 第二步：处理不同修改时间的文件（确保不遗漏重复文件）
        # 只处理之前未处理过的文件（单文件组），与已记录的哈希进行比对
        for file in "${same_size_files[@]}"; do
            # 如果已经处理过，跳过
            if [ -n "${processed_files[$file]}" ]; then
                continue
            fi
            
            # 计算MD5，只取哈希值
            sum=$(md5sum "$file" 2>/dev/null | cut -d ' ' -f 1)
            
            if [ -z "$sum" ]; then
                continue
            fi
            
            # 将文件添加到对应哈希值的文件列表中（格式：hash|file）
            echo "$sum|$file" >> "$HASH_TO_FILES_FILE"
            
            ((processed++))
            if [ $files_to_hash -gt 0 ]; then
                progress=$((30 + processed * 70 / files_to_hash))
            else
                progress=100
            fi
            echo "$progress"
            echo "# 正在比对: $(basename "$file")"
        done
        
        # 清理当前大小的变量
        unset mtime_groups
        unset processed_files
    done
    
    echo "100"
    echo "# 分析完成，正在确定要删除的文件..."
) | zenity --progress --title="$TITLE" --text="正在分析文件..." --percentage=0 --auto-close

# 第三步：对每个哈希值的文件列表按修改时间排序，保留最旧的那个
# 按哈希值分组处理
sort -t'|' -k1 "$HASH_TO_FILES_FILE" | {
    current_hash=""
    files_for_hash=()
    
    while IFS='|' read -r hash file; do
        if [ "$hash" != "$current_hash" ]; then
            # 处理上一个哈希值的文件列表
            if [ -n "$current_hash" ] && [ ${#files_for_hash[@]} -gt 1 ]; then
                # 创建临时文件用于排序
                temp_sort_file=$(mktemp)
                for f in "${files_for_hash[@]}"; do
                    mtime=$(stat -c%Y "$f" 2>/dev/null || stat -f%m "$f" 2>/dev/null)
                    if [ -n "$mtime" ]; then
                        echo "$mtime|$f" >> "$temp_sort_file"
                    fi
                done
                
                # 按修改时间排序（最旧的在前），保留第一个，其他的添加到删除列表
                sort -t'|' -k1 -n "$temp_sort_file" | {
                    first=1
                    while IFS='|' read -r mtime f; do
                        if [ "$first" -eq 1 ]; then
                            # 第一个文件（最旧的）保留
                            first=0
                        else
                            # 其他文件（较新的）添加到删除列表
                            echo "$f" >> "$DUPLICATES_FILE"
                        fi
                    done
                }
                
                rm -f "$temp_sort_file"
            fi
            
            # 开始新的哈希值
            current_hash="$hash"
            files_for_hash=("$file")
        else
            # 添加到当前哈希值的文件列表
            files_for_hash+=("$file")
        fi
    done
    
    # 处理最后一个哈希值
    if [ -n "$current_hash" ] && [ ${#files_for_hash[@]} -gt 1 ]; then
        temp_sort_file=$(mktemp)
        for f in "${files_for_hash[@]}"; do
            mtime=$(stat -c%Y "$f" 2>/dev/null || stat -f%m "$f" 2>/dev/null)
            if [ -n "$mtime" ]; then
                echo "$mtime|$f" >> "$temp_sort_file"
            fi
        done
        
        sort -t'|' -k1 -n "$temp_sort_file" | {
            first=1
            while IFS='|' read -r mtime f; do
                if [ "$first" -eq 1 ]; then
                    first=0
                else
                    echo "$f" >> "$DUPLICATES_FILE"
                fi
            done
        }
        
        rm -f "$temp_sort_file"
    fi
}

# 检查是否有重复文件
if [ ! -s "$DUPLICATES_FILE" ]; then
    zenity --info --title="$TITLE" --text="在选中的文件中未发现内容重复的项目。" --width=300
    rm -f "$HASH_TO_FILES_FILE" "$DUPLICATES_FILE"
    exit 0
fi

# 统计重复数量
DUP_COUNT=$(wc -l < "$DUPLICATES_FILE")

# 确认对话框
# 使用 text-info 显示列表供用户最后确认
if zenity --text-info \
    --title="确认删除重复项" \
    --text="检测到 $DUP_COUNT 个重复文件。\n\n点击 [确定] 将 PERMANENTLY DELETE (永久删除) 以下副本，只保留一份 originals：\n" \
    --filename="$DUPLICATES_FILE" \
    --width=600 --height=400 \
    --ok-label="确认删除" \
    --cancel-label="取消"; then
    # 执行删除
    # 逐行读取并删除
    # 再次显示进度条
    (
        while IFS= read -r file; do
            echo "# 删除: $(basename "$file")"
            rm -f "$file"
        done < "$DUPLICATES_FILE"
    ) | zenity --progress --pulsate --title="$TITLE" --text="正在删除..." --auto-close
fi

# 清理
rm -f "$HASH_TO_FILES_FILE" "$DUPLICATES_FILE"

