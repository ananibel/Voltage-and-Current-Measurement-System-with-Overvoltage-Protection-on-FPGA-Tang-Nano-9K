# Voltage and Current Measurement System with Overvoltage Protection on FPGA

<p align="center">
  <img src="https://img.shields.io/badge/FPGA-Tang%20Nano%209K-orange.svg" alt="FPGA Platform">
  <img src="https://img.shields.io/badge/Language-VHDL-blue.svg" alt="Language: VHDL">
  <img src="https://img.shields.io/badge/IDE-Gowin%20EDA-brightgreen.svg" alt="Gowin EDA">
</p>

---

## 📖 Overview

This project presents a robust monitoring system for DC voltage and current, designed and implemented on a **Gowin Tang Nano 9K FPGA**. The system accurately measures analog signals using an **ADS1115 ADC module** and displays the real-time values on an LCD screen.

A key feature of this project is the custom-developed VHDL driver for the I2C communication with the ADS1115, created to overcome compatibility issues with existing libraries on the Tang Nano platform. Furthermore, the design incorporates a critical hardware-based **overvoltage protection circuit** that automatically disconnects the power source to safeguard the system, with a mechanism to safely reconnect upon reset.

---

## ✨ Key Features

* **Real-Time Monitoring**: Continuously measures and displays voltage and current values.
* **Custom I2C Driver**: A reliable, custom-built VHDL module (`ads_driver`) for interfacing with the ADS1115 ADC, tailored for the Tang Nano 9K.
* **Overvoltage Protection**: A transistor-based circuit automatically disconnects the power source when voltage exceeds a predefined threshold, preventing damage to the system.
* **Safe Reconnection**: The system can be safely reconnected to the power source via a reset pulse after an overvoltage event.
* **LCD Interface**: Displays real-time measurements and system status indicators for user-friendly feedback.
* **Hardware Protection**: A resistive voltage divider scales the input voltage to a safe level for the ADC and FPGA.

---

## 🛠️ Hardware & Software

### Hardware Components
* **FPGA**: Gowin Tang Nano 9K
* **ADC**: ADS1115 16-Bit ADC Module
* **Display**: Standard LCD Screen (e.g., 16x2)
* **Protection Circuit**: Custom circuit using a transistor (e.g., BJT or MOSFET) and passive components.
* **Power Source**: The DC source to be monitored.

### Software & Tools
* **IDE**: Gowin EDA
* **Language**: VHDL

---

## 📂 VHDL Modules & Project Structure

The project is structured around several VHDL modules, with the core logic residing in the FPGA. The main components are:

* `ads_driver.vhd`: The heart of the ADC interface. This module manages the I2C communication protocol to configure the ADS1115 and read conversion data.
* `i2c_master.vhd`: A generic I2C master component utilized by the `ads_driver`.
* `lcd_controller.vhd`: A module to handle the display logic for the LCD screen.
* `top_level.vhd`: The main entity that integrates all sub-modules and defines the top-level pinout for the Tang Nano 9K.

---

## 🚀 Setup and Implementation

### 1. Hardware Setup
* Connect the ADS1115 module to the Tang Nano 9K, ensuring the `SCL`, `SDA`, `VCC`, and `GND` pins are correctly wired to the FPGA's I/O pins.
* Connect the LCD screen to the designated GPIO pins on the FPGA.
* Assemble the overvoltage protection circuit and place it between the power source and the system's power input.
* Connect the voltage divider to the input channel of the ADS1115.

### 2. FPGA Programming
* Open the project in Gowin EDA.
* Synthesize the VHDL code and ensure there are no errors.
* Use the Gowin Programmer tool to flash the generated `.fs` bitstream file onto the Tang Nano 9K.

### 3. Operation
* Power on the system. The LCD should initialize and begin displaying voltage and current readings.
* If an overvoltage event occurs, the protection circuit will trip, and the system will power down. An indicator on the LCD may show an "OVERVOLTAGE" status.
* To restore operation, disconnect the faulty power source and press the reset button on the board.

This project serves as a practical example of integrating analog sensors with an FPGA and implementing robust hardware protection mechanisms.
