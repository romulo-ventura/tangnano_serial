# tangnano_serial — UART reutilizável para Tang Nano 20K

A reusable code for Tang Nano 20K serial communication. The intent is to reuse for other experiments like embbeded AI.

Biblioteca UART em Verilog, exemplo de echo identificado e cliente Python para
reutilizar a comunicação nos próximos projetos. O exemplo continua em 115200
baud, 8N1, com clock de 27 MHz e respostas `TANG20K ECHO: ...`.

Comece pelo [guia de integração](docs/REUSO.md) para usar os módulos em outro
sistema ou alterar identificação, tamanho das mensagens e velocidade.

## Organização

| Arquivo | Responsabilidade |
|---|---|
| `rtl/uart.v` | Receptor e transmissor UART 8N1 |
| `rtl/byte_fifo.v` | Fila de bytes parametrizável |
| `rtl/uart_stream.v` | Interface serial reutilizável com `valid/ready`, reset e diagnósticos |
| `rtl/echo_service.v` | Exemplo de protocolo de echo, independente da placa |
| `rtl/serial_status_leds.v` | Seleção opcional entre diagnóstico e LEDs da aplicação |
| `rtl/top.v` | Integração da Tang Nano: reset inicial, módulos e LEDs |
| `tangnano20k.cst` | Pinagem e níveis elétricos da Tang Nano 20K |
| `examples/byte_echo.v` | Exemplo mínimo de integração da UART com retorno de bytes crus |
| `host/serial_client.py` | Cliente serial Python reutilizável para macOS/Linux |
| `test_serial.py` | Validação do protocolo do exemplo no hardware |
| `sim/` | Testes de integração, UART, FIFO e protocolo |
| `scripts/fpga-run` | Ativação local da OSS CAD Suite |

## Compilar, simular e testar

Abra esta pasta (`serial-echo`) no VS Code. `Cmd+Shift+B` compila o projeto;
**Terminal → Run Task** oferece simulação, programação SRAM e teste serial.
A configuração `serial-echo.lushay.json` também lista os seis arquivos RTL
para a extensão Lushay Code.

No terminal desta pasta:

```sh
make           # Compilar com LEDs para build/leds1/echo.fs
make LEDS=0    # Compilar sem diagnóstico para build/leds0/echo.fs
make check     # Simulações, testes Python e compilação do exemplo mínimo
make program   # Carregar o echo identificado na SRAM da Tang Nano
make test      # Validar 106 trocas na UART real
```

Também é possível usar `make sim` e `make test-host` separadamente.
As ferramentas FPGA vêm da OSS CAD Suite em `~/.local/opt/oss-cad-suite`.
A pasta não depende do projeto blink. O cliente/teste Python usa apenas a
biblioteca padrão, sem pyserial.

A programação substitui o circuito em execução na SRAM, sem gravar a Flash.
Desligar e ligar a placa restaura o projeto persistente anterior. O arquivo
validado pelo Makefile é **`build/leds1/echo.fs`** (padrão) ou **`build/leds0/echo.fs`** (`LEDS=0`). Arquivos `.fs`/`.json` na raiz
podem pertencer a compilações anteriores ou à extensão Lushay.

O Makefile gera bitstream sem compressão: o openFPGALoader v1.2.0 instalado
rejeitou a versão comprimida deste projeto com `checksum data is truncated`.
O bitstream sem compressão foi carregado e testado com sucesso.

## Testar manualmente

Porta confirmada: `/dev/cu.usbserial-20250303171` (interface USB 1 do SIPEED
USB Debugger, serial `2025030317`). Ajuste `PORT` se o nome mudar:

```sh
make test PORT=/dev/cu.usbserial-20250303171
python3 -m host.serial_client --port /dev/cu.usbserial-20250303171 --message teste
```

Em um terminal serial, configure 115200, 8N1, sem controle de fluxo e sem eco
local. Use LF ou CRLF como final de linha. Feche a conexão do terminal antes
de executar o teste automático.

```text
Computador → teste-123\n
FPGA       → TANG20K ECHO: teste-123\r\n
```

O limite padrão é de 120 bytes por mensagem. CR é ignorado; LF encerra a
mensagem. Uma linha vazia também recebe resposta. Acima do limite, a resposta
é `TANG20K ERROR: TOO LONG\r\n`, e a mensagem seguinte pode ser processada.
Não há banner espontâneo. Aguarde a resposta completa antes de enviar a próxima
solicitação. A fila RX de 16 bytes absorve pequenas pausas, mas não substitui
controle de fluxo nem garante recepção ilimitada durante as respostas.

