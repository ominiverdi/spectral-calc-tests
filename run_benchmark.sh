#!/bin/bash

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BENCHMARK_REPORT_DIR="${SCRIPT_DIR}/benchmark_reports"
BENCHMARK_FILE="${BENCHMARK_REPORT_DIR}/benchmark_$(date +%Y-%m-%d)_$(hostname).md"

mkdir -p output benchmark_reports

echo -e "${GREEN}===== GeoSpectraCalc Performance Benchmark =====${NC}"

# Set environment variables
export GDAL_INCLUDE_DIR=/usr/include/gdal
export GDAL_LIB_DIR=/usr/lib/x86_64-linux-gnu
export GDAL_DYNAMIC=YES
export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -Awarnings"

# Prepare C implementation
echo "Compiling C implementation..."
(cd $SCRIPT_DIR/c && gcc -Wall -O3 -march=native -o ndvi_calculator calculate_ndvi.c $(gdal-config --cflags) $(gdal-config --libs) >/dev/null 2>&1)

# Function to compile and run a Rust implementation
compile_and_run_rust() {
    local name=$1
    local bin_name=$2    # binary name (e.g., "whole-image-impl")
    local output_file=$3
    
    echo -e "\n${YELLOW}Compiling ${CYAN}$name${YELLOW}...${NC}"
    (cd $SCRIPT_DIR/rust && \
     cargo build --release --bin $bin_name --quiet)
    
    echo -e "${GREEN}Running ${CYAN}$name${GREEN}...${NC}"
    
    start_time=$(date +%s.%N)
    (cd $SCRIPT_DIR/rust && ./target/release/$bin_name >/tmp/benchmark_output.log 2>&1)
    RESULT=$?
    end_time=$(date +%s.%N)
    
    # Rest of the function remains the same
    if [ $RESULT -ne 0 ]; then
        echo -e "${RED}ERROR: $name failed with code $RESULT${NC}"
        cat /tmp/benchmark_output.log
        return 1
    fi
    
    runtime=$(echo "$end_time - $start_time" | bc)
    echo -e "Completed in ${YELLOW}$(printf "%.3fs" $runtime)${NC}"
    
    if [ -f "$output_file" ]; then
        filesize=$(du -h "$output_file" | cut -f1)
        echo -e "Output size: ${CYAN}$filesize${NC}"
    else
        filesize="N/A"
    fi
    
    echo "| $name | $(printf "%.3fs" $runtime) | $filesize |" >> "$BENCHMARK_FILE"
}

# Function to run simple benchmark (for C implementation)
run_benchmark() {
    local name=$1
    local command=$2
    local output_file=$3
    
    echo -e "\n${GREEN}Running ${CYAN}$name${GREEN}...${NC}"
    
    start_time=$(date +%s.%N)
    eval "$command" >/tmp/benchmark_output.log 2>&1
    RESULT=$?
    end_time=$(date +%s.%N)
    
    if [ $RESULT -ne 0 ]; then
        echo -e "${RED}ERROR: $name failed with code $RESULT${NC}"
        cat /tmp/benchmark_output.log
        return 1
    fi
    
    runtime=$(echo "$end_time - $start_time" | bc)
    echo -e "Completed in ${YELLOW}$(printf "%.3fs" $runtime)${NC}"
    
    if [ -f "$output_file" ]; then
        filesize=$(du -h "$output_file" | cut -f1)
        echo -e "Output size: ${CYAN}$filesize${NC}"
    else
        filesize="N/A"
    fi
    
    echo "| $name | $(printf "%.3fs" $runtime) | $filesize |" >> "$BENCHMARK_FILE"
}

# Initialize benchmark report
{
  echo "# GeoSpectraCalc Benchmark Results"
  echo "- **Date:** $(date)"
  echo "- **System:** $(hostname)"
  echo "- **CPU:** $(grep 'model name' /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^ *//')"
  echo "- **Cores:** $(grep -c ^processor /proc/cpuinfo) logical, $(lscpu -p | grep -v '^#' | sort -u -t, -k 2,2 | wc -l) physical"
  echo "- **Memory:** $(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)" GB RAM"}')"
  echo "## Results"
  echo "| Implementation | Runtime | Output Size |"
  echo "|----------------|---------|------------|"
} > "$BENCHMARK_FILE"

# Run benchmarks
run_benchmark "C" "cd $SCRIPT_DIR/c && ./ndvi_calculator" "$SCRIPT_DIR/output/c.tif"
compile_and_run_rust "Rust (whole-image)" "whole-image-impl" "$SCRIPT_DIR/output/rust_whole_image.tif"
compile_and_run_rust "Rust (chunked-parallel)" "chunked-parallel-impl" "$SCRIPT_DIR/output/rust_chunked_parallel.tif"
compile_and_run_rust "Rust (fixed-point)" "fixed-point-impl" "$SCRIPT_DIR/output/rust_fixed_point.tif"
compile_and_run_rust "Rust (direct-gdal)" "direct-gdal-impl" "$SCRIPT_DIR/output/rust_direct_gdal.tif"


# Optional: GDAL calc test
if [ -d "$SCRIPT_DIR/gdal_calc" ]; then
  echo -e "\n${GREEN}Running ${CYAN}GDAL calc${GREEN}...${NC}"
  start_time=$(date +%s.%N)
  (cd $SCRIPT_DIR/gdal_calc && bash calculate_ndvi.sh >/tmp/benchmark_output.log 2>&1)
  RESULT=$?
  end_time=$(date +%s.%N)
  
  if [ $RESULT -eq 0 ]; then
    runtime=$(echo "$end_time - $start_time" | bc)
    echo -e "Completed in ${YELLOW}$(printf "%.3fs" $runtime)${NC}"
    
    output_file="$SCRIPT_DIR/output/gdal_calc.tif"
    if [ -f "$output_file" ]; then
      filesize=$(du -h "$output_file" | cut -f1)
      echo -e "Output size: ${CYAN}$filesize${NC}"
    else
      filesize="N/A"
    fi
    
    echo "| GDAL calc | $(printf "%.3fs" $runtime) | $filesize |" >> "$BENCHMARK_FILE"
  else
    echo -e "${RED}ERROR: GDAL calc test failed${NC}"
    cat /tmp/benchmark_output.log
  fi
fi

# Optional: GRASS GIS test
if [ -d "$SCRIPT_DIR/grass" ]; then
  echo -e "\n${GREEN}Running ${CYAN}GRASS GIS${GREEN}...${NC}"
  start_time=$(date +%s.%N)
  (cd $SCRIPT_DIR/grass && bash calculate_ndvi.sh >/tmp/benchmark_output.log 2>&1)
  RESULT=$?
  end_time=$(date +%s.%N)
  
  if [ $RESULT -eq 0 ]; then
    runtime=$(echo "$end_time - $start_time" | bc)
    echo -e "Completed in ${YELLOW}$(printf "%.3fs" $runtime)${NC}"
    
    output_file="$SCRIPT_DIR/output/grass_ndvi.tif"
    if [ -f "$output_file" ]; then
      filesize=$(du -h "$output_file" | cut -f1)
      echo -e "Output size: ${CYAN}$filesize${NC}"
    else
      filesize="N/A"
    fi
    
    echo "| GRASS GIS | $(printf "%.3fs" $runtime) | $filesize |" >> "$BENCHMARK_FILE"
  else
    echo -e "${RED}ERROR: GRASS GIS test failed${NC}"
    cat /tmp/benchmark_output.log
  fi
fi

echo -e "\n${GREEN}Benchmark completed successfully${NC}"
echo -e "Results saved to ${CYAN}$BENCHMARK_FILE${NC}"