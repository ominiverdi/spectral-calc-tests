#!/bin/bash
set -e

# GeoSpectraCalc Benchmark Runner
# This script runs all implementations and generates a comprehensive report

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create directories first
echo "Creating directories..."
mkdir -p output
mkdir -p benchmark_reports

# Get date and hostname for report filename
DATE=$(date +"%Y-%m-%d")
HOSTNAME=$(hostname)
REPORT_FILE="benchmark_reports/benchmark_${DATE}_${HOSTNAME}.md"

# Get system information
echo "Gathering system information..."
OS=$(uname -s)
KERNEL=$(uname -r)
if [ "$OS" = "Linux" ]; then
    CPU=$(grep 'model name' /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^ *//')
    CPU_CORES=$(grep -c processor /proc/cpuinfo)
    MEMORY=$(free -h | awk '/^Mem:/ {print $2}')
    DISTRO=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    if [ -z "$DISTRO" ]; then
        DISTRO="Linux"
    fi
elif [ "$OS" = "Darwin" ]; then
    CPU=$(sysctl -n machdep.cpu.brand_string)
    CPU_CORES=$(sysctl -n hw.ncpu)
    MEMORY=$(sysctl -n hw.memsize | awk '{print $0/1024/1024/1024 " GB"}')
    DISTRO=$(sw_vers -productName)
else
    CPU="Unknown"
    CPU_CORES="Unknown"
    MEMORY="Unknown"
    DISTRO="Unknown"
fi

# Initialize arrays to store results
declare -a IMPL_NAMES=()
declare -a RUNTIMES=()
declare -a FILESIZE=()

# Function to run a benchmark and record results
run_benchmark() {
    local name="$1"
    local command="$2"
    local output_file="$3"
    
    echo -e "${YELLOW}Running benchmark: ${name}${NC}"
    
    # Run the benchmark
    start_time=$(date +%s.%3N)
    eval "$command"
    end_time=$(date +%s.%3N)
    
    # Calculate runtime
    runtime=$(echo "$end_time - $start_time" | bc)
    
    # Get output file size
    if [ -f "$output_file" ]; then
        filesize=$(du -h "$output_file" | cut -f1)
    else
        filesize="N/A"
    fi
    
    # Store results
    IMPL_NAMES+=("$name")
    RUNTIMES+=("$runtime")
    FILESIZE+=("$filesize")
    
    echo -e "${GREEN}✓ Completed ${name} in ${runtime}s (Output size: ${filesize})${NC}"
    echo ""
}

# Check for test data
check_data() {
    local data_dir="data"
    local required_files=(
        "T33TTG_20250305T100029_B08_10m.jp2"
        "T33TTG_20250305T100029_B04_10m.jp2"
    )
    
    echo -e "${BLUE}Checking for required data files...${NC}"
    
    for file in "${required_files[@]}"; do
        if [ ! -f "${data_dir}/${file}" ]; then
            echo -e "${RED}Error: Missing required data file: ${data_dir}/${file}${NC}"
            echo "Please download the required data files as mentioned in the README.md"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✓ All required data files are present${NC}"
}

# Generate the report header
generate_report_header() {
    cat > "$REPORT_FILE" << EOF
# GeoSpectraCalc Benchmark Results

## System Information
- **Date:** $(date)
- **Hostname:** $HOSTNAME
- **OS:** $DISTRO ($OS $KERNEL)
- **CPU:** $CPU
- **CPU Cores:** $CPU_CORES
- **Memory:** $MEMORY

## Benchmarks
EOF
}

# Generate the report table
generate_report_table() {
    # Add table header
    cat >> "$REPORT_FILE" << EOF

| Implementation | Runtime (s) | Output Size | Description |
|----------------|------------|-------------|-------------|
EOF
    
    # Sort implementations by runtime (fastest first)
    n=${#IMPL_NAMES[@]}
    declare -a sorted_indices=($(seq 0 $(($n-1))))
    
    # Simple bubble sort
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if (( $(echo "${RUNTIMES[${sorted_indices[$j]}]} > ${RUNTIMES[${sorted_indices[$j+1]}]}" | bc -l) )); then
                temp=${sorted_indices[$j]}
                sorted_indices[$j]=${sorted_indices[$j+1]}
                sorted_indices[$j+1]=$temp
            fi
        done
    done
    
    # Add implementations to table (sorted by runtime)
    for i in "${sorted_indices[@]}"; do
        local description=""
        case "${IMPL_NAMES[$i]}" in
            "C") 
                description="Standard C implementation using GDAL C API"
                ;;
            "Rust (whole-image)") 
                description="Loads entire image, processes in parallel, single write"
                ;;
            "Rust (chunked-parallel)") 
                description="Processes image in chunks with parallel computation per chunk"
                ;;
            "Rust (fixed-point)") 
                description="Uses Int16 fixed-point optimization for smaller output size"
                ;;
            "Rust (direct-gdal)") 
                description="Uses direct GDAL C API bindings"
                ;;
            *) 
                description="No description available"
                ;;
        esac
        
        echo "| ${IMPL_NAMES[$i]} | ${RUNTIMES[$i]} | ${FILESIZE[$i]} | $description |" >> "$REPORT_FILE"
    done
}

