CFLAGS  = -Wall ## -Werror
CFLAGS += -I/opt/redpitaya/include
LDFLAGS = -L/opt/redpitaya/lib

LDLIBS = -static -lrp-hw-can -lrp-sweep -lrp -lrp-hw-calib -lrp-hw-profiles
LDLIBS += -lrp-gpio -lrp-i2c -lrpapp_lcr -lrp-dsp -lrp-spi
LDLIBS += -lrp-hw -lm -lstdc++ -lpthread -li2c -lsocketcan
LDLIBS += -lrp-la

INCLUDE += -I/opt/redpitaya/include/api250-12

# List of compiled object files (not yet linked to executable)

PRGS =	config_fir_mod \
		config_uart_spi

OBJS := $(patsubst %,%.o,$(PRGS))
SRC := $(patsubst %,%.cpp,$(PRGS))

all: $(PRGS)

$(PRGS): %: %.cpp
	g++ $< $(CFLAGS) $(LDFLAGS) $(LDLIBS) -o $@

clean:
	$(RM) *.o
	$(RM) $(OBJS)

clean_all: clean
	$(RM) $(PRGS)
