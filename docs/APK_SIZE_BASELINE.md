# Baseline de tamanho Android — NexusHub

Autor: **Manus AI**
Gerado em UTC: **2026-05-08T04:10:02.249545+00:00**

Este relatório registra a medição P10 sem ativar redução prematura do APK/AAB. Quando artefatos de build existem, o script mede APKs/AABs diretamente; quando não existem, o relatório preserva o diagnóstico de bloqueio e os comandos obrigatórios para gerar a baseline real.

## Estado da baseline

| Métrica | Valor |
|---|---:|
| Artefatos APK/AAB encontrados | Não |
| Flutter no PATH deste ambiente | Não |
| Dart no PATH deste ambiente | Não |
| Assets versionados totais | 0.324 MiB |
| Imagens locais | 0.082 MiB |
| Fontes locais | 0.242 MiB |

## Artefatos medidos

Nenhum APK ou AAB foi encontrado em `frontend/build/app/outputs`. Neste sandbox, `flutter` e `dart` também não estão no PATH, então a baseline real deve ser gerada no CI ou em máquina de desenvolvimento com Flutter 3.29.3.

## Configuração Android de tamanho

| Alavanca | Estado |
|---|---|
| R8/minify em release | Inativo |
| Resource shrinking em release | Inativo |
| ABI splits para APK | Ativo |
| Universal APK também gerado | Ativo |
| Split de idiomas no AAB | Ativo |
| Split de densidade no AAB | Ativo |
| Split de ABI no AAB | Ativo |

## Dependências nativas com maior risco de peso

| Dependência | Observação operacional |
|---|---|
| `agora_rtc_engine` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `media_kit` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `media_kit_video` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `media_kit_libs_video` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `better_player_plus` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `flutter_inappwebview` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `google_mobile_ads` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `purchases_flutter` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `firebase_core` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `firebase_messaging` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `firebase_analytics` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `firebase_crashlytics` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `flutter_local_notifications` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `video_player` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `image_picker` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `image_cropper` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `photo_manager` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `record` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |
| `file_picker` | Medir impacto no artefato antes de remover, trocar ou tornar condicional. |

## Comandos obrigatórios para baseline real

```bash
cd frontend && flutter build apk --release --split-per-abi && cd ..
cd frontend && flutter build appbundle --release && cd ..
python3.11 scripts/measure_android_binary_size.py --output-md docs/APK_SIZE_BASELINE.md --output-json build/reports/android-size-baseline.json
```

A próxima etapa de redução só deve começar depois de existir uma linha de base com APK split por ABI e AAB release, comparável contra um relatório posterior. Até lá, `minifyEnabled` e `shrinkResources` permanecem desligados em release para evitar mudança comportamental não validada.