# Main execution starts here

echo -e "${BLUE}=======================================================${NC}"
echo -e "${BLUE}       GeoSpectraCalc Performance Benchmark           ${NC}"
echo -e "${BLUE}=======================================================${NC}"

# Check for required data files
check_data

# Generate report header
generate_report_header

# Run benchmarks
echo -e "${BLUE}Running benchmarks...${NC}"
echo -e "${YELLOW}This may take several minutes. Please be patient.${NC}"
echo ""

# C implementation
if [ -d "c" ]; then
    run_benchmark "C" "cd c && bash compile_and_run.sh" "output/c.tif"
fi

# Rust implementations
if [ -d "rust" ]; then
    # Whole-image implementation
    run_benchmark "Rust (whole-image)" "cd rust && bash test-whole-image.sh" "output/rust_whole_image.tif"
    
    # Chunked-parallel implementation
    run_benchmark "Rust (chunked-parallel)" "cd rust && bash test-chunked-parallel.sh" "output/rust_chunked_parallel.tif"
    
    # Fixed-point implementation
    run_benchmark "Rust (fixed-point)" "cd rust && bash test-fixed-point.sh" "output/rust_fixed_point.tif"
    
    # Direct GDAL implementation
    run_benchmark "Rust (direct-gdal)" "cd rust && bash test-direct.sh" "output/rust_direct_gdal.tif"
fi

# Generate report table
generate_report_table

echo -e "${GREEN}Benchmark complete! Report saved to: ${REPORT_FILE}${NC}"
echo ""
echo -e "${BLUE}Summary of results (fastest to slowest):${NC}"

# Sort and display summary
n=${#IMPL_NAMES[@]}
declare -a sorted_indices=($(seq 0 $(($n-1))))

# Simple bubble sort
for ((i=0; i<n-1; i++)); do
    for ((j=0; j<n-i-1; j++)); do
        if (( $(echo "${RUNTIMES[${sorted_indices[$j]}]} > ${RUNTIMES[${sorted_indices[$j+1]}]}" | bc -l) )); then
            temp=${sorted_indices[$j]}
            sorted_indices[$j]=${sorted_indices[$j+1]}
            sorted_indices[$j+1]=$temp
        fi
    done
done

# Display summary
for i in "${sorted_indices[@]}"; do
    echo -e "${GREEN}${IMPL_NAMES[$i]}:${NC} ${RUNTIMES[$i]}s (${FILESIZE[$i]})"
done

echo ""
echo -e "${BLUE}To view the full report, open:${NC} ${REPORT_FILE}"