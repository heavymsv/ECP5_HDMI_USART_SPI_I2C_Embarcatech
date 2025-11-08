# ECP5_HDMI_USART_SPI_I2C_Embarcatech

![Yosys](https://img.shields.io/badge/Synthesis-Yosys-blue?logo=yosys) ![NextPNR](https://img.shields.io/badge/Place%20%26%20Route-NextPNR-green) ![License](https://img.shields.io/badge/License-MIT-yellow) ![FPGA](https://img.shields.io/badge/FPGA-Lattice%20ECP5-orange)

### Integração de Interfaces Sensoriais e Geração de Vídeo em FPGA na Plataforma Colorlight i9 (Lattice ECP5)

Este projeto foi desenvolvido no âmbito do programa **Residência Tecnológica EmbarcaTech (TIC 37 - IFMA)** e tem como objetivo a criação de um **sistema embarcado reconfigurável** capaz de adquirir dados sensoriais, processá-los em hardware e exibi-los em tempo real via **HDMI**, utilizando a FPGA **Colorlight i9** (baseada no **Lattice ECP5 LFE5U-45F**).

---

## 🧠 Visão Geral do Projeto

O sistema integra três subsistemas principais:

1. **Aquisição Sensorial (I²C/SPI)**

   * Leitura de sensores digitais via barramentos seriais.
   * Versão inicial: ADXL345 (acelerômetro, via I²C).
   * Versão final (protótipo físico): BMP280 (pressão e temperatura, via SPI).

2. **Transmissão Serial (UART)**

   * Comunicação assíncrona com padrão **16x oversampling**.
   * Utilizada para depuração e envio de dados via **USART TX**.

3. **Renderização de Vídeo HDMI (720p@60Hz)**

   * Geração de sinais de vídeo com sincronização **VESA 1280×720@60Hz**.
   * Codificação **TMDS (8b/10b)** para transmissão diferencial.
   * Utiliza **PLL (EHXPLLL)** para gerar clocks de até **371,25 MHz**.
   * Serialização dos sinais com registradores **ODDR**.

---

## ⚙️ Arquitetura e Metodologia

O projeto foi desenvolvido integralmente em **SystemVerilog**, com design modular e FSMs para controle dos protocolos seriais e de vídeo.

Além disso, o subsistema de renderização HDMI baseia-se no repositório **[Project F - FPGA Graphics](https://github.com/projf/projf-explore/tree/main/graphics/fpga-graphics)**, adaptado para integrar o pipeline de vídeo e o controle TMDS no contexto da FPGA Colorlight i9.

| Módulo                           | Função Principal        | Destaques Técnicos                                                   |
| -------------------------------- | ----------------------- | -------------------------------------------------------------------- |
| **I2C Master**                   | Comunicação com ADXL345 | FSM de 10 estados, emulação de open-drain (tri-state).               |
| **SPI Master**                   | Comunicação com BMP280  | Leitura dos 24 coeficientes de calibração e compensação em hardware. |
| **UART TX**                      | Transmissão assíncrona  | Oversampling 16x, precisão temporal aprimorada.                      |
| **HDMI Renderer / TMDS Encoder** | Geração de vídeo 720p   | Codificação 8b/10b e double-buffering entre domínios de clock.       |
| **PLL (EHXPLLL)**                | Geração de clocks       | Produz 74.25 MHz (pixel) e 371.25 MHz (serial).                      |

---

## 🧩 Ferramentas Utilizadas

| Tipo          | Ferramenta             | Descrição                                     |
| ------------- | ---------------------- | --------------------------------------------- |
| Síntese       | **Yosys**              | Geração de netlist a partir do SystemVerilog. |
| Place & Route | **NextPNR**            | Mapeamento para o dispositivo Lattice ECP5.   |
| Bitstream     | **Project Trellis**    | Geração final do arquivo `.bit` para a FPGA.  |
| Simulação     | **GTKWave / iverilog** | Testbench e depuração dos módulos FSM.        |

---

## 💡 Adaptações e Versão Final (Protótipo Demonstrado)

Durante os testes práticos, foi identificada a dificuldade de emular corretamente o **dreno aberto (open-drain)** do I²C no ECP5.
Assim, a versão final do hardware apresentado utilizou:

* **Protocolo SPI** (em vez de I²C);
* **Sensor BMP280** (substituindo o ADXL345);
* **Lógica de compensação** implementada em hardware para cálculo de pressão e temperatura em tempo real.

---

## 🧪 Resultados

* Comunicação SPI validada com o sensor BMP280.
* Geração estável de vídeo HDMI a **720p@60Hz** com codificação TMDS funcional.
* Clock de serialização atingindo **742.5 Mbps** sem transceptores SERDES dedicados.
* Comunicação UART TX funcional via oversampling 16x.
* Sincronização entre domínios de clock (CDC) com **double-buffering**.

---

## 📁 Estrutura do Repositório

```
ECP5_HDMI_USART_SPI_I2C_Embarcatech/
├── src/                  # Códigos-fonte em SystemVerilog
│   ├── i2c_master.sv
│   ├── spi_master.sv
│   ├── uart_tx.sv
│   ├── renderer_720p.sv
│   ├── tmds_encoder.sv
│   ├── pll_config.sv
│   └── top.sv
├── constraints/          # Arquivos .lpf (mapeamento de pinos)
├── sim/                  # Testbenches e scripts de simulação
├── build/                # Scripts para síntese e bitstream
└── README.md
```

---

## 🧰 Requisitos de Hardware

* FPGA: **Colorlight i9 (Lattice ECP5 LFE5U-45F-6BG381C)**
* Sensor: **ADXL345** (I²C) ou **BMP280** (SPI)
* Saída de vídeo: **HDMI (720p@60Hz)**
* Interface serial: **UART (115200 bps)**

---

## 🚀 Como Rodar o Projeto

1. **Clone o repositório:**

   ```bash
   git clone https://github.com/heavymsv/ECP5_HDMI_USART_SPI_I2C_Embarcatech.git
   cd ECP5_HDMI_USART_SPI_I2C_Embarcatech
   ```

2. **Sintetize o projeto:**

   ```bash
   yosys -p "synth_ecp5 -top top -json top.json" src/*.sv
   ```

3. **Execute o Place & Route:**

   ```bash
   nextpnr-ecp5 --json top.json --lpf constraints/colorlight_i9.lpf --textcfg top.config --85k
   ```

4. **Gere o bitstream:**

   ```bash
   ecppack top.config top.bit
   ```

5. **Carregue na FPGA:**

   ```bash
   openFPGALoader -b colorlight-i9 top.bit
   ```

---

## 📊 Futuras Extensões

* Implementação do **Receptor UART (RX)** para comunicação bidirecional.
* Renderização de texto via **Character ROM em BRAM**.
* Suporte a resoluções superiores (1080p) com pipelining otimizado.

---

## 👥 Autores

* **Agnes de Oliveira Freire**
* **Antonio Sergio Castro de Carvalho Jr**
* **Matheus Santos Vieira**
* **Valmir Linhares de Sousa de Mesquita**

Residência Tecnológica **EmbarcaTech TIC 37 – IFMA**

---

## 📜 Licença

Este projeto é distribuído sob a licença **MIT**.
Consulte o arquivo `LICENSE` para mais detalhes.

---

## 📚 Referências Principais

* [Analog Devices – ADXL345 Datasheet](https://www.analog.com/en/products/adxl345.html)
* [Project F – FPGA Graphics](https://github.com/projf/projf-explore/tree/main/graphics/fpga-graphics)
* [Project F – ECP5 FPGA Clock Generation](https://projectf.io/posts/ecp5-fpga-clock/)
* [Colorlight i9 Tools – GitHub](https://github.com/kittennbfive/Colorlight-i9-tools)
* [Yosys Open Source Synthesis Suite](https://github.com/YosysHQ/yosys)
* [NextPNR – Open Source Place & Route](https://github.com/YosysHQ/nextpnr)

---

> 🧩 *“Compreender o domínio de clock, as primitivas de hardware e o controle de protocolos seriais é essencial para o sucesso em projetos FPGA.”*
