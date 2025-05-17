#!/bin/bash
set -e

# Base directory for DXC installations
DXC_BASE_DIR="/opt/dxc"
CACHE_DIR="${DXC_BASE_DIR}/cache"
GITHUB_RELEASE_URL="https://github.com/microsoft/DirectXShaderCompiler/releases/download"

# Version mapping - maps version numbers to release dates (YYYY_MM_DD format)
declare -A VERSION_MAP
VERSION_MAP["1.7.2212.1"]="2023_03_01"
VERSION_MAP["1.7.2308"]="2023_08_14"
VERSION_MAP["1.8.2306-preview"]="2023_06_22"
VERSION_MAP["1.8.2403"]="2024_03_11"
VERSION_MAP["1.8.2403.1"]="2024_03_22"
VERSION_MAP["1.8.2403.2"]="2024_04_02"
VERSION_MAP["1.8.2405"]="2024_05_28"
VERSION_MAP["1.8.2405-mesh-nodes-preview"]="2024_07_18"
VERSION_MAP["1.8.2407"]="2024_07_31"
VERSION_MAP["1.8.2502"]="2025_02_20"

# Default version (latest stable)
DEFAULT_VERSION="${DXC_VERSION:-1.8.2502}"

# Function to verify if a file is a valid tar.gz archive
verify_tar_gz() {
    local file=$1
    
    # Check file exists
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Check if it's a valid gzip file by reading the first few bytes
    if ! gzip -t "$file" 2>/dev/null; then
        echo "Error: File is not a valid gzip archive" >&2
        return 1
    fi
    
    return 0
}

