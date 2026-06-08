# Contexto do Projeto Piloto App / Crew 4U

Este documento registra o contexto inicial trazido para o Codex a partir da conversa com o Rafael.

## Objetivo

Evoluir o projeto Crew 4U como Projeto Piloto App, com caminho preparado para:

- Web
- Android
- iOS

## Arquitetura Decidida

O projeto deve continuar dividido em duas partes:

- `crewpay_backend`: backend em Python/FastAPI, responsável por processamento de escala, cálculos, leitura de planilhas, APIs e regras de negócio.
- `crewpay_web`: aplicativo Flutter, responsável pela interface do usuário e pela experiência em web, Android e iOS.

Python deve ser mantido como backend. Flutter deve ser mantido como app multiplataforma.

## Estado Inicial Encontrado

Pastas identificadas:

- `/Users/rafaelegidiosteffens/Projetos/crewpay_backend`
- `/Users/rafaelegidiosteffens/Projetos/crewpay_web`

Backend identificado:

- FastAPI
- Endpoint principal de upload de escala: `/upload-escala`
- Arquivos principais: `main.py`, `requirements.txt`, `aeroportos.csv`
- Pasta local: `/Users/rafaelegidiosteffens/Projetos/crewpay_backend`
- Arquivo principal: `main.py`
- Backend online: `https://crew4u-api.onrender.com`
- Endpoint online principal: `https://crew4u-api.onrender.com/upload-escala`

Frontend identificado:

- Flutter
- Dependências principais: `http`, `file_selector`
- Já possui pastas para `web`, `android`, `ios`, `macos`, `windows`, `linux`
- Pasta local: `/Users/rafaelegidiosteffens/Projetos/crewpay_web`
- Arquivo principal: `lib/main.dart`
- Site online: `https://crew4u.netlify.app/`

## Contexto Trazido do ChatGPT

O projeto foi iniciado e preparado inicialmente no ChatGPT. O contexto consolidado trazido para o Codex é:

- App Flutter Web com backend FastAPI.
- O app importa uma escala Excel de tripulante.
- O backend processa voos, reservas, sobreavisos e folgas.
- O app calcula salário/holerite.
- A escala deve aparecer em layout de app, com boa experiência mobile.
- Últimos arquivos tentados antes do Codex: `main.py v17` e `main.dart v17 corrigido`.
- O problema atual informado era: `main.dart` teve erros de compilação recentes; primeiro objetivo seria compilar sem erro.

## Regras Importantes

Estas regras devem ser preservadas em novas alterações:

1. `DO`, `OFF` e `FOLGA` precisam aparecer sempre como folga.
2. Folga não entra em KM, salário, diária, horas de voo nem jornada.
3. Linhas de legenda do Excel, como `LEGEND`, `ASB Airport stand by`, `HSB Home Stand by` e `DO Day off`, não podem virar eventos reais.
4. A escala deve abrir direto no dia atual ou próxima atividade, mas manter dias anteriores disponíveis para rolar para cima.
5. No mobile, o cabeçalho grande da Escala e o bloco de última escala importada devem sumir.
6. No mobile, devem existir dois botões pequenos acima do menu inferior:
   - upload da escala;
   - compartilhar/exportar PDF.
7. O botão de PDF deve usar ícone de compartilhar, tipo três bolinhas conectadas.
8. O PDF da escala precisa incluir as apresentações/duty reports.
9. O resumo de horas de voo, KM, reservas, sobreavisos e folgas deve ficar em menu suspenso no mobile, começando fechado.
10. A escala importada deve ficar salva no navegador/localStorage para reabrir depois no celular.
11. A aba Salário deve ser moderna, mas preservar a lógica do holerite: proventos, base de IR, descontos e salário líquido.

## Checklist de Validação Funcional

Depois de qualquer ajuste relevante, validar:

- `main.dart` compila sem erro.
- Upload da escala funciona.
- Folgas aparecem corretamente.
- Folgas não entram em cálculos indevidos.
- Linhas de legenda do Excel não viram eventos.
- PDF da escala inclui apresentações/duty reports.
- Botões pequenos aparecem no mobile acima do menu inferior.
- Cabeçalho grande da Escala some no mobile.
- Bloco de última escala importada some no mobile.
- Resumo mobile começa fechado.
- Escala importada fica salva ao reabrir.
- Aba Salário mantém proventos, base de IR, descontos e salário líquido.

## Comandos Locais

Backend:

```bash
cd ~/Projetos/crewpay_backend
source venv/bin/activate
uvicorn main:app --reload
```

Frontend:

```bash
cd ~/Projetos/crewpay_web
flutter run -d chrome
```

## Antes de Subir Online

- Conferir se `lib/main.dart` aponta para `https://crew4u-api.onrender.com/upload-escala`, ou se `CREW4U_API_BASE_URL` está configurado para `https://crew4u-api.onrender.com`.
- Rodar `flutter build web --release`.
- Subir `build/web` no Netlify.

## Primeira Preparação Multiplataforma Feita no Codex

Foram feitas alterações para reduzir dependência exclusiva da web:

- Removido uso direto de `dart:html` em `lib/main.dart`.
- Criada camada de plataforma em `lib/platform`.
- Separado armazenamento local por plataforma.
- Separada exportação/abertura de documentos por plataforma.
- URL do backend tornou-se configurável via `CREW4U_API_BASE_URL`.
- Teste inicial do app foi atualizado.
- Corrigido overflow de botão em tela mobile estreita.
- Arquivo antigo de backup foi excluído da análise automática.

Validações feitas:

- `flutter analyze`: passou sem problemas.
- `flutter test`: passou.
- `flutter build web --debug`: passou.

Validação Android:

- Ainda não foi possível gerar APK porque a máquina não tem Android SDK configurado.

## Direção de Produto

O produto deve seguir como uma ferramenta profissional para tripulantes, com foco em:

- importação de escala,
- análise de voos,
- cálculo de KM,
- cálculo de diárias,
- simulação de holerite,
- jornada,
- histórico,
- configurações de cargo e benefícios.

## Próximas Etapas Recomendadas

1. Criar um documento `REQUISITOS_PROJETO_PILOTO_APP.md`.
2. Criar um documento `ROADMAP_PROJETO_PILOTO_APP.md`.
3. Validar as regras de folga/legenda no backend.
4. Validar a experiência mobile no frontend.
5. Organizar o Flutter em pastas por responsabilidade.
6. Preparar ambiente Android SDK.
7. Preparar validação iOS via Xcode.
8. Melhorar a persistência local mobile.
9. Definir ambiente de backend: local, homologação e produção.
