# Catálogo de Modelfiles

Inventário completo, com status e o motivo de cada arquivo existir.
Original lineage audit: July 29, 2026. Inventory checked November 5, 2026:
24 definitions. The historical defect analysis below is retained; deployment
status comes from dated measurements, not directory names. See the
[operating guide](../docs/operations.md).

## Estrutura

| Pasta | Significado |
|---|---|
| `active/` | Current build definitions: v9 is the default candidate; v8 is retained. Directory membership does not prove a deployed tag. |
| `tools/` | Assistentes utilitários vivos, mas fora do fluxo principal (dev, terminal). |
| `shana/` | Persona pessoal Shana (uso pessoal, fora de produção Blue3). |
| `archive/` | Superseded. Mantidos por histórico; **não usar** — os defeitos de cada um estão listados abaixo. |

## active/

| Arquivo | Base | Params-chave | Status |
|---|---|---|---|
| `ShvIA_v9.Modelfile` | gemma4:26b-a4b-it-qat | ver comentários no arquivo | **Default build input.** Neutral engine; application supplies persona. Matched `ShvIA:latest` in the [September 23 observation](../docs/rollout-observation-20260923.md); not remeasured today. |
| `ShvIA_v8.Modelfile` | gemma4:26b-a4b-it-qat | temp 0.85 · num_ctx **4096** | **Retained legacy definition.** Embedded Anna persona and terminal instructions; context regressed from v7. It is not evidence of what `ShvIA:latest` serves today. |

## tools/

| Arquivo | Base | Params-chave | Notas |
|---|---|---|---|
| `Dev.Modelfile` | qwen2.5-coder:14b | temp 0.2 · num_ctx 16384 · repeat_penalty 1.05 | Assistente de dev da stack SHVIA (Laravel 13/PHP 8.3/MariaDB). O melhor candidato a modelo de código dedicado. **Pendência:** placeholder `[CONFIRME — Tailwind+Alpine vs Cork5/Bootstrap5]` embarcado no SYSTEM vai literalmente ao modelo — resolver. |
| `SShvTerm.Modelfile` | qwen3:14b | temp 0.3 · num_ctx 8192 | Assistente de terminal Linux (Debian Trixie). **Defeito:** SYSTEM contém `Reasoning: low` (sintaxe do gpt-oss, texto morto no qwen3). Duplicata funcional do antigo `ShvIA_qwen` (arquivado). |
| `ShvIA_qwen_2.Modelfile` | qwen3:14b | temp 0.3 · num_ctx **32768** | Versão limpa do assistente de terminal (removeu `Reasoning: low`, subiu contexto). O melhor da linhagem terminal. |
| `ShvIA_gpt.Modelfile` | gpt-oss:20b | temp 1.0 · num_ctx **32768** | Porte do assistente de terminal para gpt-oss. Porte de diretivas feito corretamente (`Reasoning: low` aqui é sintaxe nativa). Atenção: `num_predict 1024` é compartilhado com os tokens de raciocínio. |

## shana/

| Arquivo | Base | Notas |
|---|---|---|
| `Shana-v2.0.Modelfile` | qwen3:14b | Persona pessoal sarcástica, bem estruturada, com few-shots. **Defeitos:** falta `/no_think` (qwen3 gasta o `num_predict 512` em raciocínio) e os stops `<\|end_of_text\|>`/`<\|eot_id\|>` são tokens de llama (mortos aqui). |
| `Shana-v2.1.Modelfile` | gemma4:12b | Idêntico ao v2.0 exceto o FROM — teste A/B de base. Stops de llama/ChatML mortos na família gemma (`<end_of_turn>` seria o real). A/B **resolvido no v2.2**: vence gemma4 (o qwen3:14b não tem visão). Superado. |
| `Shana-v2.2.Modelfile` | **gemma4:12b-it-qat** | temp 1.0/64/0.95 · `repeat_penalty` 1.0 · num_ctx **32768** · `num_predict` -1 | **Atual.** Persona com **visão** (interpreta prints). The `26b-a4b-it-qat` base was ruled out because it **does not fit a 16 GB V100 with vision** (the tracked predecessors, v2.1 and the first v2.2 commit `8c3b8bc`, used `gemma4:12b`): 14 GB de pesos + 1,2 GB de projector = 16 GB numa placa de 16 GB (a medição de 15,2 GB do v9 é só-texto — o projector só carrega quando chega imagem). Stops mortos removidos, calibração Gemma 4 oficial aplicada. ⚠ Ao contrário do ShvIA, o SYSTEM **é** o produto: cliente que enviar `role:system` apaga a persona. |

