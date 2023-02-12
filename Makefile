TARGET = particle-life

SRC = src/main.c

CC = gcc
CFLAGS  =  -Wall -Wextra
CFLAGS  += -I./lib/SDL/include/
LDFLAGS =  SDL2.dll

all: $(SRC)
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)

run: all
	./$(TARGET)
