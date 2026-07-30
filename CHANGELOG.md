# CHANGELOG — Modelfiles SHVIA

Histórico reconstruído na auditoria de 2026-07-29 (o repositório git começa em 2026-07-30; as versões anteriores foram datadas pela evolução dos arquivos). Daqui em diante: **toda mudança de Modelfile ganha entrada aqui** — em especial trocas de FROM, mudanças de parâmetro e resultados de testes A/B (três coisas que a linhagem perdeu por não registrar).

## [v9] — 2026-07-29 — MOTOR GENÉRICO (arquitetura em camadas)

**Mudança estrutural:** o Modelfile deixa de carregar a persona. Vira motor neutro; a persona Anna (Chat) e o protocolo de agente (Code) passam a ser injetados pelo app como `role:system` por requisição, e os fatos institucionais/de cliente migram para RAG.

- `num_ctx`: 4096 → valor dimensionado para o modo Code (ver comentários no arquivo e validação de VRAM em docs/ARQUITETURA-CAMADAS.md).
- `repeat_penalty`: 1.10 → **1.0** (o default 1.1 do Ollama penaliza tokens estruturais de código).
- `temperature/top_k/top_p`: calibração oficial do Gemma 4 QAT (1.0/64/0.95) — a família se comporta mal em temperatura baixa; o app pode reduzir por modo via `options` (sem reload).
- Motivação completa: docs/DIAGNOSTICO-BUG-ANNA-CODE.md.
- **Requer mudanças no SHVIA-WEB** (dobra `foldSystemIntoFirstUser`, `options` por modo, `truncate:false`) — rollout sequenciado em docs/ARQUITETURA-CAMADAS.md.

## [v8] — produção atual (`ShvIA:latest`) — ⚠ bug conhecido

- SYSTEM do v7 + seção "SERVIDOR TERMINAL" (5 linhas coladas no fim, primeira tentativa de modo agêntico).
- **REGRESSÃO sem registro: `num_ctx` 16384 → 4096** (provável tentativa de caber na VRAM do V100 16GB). É a causa-raiz nº 1 do bug do modo Code: requisições de 15–31k tokens truncadas silenciosamente, sobra só a persona de suporte.
- `num_predict`: 2048 → -1 (ilimitado).

## [v7] — melhor SYSTEM da linhagem

- Reescrita completa e organizada da persona Anna em seções (IDENTIDADE / SOBRE A BLUE3 / OBJETIVOS / COMPORTAMENTO / PRECISÃO / SUPORTE TÉCNICO / RECOMENDAÇÕES / ESTILO / TRANSPARÊNCIA / REGRA MAIS IMPORTANTE).
- `num_ctx`: 8192 → 16384 (ponto alto da linhagem).
- `temperature`: 1.0 → 0.85 — e o comentário do v5 justificando a calibração QAT foi perdido nessa reescrita.
- Base da persona destilada em `personas/anna-blue3.md`.

## [v6] — primeira persona completa

- Primeiro SYSTEM "de verdade": prioridades de atendimento, protocolo de confiança ALTA/MÉDIA/BAIXA, listas de nunca-inventar, regras de estilo.
- Defeitos de colagem: regra-mestra enfiada no meio do bloco de confiança MÉDIA, typo "atendimentno", bullet órfão. Corrigidos na reescrita do v7.

## [v5] — troca de base: qwen3 → gemma4

- FROM `qwen3:14b` → `gemma4:26b-a4b-it-qat`.
- Porte correto: removeu o `/no_think` (hack específico do qwen3).
- `temperature`: 0.3 → 1.0 com comentário: *"recomendado pelo Google pra Gemma 4 — o QAT é calibrado pra temp 1.0"* (comentário depois perdido no v7).
- SYSTEM continuou esqueleto (seções vazias desde o v3).

## [v4] — rename

- Diff de 1 linha sobre o v3: persona "ShvIA" → "Anna". (Lição: mudança desse tamanho não justifica versão; registrar aqui.)

## [v3] — origem da linhagem ativa

- FROM `qwen3:14b`, `/no_think` embutido, temp 0.3, num_ctx 8192.
- SYSTEM esqueleto: seções "Como responder:" e "Segurança:" **vazias** (permaneceram vazias até o v6).
- Persona Blue3 + regra dura de precisão com vocabulário de assistente Linux (man/--help) — resíduo do prompt de terminal de onde nasceu (ver `archive/ShvIA_q3.Modelfile`, o "elo perdido").

---

## Linhagens paralelas (resumo — detalhes em modelfiles/README.md)

- **Anna v1.0→v2.4 + bk.Anna** (arquivada): linhagem de atendimento puro-closed-book. Do documento LGPD de 11 KB colado no SYSTEM (v1.0) até a máquina de recusa greedy (v2.2). Proibia código explicitamente — a semente cultural do bug. Pares A/B v2.3/v2.4 sem registro do vencedor.
- **Shana v1.0→v2.1**: persona pessoal. v1.0 tinha TEMPLATE que quebrava multi-turno e stops nos próprios bordões; v2.0 corrigiu; v2.1 é A/B de base (qwen3 vs gemma4:12b) sem registro do vencedor.
- **Terminal (SShvTerm / ShvIA_qwen / ShvIA_qwen_2 / ShvIA_gpt)**: assistentes de shell. `ShvIA_qwen_2` (num_ctx 32768, diretivas limpas) é o melhor; `ShvIA_qwen` era duplicata e foi arquivado. `ShvIA_gpt` demonstrou porte correto de diretivas entre famílias.
- **Dev.Modelfile**: assistente da stack SHVIA sobre qwen2.5-coder — melhor candidato a modelo de código dedicado se o modo Code ganhar modelo próprio (papel `task`/`code` no model_roles do app).
