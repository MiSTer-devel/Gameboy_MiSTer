#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define BIOS_SIZE 2304
#define PRINT_BYTES_PER_COL 16

int checksum_single_byte(FILE *);
int checksum_double_byte(FILE *);
int checksum_word(FILE *bin);
FILE * open_and_check_file(char * filename);
void print_bin(FILE *bin);

int main(int argc, char** argv) {
    unsigned int checksum;
    FILE *bin;
    if (argc < 2) {
        printf("Binary file must be passed on the command line\n");
        return -1;
    }

    bin = open_and_check_file(argv[1]);
    print_bin(bin);
    rewind(bin);
    
    printf("\n");
    printf("Reading from file with different chunk sizes\n");
    //checksum = checksum_word(bin);
    //printf("\tChecksum reading words (%d words) = 0x%X\n", BIOS_SIZE >> 2, checksum);
    //rewind(bin);
 
    checksum = checksum_double_byte(bin);
    printf("\tChecksum reading half-words (%d hwords) = 0x%X\n", BIOS_SIZE >> 1, checksum);

    rewind(bin);
    checksum = checksum_single_byte(bin);
    printf("\tChecksum (%d bytes) = 0x%X\n", BIOS_SIZE, checksum);

    fclose(bin);
    return 0;
}

FILE* open_and_check_file(char * filename) {
    int size = 0;
    FILE * file = fopen(filename, "rb");
    fseek(file, 0, SEEK_END);
    size = ftell(file);
    if (size != BIOS_SIZE) {
        printf("Error: Provided file is not the correct size (expected %d but found %d)\n", BIOS_SIZE, size);   
        fclose(file);
        exit(-1);
    }
    rewind(file);
    return file;
}

int checksum_single_byte(FILE *bin) {
    int checksum = 0;
    uint8_t byte = 0;
    unsigned char buffer[BIOS_SIZE];
    int i = 0;

    fread(&buffer, sizeof(uint8_t), BIOS_SIZE, bin);
    for (i = 0; i < BIOS_SIZE; i++) {
        byte = buffer[i];
        checksum += byte;
    }

    return checksum;
}

int checksum_double_byte(FILE *bin) {
    int checksum = 0;
    int num_hwords = BIOS_SIZE >> 1;
    uint16_t hword = 0;
    uint16_t buffer[num_hwords];
    int i = 0;

    fread(&buffer, sizeof(uint16_t), num_hwords, bin);
    for (i = 0; i < num_hwords; i++) {
        hword = buffer[i];
        checksum += (hword & 0xFF) + ((hword & 0xFF00) >> 8);

    }

    return checksum;
}

int checksum_word(FILE *bin) {
    int checksum = 0;
    int num_words = BIOS_SIZE >> 2;
    uint32_t word = 0;
    uint32_t buffer[num_words];
    int i = 0;

    fread(&buffer, sizeof(uint32_t), num_words, bin);
    for (i = 0; i < num_words; i++) {
        word = buffer[i];
        checksum += (word >> 24) + ((word >> 16) & 0xFF) + ((word >> 8) & 0xFF) + (word & 0xFF);
    }

    return checksum;
}

void print_bin(FILE *bin) {
    uint8_t byte = 0;
    unsigned char buffer[BIOS_SIZE];
    int i = 0;

    fread(&buffer, sizeof(uint8_t), BIOS_SIZE, bin);
    printf("Binary file contents:");
    for (i = 0; i < BIOS_SIZE; i++) {
        if (i % PRINT_BYTES_PER_COL == 0) {
            printf("\n");
            printf("0x%03X |", i);
        }
        byte = buffer[i];
        printf("%3X ", byte);
    }
    printf("\n");
}
