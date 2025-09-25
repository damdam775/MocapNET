# Windows Build Notes

This repository can be built with Microsoft Visual Studio 2022 and the NVIDIA CUDA toolchain on Windows. The project keeps the Linux layout, but adds shims and build logic so the same sources compile on MSVC.

## Prerequisites

1. **CMake** 3.24 or newer and a recent MSVC toolset.
2. **TensorFlow C API for Windows** (GPU or CPU). Download the official `libtensorflow` archive (e.g. `libtensorflow-cpu-windows-x86_64-2.13.0.zip`) from [TensorFlow.org](https://www.tensorflow.org/install/lang_c) and extract it to:
   ```text
   dependencies/libtensorflow/
   ├── include/
   └── lib/
       ├── tensorflow.dll
       ├── tensorflow.lib
       ├── tensorflow_framework.dll
       └── tensorflow_framework.lib
   ```
   The repository’s CMake files will automatically pick up the vendored package when `tensorflow.dll` is present under `dependencies/libtensorflow/lib/`.
3. **OpenCV** through [vcpkg](https://github.com/microsoft/vcpkg):
   ```powershell
   vcpkg install opencv:x64-windows
   ```
   Configure CMake with the vcpkg toolchain, for example:
   ```powershell
   cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE="C:/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake"
   ```
4. An NVIDIA driver compatible with the TensorFlow build you vendor.

## Building

```powershell
cmake -B build -S . -A x64 -DCMAKE_TOOLCHAIN_FILE="C:/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake"
cmake --build build --config Release
```

`_USE_MATH_DEFINES` and the Windows compatibility layer are configured automatically by the top-level `CMakeLists.txt`.

## Notes

- The `src/common/windows_compat.h` header provides implementations for `getline`, `ssize_t`, case-insensitive string helpers, and timing shims that are missing on Windows.
- ANSI color escape sequences are disabled on the Windows console via a shared `console_colors.h` header.
- POSIX-only link libraries (`rt`, `dl`, `m`, `pthread`) are wrapped behind the `MOCAPNET_POSIX_LIBS` variable so that they are not linked when building with MSVC.
- TensorFlow and TensorFlow Framework imported targets now point to `.dll`/`.lib` pairs when `WIN32` is defined.

## Optional

- To keep third-party dependencies reproducible you can create a `vcpkg.json` manifest with the desired ports and use manifest mode (`vcpkg install --feature-flags=manifests`).
