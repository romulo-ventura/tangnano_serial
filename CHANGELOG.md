# Histórico

## 0.2.0 — 2026-10-29

- LEDs opcionais via `ENABLE_DIAGNOSTIC_LEDS` e `make LEDS=0/1`.
- Aplicação principal pode controlar os seis LEDs com `app_led_on`.
- Contador e estados de diagnóstico removidos por generate quando desativados.
- Bitstreams separados por configuração em `build/leds0` e `build/leds1`.
- Testes das duas configurações, propriedade dos LEDs, reset e erro persistente.
- Relatório de recursos reproduzível, exemplo de integração, tarefas VS Code,
  guia de manutenção e pacote de fontes com manifesto SHA256.

## 0.1.0

- UART 8N1 modular, FIFO RX, interfaces valid/ready e reset síncrono.
- Protocolo de echo identificado e parametrizável.
- Cliente serial Python e testes de simulação/hardware.
