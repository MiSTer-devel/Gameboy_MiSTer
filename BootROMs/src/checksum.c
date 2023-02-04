#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define DMG_BIOS_SIZE 256
#define CGB_BIOS_SIZE 2304
#define PRINT_BYTES_PER_COL 16

int checksum_single_byte(FILE *, unsigned int);
int checksum_double_byte(FILE *, unsigned int);
int checksum_word(FILE *, unsigned int);
FILE *open_file(char *, unsigned int);
void print_bin(FILE *, unsigned int);

int main(int argc, char** argv) {
    unsigned int checksum;
    unsigned int filesize = CGB_BIOS_SIZE;
    FILE *bin;
    if (argc < 2) {
        printf("Binary file must be passed on the command line\n");
        return -1;
    }

    bin = open_file(argv[1], filesize);
    fseek(bin, 0, SEEK_END);
    filesize = ftell(bin);
    rewind(bin);

    print_bin(bin, filesize);
    rewind(bin);
    
    printf("\n");
    printf("Calculating file checksum with different chunk sizes\n");
    checksum = checksum_word(bin, filesize);
    printf("\tWords       (%2lu-bit %4d words)  = %#11x\n", sizeof(uint32_t)*8, filesize >> 2, checksum);
    rewind(bin);
 
    checksum = checksum_double_byte(bin, filesize);
    printf("\tHalf-words  (%2lu-bit %4d hwords) = %#11x\n", sizeof(uint16_t)*8, filesize >> 1, checksum);

    rewind(bin);
    checksum = checksum_single_byte(bin, filesize);
    printf("\tBytes       (%2lu-bit %4d bytes)  = %#11x\n", sizeof(uint8_t)*8, filesize, checksum);

    fclose(bin);
    return 0;
}

FILE* open_file(char * filename, unsigned int filesize) {
    FILE * file = fopen(filename, "rb");
    if (!file) {
        printf("File '%s' does not exist\n", filename);
        exit(-1);
    } 
    return file;
}

int checksum_single_byte(FILE *bin, unsigned int filesize) {
    int checksum = 0;
    uint8_t byte = 0;
    unsigned char buffer[filesize];
    int i = 0;

    fread(&buffer, sizeof(uint8_t), filesize, bin);
    for (i = 0; i < filesize; i++) {
        byte = buffer[i];
        checksum += byte;
    }

    return checksum;
}

int checksum_double_byte(FILE *bin, unsigned int filesize) {
    int checksum = 0;
    int num_hwords = filesize >> 1;
    uint16_t hword = 0;
    uint16_t buffer[num_hwords];
    int i = 0;

    fread(&buffer, sizeof(uint16_t), num_hwords, bin);
    for (i = 0; i < num_hwords; i++) {
        hword = buffer[i];
        checksum += hword;

    }

    return checksum;
}

int checksum_word(FILE *bin, unsigned int filesize) {
    int checksum = 0;
    int num_words = filesize >> 2;
    uint32_t word = 0;
    uint32_t buffer[num_words];
    int i = 0;

    fread(&buffer, sizeof(uint32_t), num_words, bin);
    for (i = 0; i < num_words; i++) {
        word = buffer[i];
        checksum += word;
    }

    return checksum;
}

void print_bin(FILE *bin, unsigned int filesize) {
    uint8_t byte = 0;
    unsigned char buffer[filesize];
    int i = 0;

    fread(&buffer, sizeof(uint8_t), filesize, bin);
    printf("Binary file contents:");
    for (i = 0; i < filesize; i++) {
        if (i % PRINT_BYTES_PER_COL == 0) {
            printf("\n");
            printf("0x%03X |", i);
        }
        byte = buffer[i];
        printf("%3X ", byte);
    }
    printf("\n");
}
