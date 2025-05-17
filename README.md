# DXC Docker

This Docker image provides the [DirectX Compiler](https://github.com/microsoft/DirectXShaderCompiler) (DXC) with flexible version selection, allowing you to specify which version of DXC you want to use at runtime.

## Features

- Supports DXC versions from 1.7 to the [latest available on GitHub](https://github.com/microsoft/DirectXShaderCompiler/releases)
- Version selection via runtime arguments (`--v=1.8.2405`)
- Usable both directly and as a [base image in other Dockerfiles](#using-as-a-base-image)
- Automatically downloads and caches requested versions
- Exposes `dxc` in PATH for easy access

## Usage

### Direct Usage

Run DXC with the default version:

```bash
docker run jasongardner/dxc [DXC_ARGS...]
```

Specify a different version at runtime:

```bash
docker run jasongardner/dxc --v=1.8.2405 [DXC_ARGS...]
```

Example: Compile a shader with a specific version:

```bash
docker run -v $(pwd):/work -w /work jasongardner/dxc --v=1.8.2405 -T ps_6_0 -E main shader.hlsl -Fo shader.bin
```

### Using as a Base Image

You can use this image as a base in your own Dockerfile:

```dockerfile
FROM jasongardner/dxc:latest
# dxc now in PATH
```

Or specify a version in your derived image:

```dockerfile
FROM jasongardner/dxc:1.7
```

To use `dxc` in the next build stages:

```dockerfile
FROM jasongardner/dxc:latest AS dxc
RUN dxc --version

# (Example base image)
FROM python:3.11-slim AS base

# Copy from previous step and add to path
COPY --from=dxc /opt/dxc /opt/dxc
ENV PATH="/opt/dxc/bin:$PATH"
```

## Available Versions

The following DXC versions are supported:

- [1.8.2502 (February 2025)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2502)
- [1.8.2407 (July 2024)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2407)
- [1.8.2405 (May 2024)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2405)
- [1.8.2403.2 (April 2024)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2403.2)
- [1.8.2403.1 (March 2024)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2403.1)
- [1.8.2403 (March 2024)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2403)
- [1.8.2306-preview (June 2023)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2306-preview)
- [1.7.2308 (August 2023)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.7.2308)
- [1.7.2212 (December 2022)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.7.2212)
- [1.7.2207 (July 2022)](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.7.2207)

## Building the Image

To build the Docker image:

```bash
docker build -t jasongardner/dxc:latest .
```

You can specify a default DXC version during build time:

```bash
docker build --build-arg DXC_VERSION=1.7.2308 -t jasongardner/dxc:1.7 .
```

## License

This Docker image is provided under the same license as the DirectX Shader Compiler. See the [DirectX Shader Compiler repository](https://github.com/microsoft/DirectXShaderCompiler) for details.
