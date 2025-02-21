#!/bin/bash

# This script creates a concise report of KVM and NVIDIA GPU/audio passthrough logs
# for a specified VM, aiming for a file size of ~3-4 MB.

# Check if the script is run as root (required to access log files)
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# Check if VM name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <VM_NAME>"
    exit 1
fi

vm_name=$1
report_file="passthrough_report.txt"

# Function to append filtered log content with a custom header
append_filtered_log() {
    local log_file=$1
    local header=$2
    local keywords=$3
    local line_limit=500  # Limit to 500 lines per section to control size

    if [ -f "$log_file" ]; then
        echo -e "\n=== $header ===\n" >> "$report_file"
        grep -i "$keywords" "$log_file" | head -n "$line_limit" >> "$report_file"
        if [ "$(grep -i "$keywords" "$log_file" | wc -l)" -gt "$line_limit" ]; then
            echo -e "\n[Note: Limited to $line_limit lines; more entries exist]" >> "$report_file"
        fi
    else
        echo -e "\n=== $header ===\nLog file not found: $log_file" >> "$report_file"
    fi
}

# Clear or create the report file
echo "Passthrough Report for VM: $vm_name" > "$report_file"
echo "Generated on: $(date)" >> "$report_file"

# System Logs for General Passthrough Activity
append_filtered_log "/var/log/syslog" "General System Activity Related to Passthrough" "kvm\|pci\|vfio\|nvidia\|audio"
append_filtered_log "/var/log/kern.log" "Kernel Events for Passthrough" "kvm\|pci\|vfio\|nvidia\|audio"

# KVM Logs for VM-Specific Passthrough
kvm_log="/var/log/libvirt/qemu/$vm_name.log"
append_filtered_log "$kvm_log" "KVM Runtime Logs for $vm_name" "pci\|gpu\|audio\|vfio\|qemu"

# VM Configuration for Passthrough Settings
vm_config="/etc/libvirt/qemu/$vm_name.xml"
append_filtered_log "$vm_config" "VM Configuration Showing Passthrough" "hostdev\|pci"

# NVIDIA Driver Logs
nvidia_log="/var/log/nvidia/nvidia.log"  # Adjust if your system uses a different path
if [ -d "/var/log/nvidia/" ]; then
    append_filtered_log "$nvidia_log" "NVIDIA Driver Activity" "nvidia\|gpu"
else
    append_filtered_log "/var/log/syslog" "NVIDIA Activity (Fallback from Syslog)" "nvidia\|gpu"
fi

# Audit Logs for Hardware Assignment
audit_log="/var/log/audit/audit.log"
append_filtered_log "$audit_log" "Audit Logs for Hardware Assignment" "pci\|audio"

echo -e "\nReport completed. Size: $(du -h "$report_file" | cut -f1)" >> "$report_file"
echo "Report created at $report_file"
