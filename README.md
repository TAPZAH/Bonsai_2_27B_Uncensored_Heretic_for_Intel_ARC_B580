# Ternary Bonsai 2 27B (PQ2_0) — portable launcher

Runs [`OS-Software/Ternary-Bonsai-2-27B-Uncensored-Heretic-GGUF`](https://huggingface.co/OS-Software/Ternary-Bonsai-2-27B-Uncensored-Heretic-GGUF) — a 27B ternary reasoning model in 7.2 GB — through an OpenAI-compatible server, with tested context presets from 32k up to 262k tokens.

One file does everything: downloads the engine, downloads the model, starts the server.

---

## Why you cannot just open this in LM Studio

The model stores its weights with **ggml type 142 (`PQ2_0`)**. Every stock llama.cpp build rejects it:

```
gguf_init_from_reader: tensor 'output.weight' has invalid ggml type 142. should be in [0, 43)
```

Updating LM Studio, switching runtimes, renaming the file to `Q2_0` — none of it helps. `Q2_0` will load without an error and then produce garbage, because it has no Hadamard activation runtime.

Only the **[PrismML llama.cpp fork](https://github.com/PrismML-Eng/llama.cpp)** has the ternary hybrid-attention kernels. This launcher fetches that fork for you.

---

## Quick start

```bat
bonsai.bat
```

Then choose:

| Key | Action |
| --- | --- |
| `1` | download engine (PrismML llama.cpp fork) |
| `2` | download model (7.2 GB, resumable) |
| `3` | download vision tower (0.93 GB, only for image input) |
| `4`–`9` | run a tested configuration |
| `S` | change port / threads / slots / custom context |
| `T` | test a running server |

Or skip the menu entirely:

```bat
bonsai.bat 65k-q8_0
```

Valid names: `32k-f16`, `32k-q8_0`, `65k-f16`, `65k-q8_0`, `131k-q8_0`, `262k-q4_0`.

The API is OpenAI compatible:

```
Base URL : http://127.0.0.1:18098/v1
API key  : anything
Model    : anything (e.g. "local")
```

---

## Tested configurations

Measured on a Ryzen 5 5500 (6C/12T) + Intel Arc B580 (12 GB VRAM), 32 GB RAM, `-ngl 99 -fa on -t 12 -np 1`, prompt 2152 tokens.

| Preset | Context | KV cache | decode | prompt eval | VRAM | Notes |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| `32k-f16` | 32 768 | f16 | **24,9 tok/s** | 415 tok/s | 8,81 GB | best quality |
| `32k-q8_0` | 32 768 | q8_0 | 24,6 tok/s | 414 tok/s | 7,87 GB | |
| `65k-f16` | 65 536 | f16 | 24,4 tok/s | 415 tok/s | 10,84 GB | tight VRAM, see below |
| `65k-q8_0` | 65 536 | q8_0 | 24,3 tok/s | 388 tok/s | 8,96 GB | **recommended** |
| `131k-q8_0` | 131 072 | q8_0 | 23,8 tok/s | 397 tok/s | 11,16 GB | |
| `262k-q4_0` | 262 144 | q4_0 | 24,3 tok/s | 219 tok/s | 10,68 GB | max context, lower KV quality |

Decode speed is essentially flat across the whole range — 24 tok/s at 32k and at 262k. Only prompt eval drops at the largest context.

### The rule that decides everything

Model weights take **6540 MiB**. The GPU gives about **11199 MiB** free. So the KV cache must fit in the remaining ~4 GiB, or it spills to system RAM and decode collapses by 5-8x.

| KV type | 32 768 | 65 536 | 131 072 | 196 608 | 262 144 |
| --- | ---: | ---: | ---: | ---: | ---: |
| f16 | 2048 MiB | 4096 MiB | 8192 MiB | 12288 MiB | 16384 MiB |
| q8_0 | 1024 MiB | 2048 MiB | 4096 MiB | 6144 MiB | 8704 MiB |
| q4_0 | 512 MiB | 1024 MiB | 2048 MiB | 3264 MiB | 4352 MiB |

`262k-q4_0` also passes `-b 512 -ub 128`, which shrinks the compute buffer from ~390 MiB to ~150 MiB and is what makes the whole thing fit.

### Do not use `-nkvo`

Moving the KV cache to system RAM with `--no-kv-offload` costs **8x decode** (22 → 2,6 tok/s). Measured, not a guess.

### 65k f16 is the flaky one

It leaves only ~0,4 GB of VRAM headroom. When anything else takes VRAM, it spills and drops from 24 to **4 tok/s**. That is the most likely cause if the model suddenly feels like it outputs one token per second. Use `65k-q8_0`.

---

## What the numbers mean for you

| You want | Use |
| --- | --- |
| best quality, normal chat | `32k-f16` |
| everyday work | `65k-q8_0` |
| long documents | `131k-q8_0` |
| maximum context | `262k-q4_0` |

Quality trade-off: `q8_0` KV cache is a mild loss, `q4_0` is a real one. `262k-q4_0` only exists because f16 would need 16 GB of VRAM.

---

## Verification

`verify-context.ps1` runs a needle-in-a-haystack test: it hides a unique code at ~50% depth inside a long prompt and asks for it at the end. Structural `n_ctx` from `/props` only proves the window was allocated, not that the model can use it.

```powershell
powershell -ExecutionPolicy Bypass -File verify-context.ps1 -TargetTokens 60000
```

---

## Notes

- This is a **thinking** model. It reasons before answering, so it needs a generous token budget. With `max_tokens` of a few hundred it will spend everything on reasoning and return an empty answer. Use 8 000–16 000.
- Engine builds target **Windows + Vulkan** (Intel Arc). CUDA and Metal builds exist in the PrismML releases; change `ENGINE_TAG` / the zip name in `bonsai.bat` if you need one.
- The model is Apache 2.0. It is uncensored — it will answer what you ask.
