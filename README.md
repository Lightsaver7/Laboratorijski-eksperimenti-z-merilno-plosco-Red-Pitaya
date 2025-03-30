# Laboratorijski-eksperimenti-z-merilno-plosco-Red-Pitaya
Pripadajoče FPGA vezje in komponente za magistrsko nalogo "Eksperimenti z merilno ploščo Red Pitaya".

Koda v repozitoriju je razdeljena v naslednje datoteke:

- **Digital_communication_FPGA** – vsebuje dodatne in spremenjene FPGA komponente, ki nadgradijo projekt "logic" z generatorjema za UART in SPI na digitalnih pinih DIO0_N – DIO5_N.
- **Modulation_division_FPGA** – vsebuje dodatne in spremenjene FPGA komponente, ki nadgradijo projekt "v0.94" z dodatkom modulacije izhodnih signalov na izhod modula "ASG" ter splošnega FIR filtra s pripadajočim vezjem za decimacijo frekvence in vhodnega signala (2^n) na vhod modula "scope".
- **General_project** – vsebuje FPGA komponente za dodatek splošne komponente v projekt "v0.94" ter pripadajoče datoteke za avtomatsko menjavo FPGA vezja.

# Laboratory experiments with measurement platform Red Pitaya
FPGA circuit and components for the Master's thesis "Experiments with the Red Pitaya measurement board".

The code in the repository is divided into the following files:

- **Digital_communication_FPGA** - contains additional and modified FPGA components that upgrade the project "logic" with generators for UART and SPI on digital pins DIO0_N - DIO5_N.
- **Modulation_division_FPGA** - contains additional and modified FPGA components that upgrade the "v0.94" project by adding output signal modulation to the output of the "ASG" module and a general FIR filter with associated frequency and input signal decimation circuitry (2^n) to the input of the "scope" module.
- **General_project** - contains the FPGA components for adding the general component to the "v0.94" project and the associated files for automatic FPGA circuit change.