## LEDs opcionais

A flag de síntese `ENABLE_DIAGNOSTIC_LEDS` seleciona quem controla os LEDs.
No Makefile, use `LEDS=1` (padrão, diagnóstico) ou `LEDS=0` (aplicação principal):

```sh
make LEDS=0
make check LEDS=0
make program LEDS=0
make resources LEDS=0
```

Com `LEDS=0`, `serial_status_leds` encaminha `app_led_on[5:0]` diretamente,
e toda a lógica de diagnóstico dos LEDs é removida na síntese. No exemplo de
echo, esse sinal vale zero e os seis LEDs ficam apagados. Na integração,
conecte os sinais de sua aplicação; veja [o exemplo](examples/application_leds.v)
e o [guia](docs/REUSO.md#controle-opcional-dos-leds).

`app_led_on` usa **1 = aceso**; a inversão para os pinos ativos em zero ocorre
somente no adaptador da placa. Os seis pinos continuam presentes no exemplo
para que a aplicação possa utilizá-los. Não conecte duas saídas aos mesmos LEDs.

A seleção é feita na compilação, não por comando serial. Os dois bitstreams são
salvos em pastas diferentes para evitar carregar uma configuração antiga.
A extensão Lushay usa o valor padrão de `ENABLE_DIAGNOSTIC_LEDS` em `top.v`;
a variável `LEDS=0` pertence ao Makefile. No VS Code existem tarefas específicas
para compilar e programar sem diagnóstico.

Quando o diagnóstico está habilitado:


| LED | Função |
|---|---|
| 0 | Heartbeat: ciclo de aproximadamente 1,24 s a 27 MHz |
| 1 | Alterna a cada mensagem encerrada por LF |
| 2 | Resposta em andamento, incluindo o último stop bit |
| 3 | Mensagem excedeu o limite; limpa ao concluir a resposta de erro |
| 4 | Erro de enquadramento UART detectado; permanece aceso até reset/reconfiguração |
| 5 | Fila RX cheia com descarte de byte; permanece aceso até reset/reconfiguração |

Os LEDs 4 e 5 eram reservados na versão inicial e agora mostram diagnósticos.
Os LEDs são ativos em nível baixo. TX está no pino 69, RX no 70, clock no 4,
e LEDs nos pinos 15–20. Referência: [Apicula, Tang Nano 20K](https://github.com/YosysHQ/apicula/blob/master/examples/tangnano20k.cst).

## Validação e recursos

Versão 0.2.0: ambas as configurações foram simuladas, sintetizadas e roteadas.
A validação inclui retorno serial, padrões de LEDs da aplicação, reset,
remoção dos diagnósticos, fila RX e cliente Python. O clock é de 27 MHz.

| Recurso | Diagnóstico ligado | Diagnóstico desligado |
|---|---:|---:|
| LUT4 (20.736 disponíveis) | 623 — 3,00% | 566 — 2,73% |
| DFF (15.552 disponíveis) | 234 — 1,50% | 205 — 1,32% |
| RAM16SDP4 (648 disponíveis) | 18 — 2,78% | 18 — 2,78% |
| BSRAM / DSP / PLL | 0 | 0 |
| BUFG (24 disponíveis) | 1 — 4,17% | 1 — 4,17% |

A memória distribuída aloca 144 bytes. Os recursos da aplicação principal que
venha a controlar os LEDs serão adicionados a esses números. Os percentuais de
recursos diferentes não devem ser somados.

Veja [o relatório de validação](docs/VALIDACAO.md) para frequência estimada,
escopo dos testes e distinção entre simulação e validação física anterior.
Execute `make resources LEDS=0` ou `make resources LEDS=1` para obter os números
da sua compilação.

## Repositório e pacote de reuso

Os arquivos de fonte, testes, configuração e documentação são versionáveis;
`build/`, `dist/`, caches e saídas da Lushay ficam fora do Git. O projeto pode
ser copiado como uma pasta independente. `VERSION` identifica a versão atual e
[CHANGELOG.md](CHANGELOG.md) registra as mudanças.

```sh
make package  # dist/serial-uart-0.2.0.zip
```

O ZIP contém fontes, exemplos, documentação e um manifesto SHA256, sem
bitstreams, logs locais ou dependência do projeto blink. Para preparar alterações,
consulte [CONTRIBUTING.md](CONTRIBUTING.md).

## Licença

Este projeto usa a licença [GNU GPL v3.0](LICENSE), selecionada na criação do
repositório. O texto completo acompanha os fontes e o pacote de reuso.
