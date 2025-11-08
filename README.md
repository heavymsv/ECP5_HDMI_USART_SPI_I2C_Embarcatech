# Integração de Interfaces Sensoriais e Geração de Vídeo em FPGA (Colorlight i9)

[cite_start]Este repositório contém o código-fonte (SystemVerilog/Verilog) para o projeto de um sistema embarcado reconfigurável desenvolvido para a placa FPGA **Colorlight i9 (Lattice ECP5)**[cite: 1, 6, 12].

[cite_start]O objetivo do sistema é ler dados de sensores, processá-los e exibi-los em tempo real através de uma saída de vídeo HDMI, além de fornecer comunicação serial para depuração[cite: 5, 11].

[cite_start]Este projeto foi desenvolvido como parte do programa **EmbarcaTech TIC 37**, uma parceria com o **Instituto Federal do Maranhão (IFMA)**[cite: 4, 105].

## Hardware e Plataforma

* [cite_start]**FPGA:** Placa Colorlight i9 [cite: 49]
* [cite_start]**Chip:** Lattice ECP5 (LFE5U-45F) [cite: 21, 49]
* **Sensores (descritos no projeto):**
    * [cite_start]Sensor de Pressão e Temperatura BMP280 (implementação final) [cite: 60]
    * [cite_start]Acelerômetro ADXL345 (design original) [cite: 21, 56]
* [cite_start]**Saída:** HDMI (conector de expansão) [cite: 50]

---

## Módulos e Funcionalidades Implementadas

[cite_start]O design é escrito em SystemVerilog [cite: 7, 13, 45] e inclui os seguintes módulos principais:

* ### Subsistema de Vídeo HDMI (720p@60Hz)
    * [cite_start]**Gerador de Temporização VESA:** Cria os sinais `HSYNC`, `VSYNC` e `Data Enable` para a resolução de 1280x720@60Hz[cite: 28, 42, 54].
    * [cite_start]**Codificador TMDS:** Implementa a codificação 8b/10b necessária para a sinalização HDMI, garantindo o balanço de DC[cite: 28, 43, 54].
    * [cite_start]**Serializador de Alta Velocidade:** Utiliza as primitivas `ODDR` (Output Double Data Rate) do ECP5 para serializar os dados e atingir o *bit rate* de 742.5 Mbps[cite: 54, 79, 88].

* ### Geração de Clock (PLL)
    * [cite_start]Utiliza a primitiva `EHXPLLL` do Lattice ECP5 para gerar os clocks de alta velocidade necessários para o vídeo[cite: 29, 75].
    * [cite_start]A partir de um clock de entrada de 25 MHz, o PLL gera[cite: 76, 78]:
        * [cite_start]**`clk_pix` (Pixel Clock):** 74.25 MHz [cite: 78]
        * [cite_start]**`clk_ser` (Serialization Clock):** 371.25 MHz (5x o *Pixel Clock*) [cite: 78]

* ### Módulos de Comunicação Serial
    * [cite_start]**SPI Mestre:** Controlador para interface com o sensor BMP280 (implementação final)[cite: 59].
    * [cite_start]**I2C Mestre:** Controlador com emulação de lógica *open-drain* (via `tri-state`) para interface com o sensor ADXL345 (design original)[cite: 26, 54].
    * [cite_start]**Transmissor UART:** Implementado com padrão de *oversampling* 16x para comunicação assíncrona e depuração[cite: 27, 54].

* ### Módulos de Lógica e Processamento
    * [cite_start]**Lógica de Compensação (BMP280):** Módulo de hardware complexo que lê os 24 coeficientes de calibração do BMP280 e converte os dados brutos de pressão e temperatura em valores finais (hPa e °C)[cite: 61, 131].
    * [cite_start]**Gerenciamento de Domínio de Clock (CDC):** Implementa `double-buffering` para transferir dados de forma segura entre os domínios de clock lentos (sensores) e o domínio de clock rápido do pixel (74.25 MHz), evitando *tearing* visual[cite: 9, 15, 54, 98].

---

## Nota Importante sobre o Projeto (I2C/ADXL345 vs. SPI/BMP280)

[cite_start]Este repositório e o relatório técnico associado descrevem duas arquiteturas de sensores[cite: 56, 62]:

1.  [cite_start]**Design Original:** Utilizava um mestre **I2C** para se comunicar com um acelerômetro **ADXL345**[cite: 56]. Os módulos para esta implementação estão presentes no projeto.
2.  [cite_start]**Implementação Final (Protótipo):** Devido a desafios técnicos de última hora durante os testes [cite: 57][cite_start], o hardware do protótipo final foi adaptado[cite: 58]. [cite_start]O módulo I2C foi substituído por um mestre **SPI** [cite: 59] [cite_start]e o sensor ADXL345 foi substituído por um sensor de pressão e temperatura **BMP280**[cite: 60].

[cite_start]O código-fonte no repositório reflete a **arquitetura final demonstrada (SPI/BMP280)**, incluindo a lógica de compensação de hardware necessária para o BMP280[cite: 61, 62, 131].

---

## Fluxo de Ferramentas (Toolchain)

[cite_start]Este projeto foi desenvolvido utilizando o fluxo de ferramentas *open-source* para FPGAs da Lattice[cite: 35, 51]. Para sintetizar e gerar o *bitstream*:

1.  [cite_start]**Síntese:** `Yosys` [cite: 51, 133]
2.  [cite_start]**Place and Route:** `Nextpnr` [cite: 51, 133]
3.  [cite_start]**Geração do Bitstream:** `Project Trellis` [cite: 51]

[cite_start]O arquivo de restrições de pinos (`.lpf`) é baseado no *pinout* da comunidade para a placa Colorlight i9[cite: 69, 96].

## Autores do Projeto

* [cite_start]Agnes de Oliveira Freire [cite: 2]
* [cite_start]Antonio Sergio Castro de Carvalho Jr [cite: 2]
* [cite_start]Matheus Santos Vieira [cite: 3]
* [cite_start]Valmir Linhares de Sousa de Mesquita [cite: 3]

## Agradecimentos

[cite_start]Este trabalho foi realizado com o apoio do programa **EmbarcaTech TIC 37 (Softex)** e do **Instituto Federal do Maranhão (IFMA)**[cite: 105].
