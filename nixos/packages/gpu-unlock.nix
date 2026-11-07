{
  lib,
  stdenv,
  kernel,
  kernelModuleMakeFlags,
  fetchFromGitHub,
  fetchurl,
  python3,
  zstd,
}:
let
  nvidiaSource = fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-610.43.03.tar.xz";
    hash = "sha256-fhGJI8eiPtw2EU1jJzpG4+BOmvmGlaQiA+esLf6fwdw=";
  };
  nvidiaInstaller = fetchurl {
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/610.43.03/NVIDIA-Linux-x86_64-610.43.03-no-compat32.run";
    hash = "sha256-4IRFHbcwpt8p09dPZVdJxNI248lF99lLUgXoQxj+L5A=";
  };
in
stdenv.mkDerivation {
  pname = "gpu-unlock";
  version = "2.0.0-${kernel.version}";
  outputs = [ "out" "firmware" ];

  src = fetchFromGitHub {
    owner = "Zagitta";
    repo = "gpu-unlock";
    rev = "7eb51bccae0a0b7e599e084d971170e9a1e82d0c";
    hash = "sha256-1KD/J1S1uyI5GGoTwQ1cU/sXeEKlG54exSvi6U+j73M=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ python3 zstd ];
  hardeningDisable = [ "pic" ];
  dontStrip = true;
  dontPatchELF = true;

  preBuild = ''
    # Extract firmware data only; never execute the NVIDIA installer.
    mkdir nvidia-source assets
    tar -xf ${nvidiaSource} -C nvidia-source --strip-components=1
    python3 firmware/extract_gsp.py ${nvidiaInstaller} assets
    python3 firmware/extract_boot_assets.py nvidia-source assets
    cd kernel/gpu_unlock
  '';

  makeFlags = kernelModuleMakeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall
    # Use the kernel's install rule so NixOS also gets the module certificate.
    make ${lib.escapeShellArgs kernelModuleMakeFlags} \
      -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M="$PWD" INSTALL_MOD_PATH="$out" INSTALL_MOD_DIR=extra DEPMOD=true modules_install
    rm -f "$out/lib/modules/${kernel.modDirVersion}/build"
    cd ../..
    mkdir -p "$firmware/lib/firmware/gpu-unlock/610.43.03"
    install -m644 assets/*.bin "$firmware/lib/firmware/gpu-unlock/610.43.03/"
    install -Dm644 assets/NVIDIA-LICENSE "$firmware/share/licenses/gpu-unlock/NVIDIA-LICENSE"
    install -Dm644 firmware/NOTICE.md "$firmware/share/licenses/gpu-unlock/NOTICE.md"
    install -Dm644 licenses/GPL-2.0.txt "$out/share/licenses/gpu-unlock/GPL-2.0.txt"
    runHook postInstall
  '';

  meta = {
    description = "Opt-in pre-driver tensor throughput unlock for supported NVIDIA GPUs";
    homepage = "https://github.com/Zagitta/gpu-unlock";
    license = [ lib.licenses.gpl2Only lib.licenses.unfree ];
    platforms = [ "x86_64-linux" ];
  };
}