# Function to download and install a specific DXC version
install_dxc_version() {
    local version=$1
    local date_code=${VERSION_MAP[$version]}
    
    if [ -z "$date_code" ]; then
        echo "Error: Unknown DXC version $version" >&2
        echo "Available versions:" >&2
        for v in "${!VERSION_MAP[@]}"; do
            echo "  $v" >&2
        done
        return 1
    fi
    
    local install_dir="${DXC_BASE_DIR}/${version}"
    local download_url
    local archive_name
    
    # Skip if already installed
    if [ -x "${install_dir}/bin/dxc" ]; then
        echo "DXC version $version is already installed" >&2
        
        # Ensure symlinks are created
        ln -sf "${install_dir}/bin/dxc" "${DXC_BASE_DIR}/bin/dxc"
        if [ "$(ls -A "${install_dir}/lib/" 2>/dev/null)" ]; then
            ln -sf "${install_dir}/lib/"* "${DXC_BASE_DIR}/lib/"
        fi
        if [ "$(ls -A "${install_dir}/include/" 2>/dev/null)" ]; then
            ln -sf "${install_dir}/include/"* "${DXC_BASE_DIR}/include/"
        fi
        
        return 0
    fi
    
    # Create directories
    mkdir -p "${install_dir}" "${CACHE_DIR}"
    
    # Determine download URL and archive name based on version
    if [[ $version == *"preview"* ]]; then
        # Preview versions have a different naming pattern
        tag="v${version}"
        # For preview versions, we need to check the specific naming pattern
        if [[ $version == "1.8.2405-mesh-nodes-preview" ]]; then
            archive_name="linux_dxc_mesh_nodes_preview.x86_64.tar.gz"
        else
            archive_name="linux_dxc_preview.x86_64.tar.gz"
        fi
    else
        # Regular versions
        tag="v${version}"
        archive_name="linux_dxc_${date_code}.x86_64.tar.gz"
    fi
    
    download_url="${GITHUB_RELEASE_URL}/${tag}/${archive_name}"
    local cache_path="${CACHE_DIR}/${archive_name}"
    
    # Download the archive if not in cache
    if [ ! -f "${cache_path}" ]; then
        echo "Downloading DXC version $version from $download_url" >&2
        
        # Use curl with output to a temporary file first
        local temp_file="${cache_path}.tmp"
        if ! curl -L -f -o "${temp_file}" "${download_url}"; then
            echo "Error: Failed to download DXC version $version from ${download_url}" >&2
            echo "HTTP request failed or returned an error status code" >&2
            rm -f "${temp_file}"
            return 1
        fi
        
        # Verify the downloaded file is a valid tar.gz archive
        if ! verify_tar_gz "${temp_file}"; then
            echo "Error: Downloaded file is not a valid tar.gz archive" >&2
            echo "URL: ${download_url}" >&2
            echo "This might be an HTML error page or invalid content" >&2
            rm -f "${temp_file}"
            return 1
        fi
        
        # Move the verified file to the cache
        mv "${temp_file}" "${cache_path}"
    fi
    
    # Verify the cached file is a valid tar.gz archive
    if ! verify_tar_gz "${cache_path}"; then
        echo "Error: Cached file is not a valid tar.gz archive" >&2
        echo "Please delete ${cache_path} and try again" >&2
        return 1
    fi
    
    # Extract the archive
    echo "Installing DXC version $version to ${install_dir}" >&2
    
    # Create a temporary directory for extraction
    local temp_dir=$(mktemp -d)
    
    # Extract to the temporary directory
    if ! tar -xzf "${cache_path}" -C "${temp_dir}"; then
        echo "Error: Failed to extract archive ${cache_path}" >&2
        rm -rf "${temp_dir}"
        return 1
    fi
    
    # Debug: Show the extracted directory structure
    echo "Extracted archive contents:" >&2
    find "${temp_dir}" -type f | sort >&2
    
    # Create bin, lib, and include directories
    mkdir -p "${install_dir}/bin" "${install_dir}/lib" "${install_dir}/include"
    
    # Find and move the files to the correct locations
    # First, check if we have the expected files
    if find "${temp_dir}" -name "dxc" -type f | grep -q .; then
        # Move dxc executable to bin directory
        find "${temp_dir}" -name "dxc" -type f -exec cp {} "${install_dir}/bin/" \;
        chmod +x "${install_dir}/bin/dxc"
        
        # Move library files to lib directory
        find "${temp_dir}" -name "libdxcompiler.so*" -type f -exec cp {} "${install_dir}/lib/" \;
        find "${temp_dir}" -name "libdxil.so*" -type f -exec cp {} "${install_dir}/lib/" \;
        
        # Move header files to include directory
        find "${temp_dir}" -name "*.h" -type f -exec cp {} "${install_dir}/include/" \;
    else
        # Try to find the dxc executable in any subdirectory
        echo "Searching for dxc executable in subdirectories..." >&2
        
        # Look for any executable file that might be dxc
        local dxc_candidates=$(find "${temp_dir}" -type f -executable)
        if [ -n "$dxc_candidates" ]; then
            echo "Found executable candidates:" >&2
            echo "$dxc_candidates" >&2
            
            # Try to identify dxc by checking file output
            for candidate in $dxc_candidates; do
                if file "$candidate" | grep -q "ELF.*executable"; then
                    echo "Found potential DXC executable: $candidate" >&2
                    cp "$candidate" "${install_dir}/bin/dxc"
                    chmod +x "${install_dir}/bin/dxc"
                    break
                fi
            done
        fi
        
        # Look for library files
        local lib_candidates=$(find "${temp_dir}" -name "*.so*" -type f)
        if [ -n "$lib_candidates" ]; then
            echo "Found library candidates:" >&2
            echo "$lib_candidates" >&2
            
            # Copy all .so files to lib directory
            for lib in $lib_candidates; do
                cp "$lib" "${install_dir}/lib/"
            done
        fi
        
        # Look for header files
        local header_candidates=$(find "${temp_dir}" -name "*.h" -type f)
        if [ -n "$header_candidates" ]; then
            # Copy all .h files to include directory
            for header in $header_candidates; do
                cp "$header" "${install_dir}/include/"
            done
        fi
    fi
    
    # Clean up temporary directory
    rm -rf "${temp_dir}"
    
    # Make sure dxc is executable
    if [ -f "${install_dir}/bin/dxc" ]; then
        chmod +x "${install_dir}/bin/dxc"
    else
        echo "Error: dxc executable not found after installation" >&2
        echo "Archive structure may be different than expected" >&2
        return 1
    fi
    
    # Create directories for symlinks if they don't exist
    mkdir -p "${DXC_BASE_DIR}/bin" "${DXC_BASE_DIR}/lib" "${DXC_BASE_DIR}/include"
    
    # Create symlinks in the current active version directory
    ln -sf "${install_dir}/bin/dxc" "${DXC_BASE_DIR}/bin/dxc"
    
    # Only create lib symlinks if there are files to link
    if [ "$(ls -A "${install_dir}/lib/" 2>/dev/null)" ]; then
        ln -sf "${install_dir}/lib/"* "${DXC_BASE_DIR}/lib/"
    fi
    
    # Only create include symlinks if there are files to link
    if [ "$(ls -A "${install_dir}/include/" 2>/dev/null)" ]; then
        ln -sf "${install_dir}/include/"* "${DXC_BASE_DIR}/include/"
    fi
    
    # Verify the installation
    if [ ! -x "${DXC_BASE_DIR}/bin/dxc" ]; then
        echo "Error: DXC executable symlink not found after installation" >&2
        return 1
    fi
    
    echo "Successfully installed DXC version $version" >&2
    return 0
}

# Create base directories
mkdir -p "${DXC_BASE_DIR}/bin" "${DXC_BASE_DIR}/lib" "${DXC_BASE_DIR}/include"

# Parse arguments to check for version specification
version="$DEFAULT_VERSION"
args=()

for arg in "$@"; do
    if [[ "$arg" =~ ^--v=(.+)$ ]]; then
        version="${BASH_REMATCH[1]}"
    else
        args+=("$arg")
    fi
done

# Install the requested version
if ! install_dxc_version "$version"; then
    exit 1
fi

# Verify dxc executable exists
if [ ! -x "${DXC_BASE_DIR}/bin/dxc" ]; then
    echo "Error: DXC executable not found after installation" >&2
    echo "Please check the installation process" >&2
    exit 1
fi

# If no arguments provided or first argument is --v, show usage
if [ ${#args[@]} -eq 0 ] || [[ "${args[0]}" =~ ^--v= ]]; then
    echo "DirectX Compiler (DXC) Docker Image" >&2
    echo "Usage: docker run dxc [--v=VERSION] [DXC_ARGS...]" >&2
    echo "Available versions:" >&2
    for v in "${!VERSION_MAP[@]}"; do
        echo "  $v" >&2
    done
    echo "Current version: $version" >&2
    echo "For DXC help: docker run dxc --help" >&2
    exit 0
fi

# Execute dxc with the remaining arguments
exec "${DXC_BASE_DIR}/bin/dxc" "${args[@]}"
