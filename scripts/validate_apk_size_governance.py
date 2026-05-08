#!/usr/bin/env python3.11
"""
Validação textual do módulo P10 — governança de tamanho APK/AAB.

Confirma que o projeto passou a medir baseline de APK/AAB por automação versionada,
que o CI publica relatórios de tamanho e que nenhuma alavanca de redução sensível
foi ativada antes de existir baseline real e validação Flutter/device.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MEASURE_SCRIPT = ROOT / "scripts/measure_android_binary_size.py"
CI = ROOT / ".github/workflows/ci.yml"
BUILD_GRADLE = ROOT / "frontend/android/app/build.gradle"
CHECKLIST = ROOT / "CHECKLIST_MIGRACAO_APK_SERVIDOR.md"
BASELINE_DOC = ROOT / "docs/APK_SIZE_BASELINE.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.exists(), f"Arquivo obrigatório ausente: {path}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    script = read(MEASURE_SCRIPT)
    ci = read(CI)
    gradle = read(BUILD_GRADLE)
    checklist = read(CHECKLIST)
    baseline_doc = read(BASELINE_DOC)

    require("find_artifacts" in script and "*.apk" not in script, "Script deve localizar artefatos APK/AAB de forma programática")
    require(".apk" in script and ".aab" in script, "Script deve medir APK e AAB")
    require("zip_breakdown" in script and "native_lib_mib_by_abi" in script,
            "Script deve decompor ZIP e bibliotecas nativas por ABI")
    require("--require-artifacts" in script,
            "Script deve permitir modo estrito quando a baseline real for obrigatória")
    require("APK_SIZE_BASELINE.md" in script,
            "Script deve gerar relatório Markdown versionável da baseline")

    require("measure_android_binary_size.py" in ci,
            "CI deve executar a medição de tamanho após builds Android")
    require("android-size-debug" in ci and "android-size-release" in ci,
            "CI deve publicar relatórios de tamanho para debug APK e release AAB")
    require("build/reports/android-size" in ci,
            "CI deve armazenar relatórios em build/reports")

    build_types_index = gradle.find("buildTypes")
    require(build_types_index >= 0, "build.gradle deve conter bloco buildTypes")
    build_types = gradle[build_types_index:]
    release_block = re.search(r"release\s*\{(?P<body>[\s\S]*?)\n\s*\}\n\s*debug\s*\{", build_types)
    require(release_block is not None, "build.gradle deve conter bloco buildTypes.release antes do debug")
    body = release_block.group("body") if release_block else ""
    require("minifyEnabled false" in body, "P10.1 não deve ativar minifyEnabled antes da baseline real")
    require("shrinkResources false" in body, "P10.1 não deve ativar shrinkResources antes da baseline real")
    require("splits" in gradle and "universalApk true" in gradle,
            "Configuração atual de splits/universal APK deve ser preservada para comparação de baseline")

    require("P10.1" in checklist and "APK_SIZE_BASELINE.md" in checklist,
            "Checklist mestre deve registrar o P10.1 e apontar para o relatório de baseline")
    require("P10.2" in checklist and "Não iniciado" in checklist,
            "Checklist deve manter P10.2 sem redução real antes de estabilidade e baseline")
    require("Nenhum APK ou AAB" in baseline_doc or "Artefato | Tipo | Tamanho" in baseline_doc,
            "Documento de baseline deve registrar artefatos medidos ou bloqueio operacional explícito")

    print("OK — P10 APK/AAB Size Governance validado textualmente")
    print("- Script mede APK/AAB, assets, configuração Android e bibliotecas nativas por ABI")
    print("- CI publica relatórios de tamanho para build Android")
    print("- Redução sensível permanece bloqueada até baseline real e validação Flutter/device")


if __name__ == "__main__":
    main()
