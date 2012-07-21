CC      = gcc
LIBS    = -lpthread
DEBUGFL = -g
CFLAGS  = $(DEBUGFL) -c -Wall

TARGET	= fs-test
TARGET1	= log-server
TARGET2	= send-sep

SRCS    = main.c fio_thread.c sync.c
OBJS	= $(SRCS:.c=.o)

SRCS1   = log-server.c
OBJS1	= $(SRCS1:.c=.o)

SRCS2   = send-sep.c
OBJS2	= $(SRCS2:.c=.o)

CFLAGS += -D_GNU_SOURCE # for pthread_barrier

all: $(TARGET) $(TARGET1) $(TARGET2)

$(TARGET): $(OBJS) config.h
	$(CC) -o $(TARGET) $(OBJS) $(LIBS)

$(TARGET1): $(OBJS1) config.h
	$(CC) -o $(TARGET1) $(OBJS1) $(LIBS)

$(TARGET2): $(OBJS2) config.h
	$(CC) -o $(TARGET2) $(OBJS2) $(LIBS)

.c.o: 
	$(CC) $(CFLAGS) $(DEBUGFL) -c $<

clean:
	rm -f $(TARGET) $(TARGET1) $(TARGET2) *.o *~

