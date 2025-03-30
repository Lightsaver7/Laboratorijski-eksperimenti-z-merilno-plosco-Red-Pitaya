#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

void Out32(void *adr, int offset, int value)
{
    *((uint32_t *)(adr+offset)) = value;
}

int In32(void *adr, int offset)
{
    return *((uint32_t *)(adr+offset));
}

int In16(void *adr, int offset)
{
    int r;
    r= *((uint32_t *)(adr+offset));
    if (r > 32767) return r-65536;
    return r;
}


int main(int argc, char **argv)
{
  // Memmory mapping varibles
  int fd;
  int BASE = 0x40300000; // Proc base address;
  void *adr;
  char *name = "/dev/mem";
  int d,id;

  // Example variables
  int led_reg = 0x01;
  int dac_const_value = 0x1eff;
  int adc_sample = 0;
  
  
  /* open memory device */
  if((fd = open(name, O_RDWR)) < 0) {
    perror("open");
    return 1;
  }

  /* map the memory, start from BASE address, size: _SC_PAGESIZE = 4k */
  adr = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, BASE);

  /* Register offset (base 0x40300000)
  - 0x10 - direction of DIO P pins (0 == input, 1 == output) (R/W)
  - 0x14 - direction of DIO N pins (R/W)
  - 0x18 - output value of DIO P pins (R/W)
  - 0x1C - output value of DIO N pins (R/W)
  - 0x20 - input value of DIO P pins (R)
  - 0x24 - input value of DIO N pins (R)
  - 0x30 - LED control (R/W)
  - 0x50 - ID  (R/W)
  - 0x54 - amplitude OUT1 (R/W)
  - 0x58 - ADC trigger (R/W)
  - 0x5C - DAC trigger (R/W)
  - 0x60 - ADC sample (R)
  - 0x64 - DAC sample (R/W)
  */

  // Read and display ID
  id = In32(adr, 0x50);
  printf("ID = %x\n",id);
  sleep(1);

  // Turn on LED0
  Out32(adr, 0x30, 1);

  // Write to DAC register (OUT2)
  Out32(adr, 0x64, dac_const_value);

  // Trigger DAC output (OUT2)
  Out32(adr, 0x5C, 1);

  // Trigger acquisition
  Out32(adr, 0x58, 1);

  // Read acquisition sample
  adc_sample = In32(adr, 0x60);
  printf("ADC value: %x\n", adc_sample);
  sleep(1);

  munmap(adr, sysconf(_SC_PAGESIZE));
  return 0;
}