## archive/ (não usar — motivo do arquivamento)

| Arquivo | Base | Por que foi arquivado |
|---|---|---|
| `ShvIA_v7.Modelfile` | gemma4:26b-a4b-it-qat | O melhor SYSTEM da linhagem Anna (seções organizadas) e num_ctx 16384. Superado pelo v8 (que, ironicamente, **regrediu** o num_ctx para 4096). Referência para a persona destilada em `personas/anna-blue3.md`. |
| `ShvIA_v6.Modelfile` | gemma4:26b-a4b-it-qat | Primeira persona completa. Colagens sem integração ("O objetivo não é responder…" no meio do bloco de confiança), typos, bullet órfão. Reescrito no v7. |
| `ShvIA_v5.Modelfile` | gemma4:26b-a4b-it-qat | Troca de base qwen3→gemma4 (removeu `/no_think` corretamente; comentário justificando temp 1.0 do QAT). SYSTEM ainda esqueleto com seções vazias. |
| `ShvIA_v4.Modelfile` | qwen3:14b | Diff de 1 linha sobre o v3 (renomeia persona para "Anna"). Seções `Como responder:` e `Segurança:` vazias. |
| `ShvIA_v3.Modelfile` | qwen3:14b | Primeiro da linhagem ativa. SYSTEM incompleto (seções vazias), `/no_think` embutido, vocabulário de assistente Linux numa persona de ISP. |
| `ShvIA_q3.Modelfile` | qwen3:14b | O "elo perdido": momento em que a persona Blue3 foi colada por cima do assistente técnico, apagando as seções técnicas — o padrão que culmina no bug do v8. |
| `ShvIA_qwen.Modelfile` | qwen3:14b | Duplicata byte-a-byte do SShvTerm com `Reasoning: low` alheio. Superado por `tools/ShvIA_qwen_2`. |
| `Anna-v1.0.Modelfile` | qwen3:14b | SYSTEM de 11,4 KB com documento LGPD inteiro colado (meta-texto incluso), placeholder de DPO não resolvido e **proibição explícita de código** — a semente do comportamento anti-código. |
| `Anna-v2.0.Modelfile` | qwen3:14b | Reescrita normativa closed-book. Contradição de fronteira (pode explicar Linux, não pode usar conhecimento geral). Estilo staccato inflado. |
| `Anna-v2.1.Modelfile` | qwen2.5:14b | Compressão radical (5,8→1,5 KB) + downgrade de base sem registro do motivo. min_p+top_p+top_k empilhados. |
| `Anna-v2.2.Modelfile` | gemma3:12b | Experimento extremo: closed-book absoluto, greedy triplo (temp 0 + top_p 0.5 + top_k 1), `num_predict 256`, "Não tente ajudar." — máquina de recusa, inservível. |
| `Anna-v2.3.Modelfile` | qwen3:14b | Destilação mínima do v2.2. qwen3 sem `/no_think` + `num_predict 256` = raciocínio consome o budget antes da resposta. |
| `Anna-v2.4.Modelfile` | gemma4:12b | Par A/B do v2.3 (só muda o FROM). Resultado do teste nunca registrado. |
| `bk.Anna.Modelfile` | qwen3:14b | Ramo divergente: Anna **interna** (colaboradores, não clientes). Primeiro a prever RAG. Placeholders `[PREENCHA…]` visíveis ao modelo; mantém proibição de código. Nome "bk" esconde que é um ramo funcional, não backup. |
| `Shana-v1.0.Modelfile` | llama3.1:8b | TEMPLATE custom que quebra multi-turno; stops nos próprios bordões da persona (trunca quando a persona funciona); repeat_penalty 1.35 altíssimo. Reescrito no v2.0. |

