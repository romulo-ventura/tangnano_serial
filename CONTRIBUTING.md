# Manutenção e reuso

## Dependências

- GNU Make e Python 3 em macOS/Linux.
- OSS CAD Suite com Yosys, nextpnr-himbaechel, gowin_pack, Icarus Verilog e
  openFPGALoader. O caminho padrão é `~/.local/opt/oss-cad-suite`.
- Para ferramentas já disponíveis no PATH, use `make RUN= check` e
  `make RUN= LEDS=0`. Isso dispensa o wrapper local.

Os arquivos RTL usam Verilog sintetizável. Os testbenches usam SystemVerilog.
Não há dependência Python externa. A configuração de placa é Tang Nano 20K.

## Verificar uma alteração

```sh
make check LEDS=1
make check LEDS=0
make resources LEDS=1
make resources LEDS=0
```

`check` inclui testes de protocolo, UART, FIFO, LEDs, cliente Python e compilação
dos exemplos. Antes de publicar uma mudança de hardware, valide também na placa
quando disponível:

```sh
make program LEDS=0
make test LEDS=0 PORT=/dev/cu.usbserial-20250303171
```

A variável LEDS identifica a compilação e a pasta do relatório; `make test` não
programa nem identifica automaticamente qual bitstream está na placa.

## Organização

Mantenha o protocolo da aplicação separado de `uart_stream`. Mudanças de pinagem,
reset inicial e polaridade dos LEDs ficam no adaptador de placa. Documente
mudanças de interface em `docs/REUSO.md`, comportamento em `README.md` e versão
em `VERSION`/`CHANGELOG.md`. Atualize o Makefile e o manifesto Lushay se adicionar
arquivos RTL. Não versione arquivos gerados ou dados de testes locais.

## Pacote independente

`make package` cria um ZIP com fontes e documentação, com o wrapper
executado pelo Bash no Makefile. Extraia a pasta e use os mesmos comandos Make. O arquivo
`MANIFEST.sha256` permite conferir integridade com `shasum -a 256 -c MANIFEST.sha256`
no macOS ou `sha256sum -c MANIFEST.sha256` no Linux.
