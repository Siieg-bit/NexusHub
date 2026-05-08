#!/usr/bin/env python3.11
"""
Medição P10 — baseline de tamanho APK/AAB NexusHub.

Este script é deliberadamente somente leitura. Ele consolida os artefatos Android
já produzidos pelo build Flutter, mede assets versionados e registra o estado das
alavancas de redução sem ativar minificação, resource shrinking ou remoções de
payload prematuras.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import zipfile
from collections import defaultdict
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FRONTEND = ROOT / "frontend"

NATIVE_SIZE_RISK_DEPENDENCIES = [
    "agora_rtc_engine",
    "media_kit",
    "media_kit_video",
    "media_kit_libs_video",
    "better_player_plus",
    "flutter_inappwebview",
    "google_mobile_ads",
    "purchases_flutter",
    "firebase_core",
    "firebase_messaging",
    "firebase_analytics",
    "firebase_crashlytics",
    "flutter_local_notifications",
    "video_player",
    "image_picker",
    "image_cropper",
    "photo_manager",
    "record",
    "file_picker",
]


@dataclass
class FileSize:
    path: str
    bytes: int
    mib: float


@dataclass
class ArtifactMetric:
    path: str
    kind: str
    bytes: int
    mib: float
    entries: int | None
    compressed_mib_by_top_level: dict[str, float]
    uncompressed_mib_by_top_level: dict[str, float]
    native_lib_mib_by_abi: dict[str, float]


def bytes_to_mib(value: int) -> float:
    return round(value / (1024 * 1024), 3)


def iter_files(path: Path) -> Iterable[Path]:
    if not path.exists():
        return []
    return (p for p in path.rglob("*") if p.is_file())


def dir_size(path: Path) -> int:
    if not path.exists():
        return 0
    return sum(p.stat().st_size for p in iter_files(path))


def file_size(path: Path, root: Path) -> FileSize:
    size = path.stat().st_size
    return FileSize(path=str(path.relative_to(root)), bytes=size, mib=bytes_to_mib(size))


def find_artifacts(frontend_dir: Path) -> list[Path]:
    outputs = frontend_dir / "build" / "app" / "outputs"
    if not outputs.exists():
        return []
    artifacts = [p for p in outputs.rglob("*") if p.is_file() and p.suffix.lower() in {".apk", ".aab"}]
    return sorted(artifacts, key=lambda p: p.stat().st_size, reverse=True)


def zip_breakdown(path: Path) -> tuple[int, dict[str, float], dict[str, float], dict[str, float]]:
    compressed: dict[str, int] = defaultdict(int)
    uncompressed: dict[str, int] = defaultdict(int)
    native_by_abi: dict[str, int] = defaultdict(int)

    with zipfile.ZipFile(path) as zf:
        infos = zf.infolist()
        for info in infos:
            name = info.filename.strip("/")
            if not name:
                continue
            top_level = name.split("/", 1)[0]
            compressed[top_level] += info.compress_size
            uncompressed[top_level] += info.file_size

            parts = name.split("/")
            if name.endswith(".so"):
                abi = "unknown"
                if len(parts) >= 3 and parts[0] == "lib":
                    abi = parts[1]
                elif "lib" in parts:
                    index = parts.index("lib")
                    if index + 1 < len(parts):
                        abi = parts[index + 1]
                native_by_abi[abi] += info.file_size

    return (
        len(infos),
        {k: bytes_to_mib(v) for k, v in sorted(compressed.items(), key=lambda item: item[1], reverse=True)},
        {k: bytes_to_mib(v) for k, v in sorted(uncompressed.items(), key=lambda item: item[1], reverse=True)},
        {k: bytes_to_mib(v) for k, v in sorted(native_by_abi.items(), key=lambda item: item[1], reverse=True)},
    )


def measure_artifact(path: Path, root: Path) -> ArtifactMetric:
    entries = None
    compressed: dict[str, float] = {}
    uncompressed: dict[str, float] = {}
    native_by_abi: dict[str, float] = {}
    if zipfile.is_zipfile(path):
        entries, compressed, uncompressed, native_by_abi = zip_breakdown(path)

    size = path.stat().st_size
    return ArtifactMetric(
        path=str(path.relative_to(root)),
        kind=path.suffix.lower().lstrip("."),
        bytes=size,
        mib=bytes_to_mib(size),
        entries=entries,
        compressed_mib_by_top_level=compressed,
        uncompressed_mib_by_top_level=uncompressed,
        native_lib_mib_by_abi=native_by_abi,
    )


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def parse_android_config(frontend_dir: Path) -> dict[str, object]:
    build_gradle = read_text(frontend_dir / "android/app/build.gradle")
    return {
        "release_minify_enabled": bool(re.search(r"release\s*\{[\s\S]*?minifyEnabled\s+true", build_gradle)),
        "release_shrink_resources": bool(re.search(r"release\s*\{[\s\S]*?shrinkResources\s+true", build_gradle)),
        "abi_splits_enabled": "splits" in build_gradle and "abi" in build_gradle and re.search(r"enable\s+true", build_gradle) is not None,
        "universal_apk_enabled": "universalApk true" in build_gradle,
        "bundle_language_split_enabled": "language { enableSplit = true }" in build_gradle,
        "bundle_density_split_enabled": "density { enableSplit = true }" in build_gradle,
        "bundle_abi_split_enabled": "abi { enableSplit = true }" in build_gradle,
    }


def parse_dependency_risks(frontend_dir: Path) -> list[str]:
    pubspec = read_text(frontend_dir / "pubspec.yaml")
    risks = []
    for dep in NATIVE_SIZE_RISK_DEPENDENCIES:
        if re.search(rf"^\s*{re.escape(dep)}\s*:", pubspec, flags=re.MULTILINE):
            risks.append(dep)
    return risks


def collect_metrics(frontend_dir: Path) -> dict[str, object]:
    frontend_dir = frontend_dir.resolve()
    artifacts = [measure_artifact(p, ROOT) for p in find_artifacts(frontend_dir)]
    assets_dir = frontend_dir / "assets"
    images_dir = assets_dir / "images"
    fonts_dir = assets_dir / "fonts"

    largest_assets = sorted(iter_files(assets_dir), key=lambda p: p.stat().st_size, reverse=True)[:20] if assets_dir.exists() else []

    metrics: dict[str, object] = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "frontend_dir": str(frontend_dir.relative_to(ROOT)),
        "baseline_available": bool(artifacts),
        "flutter_available_in_path": bool(os.environ.get("FLUTTER_ROOT")) or any((Path(part) / "flutter").exists() for part in os.environ.get("PATH", "").split(os.pathsep)),
        "dart_available_in_path": any((Path(part) / "dart").exists() for part in os.environ.get("PATH", "").split(os.pathsep)),
        "artifacts": [asdict(metric) for metric in artifacts],
        "assets": {
            "total": asdict(FileSize(path="frontend/assets", bytes=dir_size(assets_dir), mib=bytes_to_mib(dir_size(assets_dir)))),
            "images": asdict(FileSize(path="frontend/assets/images", bytes=dir_size(images_dir), mib=bytes_to_mib(dir_size(images_dir)))),
            "fonts": asdict(FileSize(path="frontend/assets/fonts", bytes=dir_size(fonts_dir), mib=bytes_to_mib(dir_size(fonts_dir)))),
            "largest_files": [asdict(file_size(path, ROOT)) for path in largest_assets],
        },
        "android_config": parse_android_config(frontend_dir),
        "native_size_risk_dependencies": parse_dependency_risks(frontend_dir),
        "required_baseline_commands": [
            "cd frontend && flutter build apk --release --split-per-abi && cd ..",
            "cd frontend && flutter build appbundle --release && cd ..",
            "python3.11 scripts/measure_android_binary_size.py --output-md docs/APK_SIZE_BASELINE.md --output-json build/reports/android-size-baseline.json",
        ],
    }
    return metrics


def render_markdown(metrics: dict[str, object]) -> str:
    artifacts = metrics["artifacts"]  # type: ignore[index]
    assets = metrics["assets"]  # type: ignore[index]
    config = metrics["android_config"]  # type: ignore[index]
    risks = metrics["native_size_risk_dependencies"]  # type: ignore[index]

    lines: list[str] = []
    lines.append("# Baseline de tamanho Android — NexusHub")
    lines.append("")
    lines.append("Autor: **Manus AI**")
    lines.append(f"Gerado em UTC: **{metrics['generated_at_utc']}**")
    lines.append("")
    lines.append(
        "Este relatório registra a medição P10 sem ativar redução prematura do APK/AAB. "
        "Quando artefatos de build existem, o script mede APKs/AABs diretamente; quando não existem, "
        "o relatório preserva o diagnóstico de bloqueio e os comandos obrigatórios para gerar a baseline real."
    )
    lines.append("")
    lines.append("## Estado da baseline")
    lines.append("")
    lines.append("| Métrica | Valor |")
    lines.append("|---|---:|")
    lines.append(f"| Artefatos APK/AAB encontrados | {'Sim' if metrics['baseline_available'] else 'Não'} |")
    lines.append(f"| Flutter no PATH deste ambiente | {'Sim' if metrics['flutter_available_in_path'] else 'Não'} |")
    lines.append(f"| Dart no PATH deste ambiente | {'Sim' if metrics['dart_available_in_path'] else 'Não'} |")
    lines.append(f"| Assets versionados totais | {assets['total']['mib']} MiB |")  # type: ignore[index]
    lines.append(f"| Imagens locais | {assets['images']['mib']} MiB |")  # type: ignore[index]
    lines.append(f"| Fontes locais | {assets['fonts']['mib']} MiB |")  # type: ignore[index]
    lines.append("")

    lines.append("## Artefatos medidos")
    lines.append("")
    if artifacts:
        lines.append("| Artefato | Tipo | Tamanho | Entradas ZIP |")
        lines.append("|---|---|---:|---:|")
        for artifact in artifacts:  # type: ignore[assignment]
            lines.append(f"| `{artifact['path']}` | {artifact['kind']} | {artifact['mib']} MiB | {artifact.get('entries') or 0} |")
        lines.append("")
        for artifact in artifacts:  # type: ignore[assignment]
            if artifact.get("native_lib_mib_by_abi"):
                lines.append(f"### Bibliotecas nativas por ABI — `{artifact['path']}`")
                lines.append("")
                lines.append("| ABI | Tamanho descompactado |")
                lines.append("|---|---:|")
                for abi, mib in artifact["native_lib_mib_by_abi"].items():
                    lines.append(f"| {abi} | {mib} MiB |")
                lines.append("")
    else:
        lines.append(
            "Nenhum APK ou AAB foi encontrado em `frontend/build/app/outputs`. "
            "Neste sandbox, `flutter` e `dart` também não estão no PATH, então a baseline real deve ser gerada no CI ou em máquina de desenvolvimento com Flutter 3.29.3."
        )
        lines.append("")

    lines.append("## Configuração Android de tamanho")
    lines.append("")
    lines.append("| Alavanca | Estado |")
    lines.append("|---|---|")
    labels = {
        "release_minify_enabled": "R8/minify em release",
        "release_shrink_resources": "Resource shrinking em release",
        "abi_splits_enabled": "ABI splits para APK",
        "universal_apk_enabled": "Universal APK também gerado",
        "bundle_language_split_enabled": "Split de idiomas no AAB",
        "bundle_density_split_enabled": "Split de densidade no AAB",
        "bundle_abi_split_enabled": "Split de ABI no AAB",
    }
    for key, label in labels.items():
        lines.append(f"| {label} | {'Ativo' if config.get(key) else 'Inativo'} |")  # type: ignore[union-attr]
    lines.append("")

    lines.append("## Dependências nativas com maior risco de peso")
    lines.append("")
    if risks:
        lines.append("| Dependência | Observação operacional |")
        lines.append("|---|---|")
        for dep in risks:  # type: ignore[assignment]
            lines.append(f"| `{dep}` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |")
    else:
        lines.append("Nenhuma dependência de risco conhecida foi identificada no `pubspec.yaml`.")
    lines.append("")

    lines.append("## Comandos obrigatórios para baseline real")
    lines.append("")
    lines.append("```bash")
    for command in metrics["required_baseline_commands"]:  # type: ignore[index]
        lines.append(command)
    lines.append("```")
    lines.append("")
    lines.append(
        "A próxima etapa de redução só deve começar depois de existir uma linha de base com APK split por ABI e AAB release, "
        "comparável contra um relatório posterior. Até lá, `minifyEnabled` e `shrinkResources` permanecem desligados em release para evitar mudança comportamental não validada."
    )
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Mede baseline de tamanho APK/AAB do NexusHub.")
    parser.add_argument("--frontend-dir", type=Path, default=DEFAULT_FRONTEND)
    parser.add_argument("--output-json", type=Path, default=ROOT / "build/reports/android-size-baseline.json")
    parser.add_argument("--output-md", type=Path, default=ROOT / "docs/APK_SIZE_BASELINE.md")
    parser.add_argument("--require-artifacts", action="store_true", help="Falha se nenhum APK/AAB existir.")
    args = parser.parse_args()

    metrics = collect_metrics(args.frontend_dir)
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_md.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(metrics, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    args.output_md.write_text(render_markdown(metrics), encoding="utf-8")

    print(f"Relatório JSON: {args.output_json}")
    print(f"Relatório Markdown: {args.output_md}")
    if metrics["baseline_available"]:
        for artifact in metrics["artifacts"]:  # type: ignore[index]
            print(f"- {artifact['path']}: {artifact['mib']} MiB")
    else:
        print("AVISO: nenhum APK/AAB encontrado; baseline real depende de build Flutter no CI/dev.")
        if args.require_artifacts:
            sys.exit(2)


if __name__ == "__main__":
    main()