## Lições recorrentes da linhagem (não repetir)

1. **Diretiva de uma família colada em outra** — `/no_think` (qwen3), `Reasoning: low` (gpt-oss) e stops `<|eot_id|>` (llama) migraram por copy-paste entre bases incompatíveis, virando texto morto ou quebrando o modelo. Ao trocar o FROM, revise TODAS as diretivas e stops.
2. **Parâmetros herdados sem recalibrar** — sampling tunado para qwen reutilizado em gemma e vice-versa. Cada família tem calibração própria (Gemma 4 QAT: temp 1.0/top_k 64/top_p 0.95; Qwen3-Coder: temp 0.7/top_p 0.8/top_k 20).
3. **Testes A/B sem registro do resultado** — v2.3/v2.4 e Shana v2.0/v2.1 são pares A/B cujo vencedor nunca foi anotado. Registrar no CHANGELOG.
4. **Placeholders `[PREENCHA]` indo para produção** — o modelo recebe o placeholder como texto e pode citá-lo ao usuário (Anna-v1.0, bk.Anna, Dev).
5. **Versão nova por diff de 1 linha** — v3→v4 gastou uma versão num rename. Usar o CHANGELOG para mudanças pequenas.
   🔴 **E por diff de ZERO linhas, medido em 22/09/2026:** `Shana-v2.3.Modelfile` era cópia byte-a-byte da v2.2. Tinha **um** commit em toda a história (`1ebc20e "Nova versao"`) e já nasceu idêntica — nada próprio foi sobrescrito. Quem promovesse "a v2.3" subiria a v2.2 acreditando estar subindo mudança. Apagada; agora `scripts/prova-modelfile-nao-e-duplicata.sh` recusa duplicata que não esteja declarada em `modelfiles/duplicatas-declaradas.txt`.
6. **Regressão silenciosa de parâmetro** — v7 (16384) → v8 (4096) sem registro: foi a causa-raiz do bug do modo Code.
   The SHVIA-WEB mirror's v8 copy declares 16384 instead; see [below](#mirror-in-shvia-web).

## Mirror in SHVIA-WEB

SHVIA-WEB keeps a separate copy of 16 definitions under
`docs/SERVIDOR-GPU/MODELFILES/` (`active/` and `historico/`), which its own README
dates to a July 11, 2026 snapshot of the GPU server. It is not synchronized with this
repository. Compared byte for byte on November 5, 2026 (SHVIA-WEB `b24e45a5`):

| SHVIA-WEB file | Here | Result |
|---|---|---|
| `active/ShvIA_v3` … `active/ShvIA_v7` | `archive/ShvIA_v3` … `archive/ShvIA_v7` | identical |
| `active/ShvIA_v8` | `active/ShvIA_v8` | **differs in one line**: `num_ctx 16384` there, `num_ctx 4096` here |
| `historico/Anna-v1.0` … `Anna-v2.4`, `bk.Anna`, `Shana-v1.0` | `archive/` | identical |
| `historico/Dev` | `tools/Dev` | identical |
| `historico/Shana-v2.0` | `shana/Shana-v2.0` | identical |

Absent there: `ShvIA_v9`, `Shana-v2.1`, `Shana-v2.2`, `ShvIA_q3`, `ShvIA_qwen`,
`SShvTerm`, `ShvIA_qwen_2` and `ShvIA_gpt`. The mirror's README still names
`ShvIA:G4v8` as the production model, and SHVIA-WEB's GPU rebuild runbook recreates
`ShvIA` from its own v8 copy. Neither repository records which `num_ctx` the server's
v8 tag carried on July 11; the July 29 diagnosis describes the deployed v8 as `num_ctx 4096`.
Use this directory, not the mirror, as the source for builds.
