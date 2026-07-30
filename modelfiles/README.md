# Catálogo de Modelfiles

Inventário completo, com status e o motivo de cada arquivo existir.
Revisado em 2026-07-29 (auditoria completa das 20 versões — ver [../docs/DIAGNOSTICO-BUG-ANNA-CODE.md](../docs/DIAGNOSTICO-BUG-ANNA-CODE.md)).

## Estrutura

| Pasta | Significado |
|---|---|
| `active/` | O que roda em produção agora (v8) + a próxima versão (v9). **Só aqui pode haver Modelfile apontado por `ollama create` em produção.** |
| `tools/` | Assistentes utilitários vivos, mas fora do fluxo principal (dev, terminal). |
| `shana/` | Persona pessoal Shana (uso pessoal, fora de produção Blue3). |
| `archive/` | Superseded. Mantidos por histórico; **não usar** — os defeitos de cada um estão listados abaixo. |

## active/

| Arquivo | Base | Params-chave | Status |
|---|---|---|---|
| `ShvIA_v9.Modelfile` | gemma4:26b-a4b-it-qat | ver comentários no arquivo | **Próxima produção.** Motor genérico sem persona — a persona vem do app (ver [../docs/ARQUITETURA-CAMADAS.md](../docs/ARQUITETURA-CAMADAS.md)) |
| `ShvIA_v8.Modelfile` | gemma4:26b-a4b-it-qat | temp 0.85 · num_ctx **4096** | **Produção atual (`ShvIA:latest`), com bug conhecido.** Persona Anna completa + 5 linhas de "SERVIDOR TERMINAL" coladas no fim. O `num_ctx 4096` regrediu dos 16384 do v7 e causa o bug do modo Code (truncamento silencioso). Substituir pela v9. |

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
| `Shana-v2.1.Modelfile` | gemma4:12b | Idêntico ao v2.0 exceto o FROM — teste A/B de base. Stops de llama/ChatML mortos na família gemma (`<end_of_turn>` seria o real). Nenhum registro de qual base venceu o A/B. |

## archive/ (não usar — motivo do arquivamento)

| Arquivo | Base | Por que foi arquivado |
|---|---|---|
| `ShvIA_v7.Modelfile` | gemma4:26b | O melhor SYSTEM da linhagem Anna (seções organizadas) e num_ctx 16384. Superado pelo v8 (que, ironicamente, **regrediu** o num_ctx para 4096). Referência para a persona destilada em `personas/anna-blue3.md`. |
| `ShvIA_v6.Modelfile` | gemma4:26b | Primeira persona completa. Colagens sem integração ("O objetivo não é responder…" no meio do bloco de confiança), typos, bullet órfão. Reescrito no v7. |
| `ShvIA_v5.Modelfile` | gemma4:26b | Troca de base qwen3→gemma4 (removeu `/no_think` corretamente; comentário justificando temp 1.0 do QAT). SYSTEM ainda esqueleto com seções vazias. |
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
6. **Regressão silenciosa de parâmetro** — v7 (16384) → v8 (4096) sem registro: foi a causa-raiz do bug do modo Code.
