check_cpu() {
  os="$(uname -s)"
  if [ "$os" = "Darwin" ]; then
    # macOS: "CPU usage: 3.29% user, 5.13% sys, 91.56% idle"
    idle=$(top -l 1 | awk -F'[:, ]+' '/CPU usage/ {for(i=1;i<=NF;i++) if($i=="idle") print $(i-1)}')
    usage=$(awk -v idle="$idle" 'BEGIN {printf "%.2f", 100 - idle}')
  else
    # Linux: "Cpu(s):  7.6%us, ... 89.8%id, ..."
    idle=$(top -bn1 | awk -F',' '/Cpu\(s\)/ {for(i=1;i<=NF;i++) if($i ~ /id/) {gsub(/[^0-9.]/,"",$i); print $i}}')
    usage=$(awk -v idle="$idle" 'BEGIN {printf "%.2f", 100 - idle}')
  fi
  cpu_usage="$usage"
  if awk -v u="$usage" 'BEGIN{ exit !(u>85) }'; then
    echo "CPU: ${usage}%  Critical"
    return 2
  elif awk -v u="$usage" 'BEGIN{ exit !(u>=70) }'; then
    echo "CPU: ${usage}%  Warning"
    return 1
  else
    echo "CPU: ${usage}%  OK"
    return 0
  fi
}

# -------- Memory --------
check_mem() {
  os="$(uname -s)"

  if [ "$os" = "Darwin" ]; then
    page_size=$(sysctl -n hw.pagesize)
    free=$(vm_stat | awk '/Pages free/ {gsub("\\.",""); print $3}')
    inactive=$(vm_stat | awk '/Pages inactive/ {gsub("\\.",""); print $3}')
    total=$(sysctl -n hw.memsize)
    free_bytes=$(( (free + inactive) * page_size ))
    used_bytes=$(( total - free_bytes ))
    usage=$(awk -v u="$used_bytes" -v t="$total" 'BEGIN{ printf "%.2f", (u/t)*100 }')
  else
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    used=$((mem_total - mem_avail))
    usage=$(awk -v u="$used" -v t="$mem_total" 'BEGIN{ printf "%.2f", (u/t)*100 }')
  fi
  mem_usage="$usage"
  if awk -v u="$usage" 'BEGIN{ exit !(u>90) }'; then
    echo "Memory: ${usage}%  Critical"
    return 2
  elif awk -v u="$usage" 'BEGIN{ exit !(u>=75) }'; then
    echo "Memory: ${usage}%  Warning"
    return 1
  else
    echo "Memory: ${usage}%  OK"
    return 0
  fi
}

# -------- Disk (先给可用版本，后面可再增强) --------
check_disk() {
  # 仅检查根分区 /
  if df -P / >/dev/null 2>&1; then
    used=$(df -P / | awk 'END{gsub("%","",$5); print $5}')
  else
    echo "Disk: N/A"
    disk_usage="N/A"
    return 0
  fi
  disk_usage="$used"
  if awk -v u="$used" 'BEGIN{ exit !(u>80) }'; then
    echo "Disk: ${used}%  Warning"
    return 1
  else
    echo "Disk: ${used}%  OK"
    return 0
  fi

}

main() {
  if [ "$1" = "--explain" ]; then
    echo "Running in explain mode..."
    explain_mode=true
  else
    explain_mode=false
  fi

  check_cpu;  cpu_s=$?
  check_mem;  mem_s=$?
  check_disk; disk_s=$?

  if [ "$1" = "--json" ]; then
    echo "{"
    echo "  \"cpu_usage\": \"${cpu_usage}%\","
    echo "  \"mem_usage\": \"${mem_usage}%\","
    echo "  \"disk_usage\": \"${disk_usage}%\""
    echo "}"
    exit 0
  fi

  if $explain_mode; then
    [ $cpu_s  -eq 2 ] && echo "⚠ CPU 使用率过高，可能影响性能。"
    [ $mem_s  -eq 2 ] && echo "⚠ 内存占用过高，可能导致系统卡顿/触发 OOM。"
    [ $disk_s -eq 1 ] && echo "⚠ 磁盘空间紧张，可能导致写入失败或服务异常。"
  fi

  # 汇总退出码（2 > 1 > 0）
  if [ $cpu_s -eq 2 ] || [ $mem_s -eq 2 ]; then
    exit 2
  elif [ $cpu_s -eq 1 ] || [ $disk_s -eq 1 ]; then
    exit 1
  else
    exit 0
  fi
}

main "$@"
