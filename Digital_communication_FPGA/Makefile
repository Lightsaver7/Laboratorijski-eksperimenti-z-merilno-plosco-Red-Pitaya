MODEL ?= Z10

CFLAGS  = -std=gnu11 -Wall ## -Werror
CFLAGS += -I/opt/redpitaya/include -D$(MODEL)
LDFLAGS = -L/opt/redpitaya/lib
LDLIBS = -static -lrp

ifeq ($(MODEL),Z20_250_12)
INCLUDE += -I/opt/redpitaya/include/api250-12
LDLIBS += -lrp-gpio -lrp-i2c
endif

LDLIBS += -lrp-hw -lm -lstdc++ -lpthread


# List of compiled object files (not yet linked to executable)

PRGS =  uart

OBJS := $(patsubst %,%.o,$(PRGS))
SRC := $(patsubst %,%.c,$(PRGS))

all: $(PRGS)

$(PRGS): %: %.c
	$(CC) $< $(CFLAGS) $(LDFLAGS) $(LDLIBS) -o $@

clean:
	$(RM) *.o
	$(RM) $(OBJS)