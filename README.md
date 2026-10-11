**English** | **[Р СѓСЃСЃРєРёР№](README.ru.md)**

# Ternary Bonsai 2 27B (PQ2_0) вЂ” portable launcher

> **Intel Arc B580 only.**
>
> Every preset, every flag and every number below was measured on an
> **Intel Arc B580 (12 GB VRAM)** with the **Vulkan** build of the PrismML
> llama.cpp fork on Windows.
>
> The whole tuning is one rule: the 6540 MiB of model weights must fit in
> VRAM together with the KV cache, which leaves about 4 GiB for it. That is
> what decides whether you use `f16`, `q8_0` or `q4_0` at a given context.
> On a GPU with a different VRAM budget the cache sizes stop lining up, the
> KV cache spills into system RAM and decode collapses by 5-8x. The presets
> will run, but not at the speeds claimed here.
>
> Other GPUs: use a matching engine build (CUDA / Metal) from the
> [PrismML releases](https://github.com/PrismML-Eng/llama.cpp/releases) and
> expect to re-derive the context table yourself.

Runs [`OS-Software/Ternary-Bonsai-2-27B-Uncensored-Heretic-GGUF`](https://huggingface.co/OS-Software/Ternary-Bonsai-2-27B-Uncensored-Heretic-GGUF) вЂ” a 27B ternary reasoning model in 7.2 GB вЂ” through an OpenAI-compatible server, with tested context presets from 32k up to 262k tokens.

One file does everything: downloads the engine, downloads the model, starts the server.

---

## Why you cannot just open this in LM Studio

The model stores its weights with **ggml type 142 (`PQ2_0`)**. Every stock llama.cpp build rejects it:

```
gguf_init_from_reader: tensor 'output.weight' has invalid ggml type 142. should be in [0, 43)
```

Updating LM Studio, switching runtimes, renaming the file to `Q2_0` вЂ” none of it helps. `Q2_0` will load without an error and then produce garbage, because it has no Hadamard activation runtime.

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
| `4`вЂ“`9` | run a tested configuration |
| `S` | change port / threads / slots / custom context |
| `T` | test a running server |

Or skip the menu entirely:

```bat
bonsai.bat 65k-q8_0
```

Valid names: `32k-f16`, `32k-q8_0`, `65k-f16`, `65k-q8_0`, `96k-q8_0`, `131k-q4_0`, `262k-q4_0`.

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
| `96k-q8_0` | 98 304 | q8_0 | 24,6 tok/s | 405 tok/s | 10,06 GB | intermediate, 1,1 GB headroom |
| `131k-q4_0` | 131 072 | q4_0 | **27,1 tok/s** | 435 tok/s | 9,17 GB | fastest, 2 GB headroom |
| `262k-q4_0` | 262 144 | q4_0 + `-b 512 -ub 128` | 24,3 tok/s | 219 tok/s | 10,68 GB | max context, lower KV quality |

Decode speed is essentially flat across the whole range вЂ” 24 tok/s at 32k and at 262k. Only prompt eval drops at the largest context.

### The rule that decides everything

Model weights take **6540 MiB** and the compute buffer about **390 MiB**. The GPU gives about **11199 MiB** free. So the KV cache must fit in the remaining ~4269 MiB, or it spills to system RAM and decode collapses by 5-8x.

KV cache is 16 layers x 2 (K+V) x 4 heads x 256 dim. Measured sizes:

| KV type | bytes/token | 32 768 | 65 536 | 98 304 | 131 072 | 196 608 | 262 144 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| f16 | 69 632 | 2176 MiB | 4352 MiB | 6528 MiB | 8704 MiB | 13056 MiB | 17408 MiB |
| q8_0 | 34 816 | 1088 MiB | 2176 MiB | 3264 MiB | 4352 MiB | 6528 MiB | 8704 MiB |
| q4_0 | 17 408 | 544 MiB | 1088 MiB | 1632 MiB | 2176 MiB | 3264 MiB | 4352 MiB |

Add 6540 + 390 to any cell and compare with 11199. That is the whole design.

Two consequences worth knowing:

- **131 072 needs q4_0, not q8_0.** q8_0 there is 4352 MiB, which puts
  the total at 11 282 MiB - 83 MiB over. The obvious workaround is
  `-b 512 -ub 128`, and it does make it fit, but ub 128 costs prompt eval:
  it fell from 397 to 122 tok/s, and on a long prompt the rate kept sliding
  down to 48 tok/s until the Vulkan device was lost. q4_0 needs only
  2176 MiB, keeps the full ubatch, fits with 2 GB of headroom and ends up
  the fastest preset of all: 27,1 tok/s decode, 435 tok/s prompt eval.
- **`262k-q4_0` also passes `-b 512 -ub 128`** for the same reason: 6540 + 4352 + 150 = 11 042 MiB, just under the limit. f16 would need 17 GB and simply cannot run here.

### Do not use `-nkvo`

Moving the KV cache to system RAM with `--no-kv-offload` costs **8x decode** (22 в†’ 2,6 tok/s). Measured, not a guess.

### 65k f16 is the flaky one

It leaves only ~0,4 GB of VRAM headroom. When anything else takes VRAM, it spills and drops from 24 to **4 tok/s**. That is the most likely cause if the model suddenly feels like it outputs one token per second. Use `65k-q8_0`.

---

## What the numbers mean for you

| You want | Use |
| --- | --- |
| best quality, normal chat | `32k-f16` |
| everyday work | `65k-q8_0` |
| a bit more room than 65k | `96k-q8_0` |
| long documents | `131k-q4_0` |
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

- This is a **thinking** model. It reasons before answering, so it needs a generous token budget. With `max_tokens` of a few hundred it will spend everything on reasoning and return an empty answer. Use 8 000вЂ“16 000.
- Engine builds target **Windows + Vulkan** (Intel Arc). CUDA and Metal builds exist in the PrismML releases; change `ENGINE_TAG` / the zip name in `bonsai.bat` if you need one.
- The model is Apache 2.0. It is uncensored вЂ” it will answer what you ask.
