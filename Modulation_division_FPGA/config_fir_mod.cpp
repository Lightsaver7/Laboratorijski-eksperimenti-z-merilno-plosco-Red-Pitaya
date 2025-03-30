#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <cmath>
#include <iostream>


#define ONE 8192

void Out32(void *adr, int offset, int value)
{
    *((uint32_t *)(adr+offset)) = value;
}

int In32(void *adr, int offset)
{
    return *((uint32_t *)(adr+offset));
}

int In16(void *adr, int offset){
    int r;
    r= *((uint32_t *)(adr+offset));
    if (r > 32767) return r-65536;
    return r;
}


int main(int argc, char **argv)
{
    int fd;
    int BASE_PROC = 0x40300000; // Proc base address;
    int BASE_AWG = 0x40200000;  // AWG base address;
    void *adr_proc;
    void *adr_awg;
    char *name = (char *)"/dev/mem";
    int id;

    int out_carrier, out_message;
    int A_message, A_carrier;
    int Offset_message, Offset_carrier;    
    int mod_fact        = ONE;                   // Modulation factor
    int mod_out_scale   = ONE;

    int fir_coef_table[][6]= {{21, -25, -80,  32, 320, 486},    // Low Pass 1
                              {93, 93, 93, 93, 93, 93},         // Low Pass 2
                              {-2, 26, 38, -60, -252, 511},     // High Pass 1
                              {-7, -18, 58, 49, -339, 511},     // High Pass 2
                              {67, -52, 286, 236, 218, 511},    // Band Pass 1
                              {-81, -22, -42, -210, 123, 511},  // Band Pass 2
                              {118, 32, 62, 303, -175, 511},    // Band Stop 1
                              {9, -66, -21, 180, 12, 511},      // Band Stop 2
                              {9, -101, -13, 98, 4, 511},       // Hard to determine (Band stop)
                              {-345, 291, 45, 10, 300, 511},    // Hard to determine (Band pass)
                              {-60, -23, 67, -122, 168, 511},   // Hard to determine (Low pass)
                              {-105, -27, -29, -31, -32, 511}}; // Hard to determine (High pass)
    
    /* open memory device */
    if((fd = open(name, O_RDWR)) < 0) {
        perror("open");
        return 1;
    }

    /* map the memory, start from BASE address, size: _SC_PAGESIZE = 4k */
    adr_proc = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, BASE_PROC);
    adr_awg  = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, BASE_AWG);


    /* ###    ADDRESS SPACE   ### */
    /*
        Base = 0x40300000;

        #####   WRITE   #####           #####   READ   #####            #####   INFO   #####
        0x00010                                0x00010                  -- GPIO P direction
        0x00014                                0x00014                  -- GPIO N direction
        0x00018                                0x00018                  -- GPIO P output
        0x0001C                                0x0001C                  -- GPIO N output
        -                                      0x00020                  -- GPIO P inputs
        -                                      0x00024                  -- GPIO N inputs
        0x00030                                0x00030                  -- LEDs
        0x00050                                0x00050                  -- ID + fir enable
        0x00054                                -                        -- FIR change coefficients
        0x00058                                0x00058                  -- Write temp coef / Read temp coeficients
        0x00060                                0x00060                  -- Freq division enable
        0x00064                                0x00064                  -- Averaging enable/disable
        0x00068                                0x00068                  -- Frequency divison
        0x00070                                0x00070                  -- Modulation enable
        0x00074                                0x00074                  -- Modulation carrier channel select
        0x00078                                0x00078                  -- Modulation factor
        0x0007C                                0x0007C                  -- Modulation output scaling factor

    */

    /* ###    VARIABLES   ### */
    int dig_pin_p_dir   = 0b00000000;
    int dig_pin_n_dir   = 0b00000000;
    int dig_pin_p_out   = 0b00000000;
    int dig_pin_n_out   = 0b00000000;
    int leds            = 0b00000000;

    int fir_en          = 0;
    int fir_change_coef = 1;
    int fir_coef[6]     = {0, 0, 0, 0, 0, 0};
    int enable_freq_div = 0;
    int avg_nFirst      = 1;                // Avg = 1, First = 0
    int freq_div        = 0;                // 0 == 2, 1 == 4, 2 == 8, 3 == 16
    
    int mod_en          = 0;
    int mod_car_ch      = 1;                // 1 == OUT1, 2 == OUT2


    A_carrier = round(1.0 * ONE);
    A_message = round(1.0 * ONE);


    /* ### Read input parameters and set variables ### */
    if (argc > 1) {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-fir") == 0) {
                if (i + 1 < argc) {
                    int fir = atoi(argv[i + 1]);
                    if (fir >= 0 && fir <= 11) {
                        for (int j = 0; j < 6; j++) {
                            fir_coef[j] = fir_coef_table[fir][j];
                        }
                        i++;
                    } else {
                        std::cout << "Invalid FIR filter number!" << std::endl;
                        return 1;
                    }
                } else {
                    std::cout << "Missing FIR filter number!" << std::endl;
                    return 1;
                }
            } else if (strcmp(argv[i], "-fir_en") == 0) {
                if (i + 1 < argc) {
                    fir_en = atoi(argv[i + 1]);
                    if (fir_en != 0 && fir_en != 1) {
                        std::cout << "Invalid FIR enable value!" << std::endl;
                        return 1;
                    }
                    i++;
                } else {
                    std::cout << "Missing FIR enable value!" << std::endl;
                    return 1;
                }
            } else if (strcmp(argv[i], "-freq_div") == 0) {
                if (i + 1 < argc) {
                    enable_freq_div = 1;
                    freq_div = atoi(argv[i + 1]);
                    if (freq_div < 0 || freq_div > 3) {
                        std::cout << "Invalid frequency division value!" << std::endl;
                        return 1;
                    }
                    i++;
                } else {
                    std::cout << "Missing frequency division value!" << std::endl;
                    return 1;
                }
            } else if (strcmp(argv[i], "-avg") == 0) {
                if (i + 1 < argc) {
                    avg_nFirst = atoi(argv[i + 1]);
                    if (avg_nFirst != 0 && avg_nFirst != 1) {
                        std::cout << "Invalid averaging/first value!" << std::endl;
                        return 1;
                    }
                    i++;
                } else {
                    std::cout << "Missing averaging/first value!" << std::endl;
                    return 1;
                }
            } else if (strcmp(argv[i], "-mod") == 0) {
                if (i + 1 < argc) {
                    mod_en = atoi(argv[i + 1]);
                    if (mod_en != 0 && mod_en != 1) {
                        std::cout << "Invalid modulation enable value!" << std::endl;
                        return 1;
                    }
                    i++;
                } else {
                    std::cout << "Missing modulation enable value!" << std::endl;
                    return 1;
                }
            } else if (strcmp(argv[i], "-mod_ch") == 0) {
                if (i + 1 < argc) {
                    mod_car_ch = atoi(argv[i + 1]);
                    if (mod_car_ch != 1 && mod_car_ch != 2) {
                        std::cout << "Invalid modulation carrier channel value!" << std::endl;
                        return 1;
                    }
                    i++;
                } else {
                    std::cout << "Missing modulation carrier channel value!" << std::endl;
                    return 1;
                }
            } else if (strcmp(argv[i], "-A_carrier") == 0) {
                if (i + 1 < argc) {
                    A_carrier = atoi(argv[i + 1]);
                    if (A_carrier < 0 || A_carrier > ONE) {
                        std::cout << "Invalid carrier amplitude value!" << std::endl;
                        return 1;
                    }
                    i++;
                } else {
                    std::cout << "Missing carrier amplitude value!" << std::endl;
                    return 1;
                }
            } else if (strcmp(argv[i], "-A_message") == 0) {
                if (i + 1 < argc) {
                    A_message = atoi(argv[i + 1]);
                    if (A_message < 0 || A_message > ONE) {
                        std::cout << "Invalid message amplitude value!" << std::endl;
                        return 1;
                    }
                    i++;
                } else {
                    std::cout << "Missing message amplitude value!" << std::endl;
                    return 1;
                }
            } else {
                std::cout << "Invalid parameter!" << std::endl;
                return 1;
            }
        }
    }


    /* Get amplitude values form Red Pitaya */
    /*
    if (mod_car_ch == 1) {
        out_carrier = In32(adr_awg, 0x4);
        out_message = In32(adr_awg, 0x24);
    } else {
        out_carrier = In32(adr_awg, 0x24);
        out_message = In32(adr_awg, 0x4);
    }

    A_carrier = (out_carrier & 0x0000FFFF);
    A_message = (out_message & 0x0000FFFF);
    std::cout << "Carrier amplitude = " << A_carrier << std::endl;
    std::cout << "Message amplitude = " << A_message << std::endl;
    Offset_carrier = (out_carrier & 0xFFFF0000) >> 16;
    Offset_message = (out_message & 0xFFFF0000) >> 16;
    std::cout << "Carrier offset = " << Offset_carrier << std::endl;
    std::cout << "Message offset = " << Offset_message << std::endl;
    */
    if (A_message > A_carrier) {
        std::cout << "WARNING Message amplitude is bigger than carrier amplitude!" << std::endl;
    }

    mod_fact = round((float)A_message/(float)A_carrier * ONE);
    std::cout << "Modulation factor = " << mod_fact << std::endl;

    /* Apply scaling if the output is too big */
    if (A_carrier + A_message > ONE) {
        mod_out_scale = round((float)A_carrier/((float)A_message + (float)A_carrier) * ONE);       // Scaling factor for output
        std::cout << "Modulation output scaling factor = " << mod_out_scale << std::endl;
    } else {
        mod_out_scale = ONE;
    }


    /* Read and display ID */
    id = In32(adr_proc, 0x50);
    std::cout << "ID = 0x" << std::hex << id << std::dec << std::endl << std::endl;

    /* Configure settings */
    Out32(adr_proc, 0x00010, dig_pin_p_dir);
    Out32(adr_proc, 0x00014, dig_pin_n_dir);
    Out32(adr_proc, 0x00018, dig_pin_p_out);
    Out32(adr_proc, 0x0001C, dig_pin_n_out);
    Out32(adr_proc, 0x00030, leds);
    Out32(adr_proc, 0x00050, fir_en);
    for (int i = 0; i < 6; i++) {               // Write FIR temporary coefficients
        Out32(adr_proc, 0x00058, fir_coef[i]);
    }
    for (int i = 0; i < 6; i++) {               // Read FIR coefficients
        std::cout << "FIR[" << i << "] = " << fir_coef[i] << std::endl;
    }
    Out32(adr_proc, 0x00054, fir_change_coef);  // Change FIR coefficients
    Out32(adr_proc, 0x00060, enable_freq_div);
    Out32(adr_proc, 0x00064, avg_nFirst);
    Out32(adr_proc, 0x00068, freq_div);
    Out32(adr_proc, 0x00070, mod_en);
    Out32(adr_proc, 0x00074, mod_car_ch - 1);
    Out32(adr_proc, 0x00078, mod_fact);
    Out32(adr_proc, 0x0007C, mod_out_scale);

    
    std:: cout << std::endl << "End of program!" << std::endl << std::endl;
    munmap(adr_proc, sysconf(_SC_PAGESIZE));
    munmap(adr_awg, sysconf(_SC_PAGESIZE));
    return 0;
}




