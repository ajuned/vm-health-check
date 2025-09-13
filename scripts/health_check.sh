check_cpu() {
  os="$(uname -s)"

  if [ "$os" = "Darwin" ]; then
    # macOS: "CPU usage: 3.29% user, 5.13% sys, 91.56% idle"
    idle=$(top -l 1 | awk -F'[:, ]+' '/CPU usage/ {for(i=1;i<=NF;i++) if($i=="idle") print $(i-1)}')
    # usage = 100 - idle
    usage=$(awk -v idle="$idle" 'BEGIN {printf "%.2f", 100 - idle}')
  else
    # Linux: "Cpu(s):  7.6%us, 2.3%sy, ... 89.8%id, ..."
    idle=$(top -bn1 | awk -F',' '/Cpu\\(s\\)/ {for(i=1;i<=NF;i++) if($i ~ /id/) {gsub(/[^0-9.]/,"",$i); print $i}}')
    usage=$(awk -v idle="$idle" 'BEGIN {printf "%.2f", 100 - idle}')
  fi

  # decide status
  if awk "BEGIN {exit !($usage > 85)}"; then
    echo "CPU: ${usage}%  Critical"
    return 2
  elif awk "BEGIN {exit !($usage >= 70)}"; then
    echo "CPU: ${usage}%  Warning"
    return 1
  else
    echo "CPU: ${usage}%  OK"
    return 0
  fi
}
check_mem() {
   echo "[Memory] check placeholder"
}
check_disk() {
   echo "[Disk] check placeholder"
}
main() {
   if [ "$1" == "--explain" ]; then
      echo "Running in explain mode..."
      explain_mode=true
   else
      explain_mode=false
   fi

   check_cpu
   check_mem
   check_disk
}

main "$@"

