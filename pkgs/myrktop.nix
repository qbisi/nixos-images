{
  lib,
  python3Packages,
  fetchFromGitHub,
  lm_sensors,
  smartmontools,
}:
python3Packages.buildPythonApplication rec {
  pname = "myrktop";
  version = "0-unstable-2025-4-22";
  format = "other";

  src = fetchFromGitHub {
    owner = "mhl221135";
    repo = "myrktop";
    rev = "246d8285aa21ae08bbfeb99ebdb34819561b021f";
    hash = "sha256-X70xgIBhxDs8LSvgOzICWBUON6faY+d0vEVu1xOS378=";
  };

  pythonPath = with python3Packages; [
    urwid
    wcwidth
    typing-extensions
  ];

  dontBuild = true;

  installPhase = ''
    buildPythonPath $pythonPath
    patchPythonScript myrktop.py
    substituteInPlace myrktop.py \
      --replace-fail "uptime -p" "uptime" \
      --replace-fail "sensors" "${lib.getExe lm_sensors}" \
      --replace-fail "sudo smartctl" "${lib.getExe' smartmontools "smartctl"}"
    install -Dm755 myrktop.py $out/bin/myrktop
  '';

  dontFixup = true;

  meta = {
    description = "Orange Pi 5 (RK3588) System Monitoring script";
    homepage = "https://github.com/mhl221135/myrktop";
    license = lib.licenses.mit;
    platform = lib.platform.linux;
    maintainers = lib.maintainers.qbisi;
  };
}
