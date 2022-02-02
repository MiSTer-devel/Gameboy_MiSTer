#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// GBP file format is simple. There are 4 palette colors using 8 bit
// rgb, starting from lightest ending in darkest for a total of 12 bytes.
// The last several bytes are 0, reserved for future use.


void gbp_get_color(uint8_t *palette, uint32_t index)
{
	char buffer[100];

	printf ("Red   (0-255): ");
	fgets(buffer, sizeof(buffer), stdin);
	palette[index] = (uint8_t) strtol(buffer, NULL, 10);

	printf ("Green (0-255): ");
	fgets(buffer, sizeof(buffer), stdin);
	palette[index + 1] = (uint8_t) strtol(buffer, NULL, 10);

	printf ("Blue  (0-255): ");
	fgets(buffer, sizeof(buffer), stdin);
	palette[index + 2] = (uint8_t) strtol(buffer, NULL, 10);
}

int main (int argc, char **argv)
{
	uint8_t palette[16];
	memset(palette, 0, sizeof(palette));

	if (argc < 2) {
		printf("Usage: %s <filename>\n", argv[0]);
		return 1;
	}

	FILE *f = fopen(argv[1], "w");
	if (!f) {
		printf("Unable to open %s for writing.\n", argv[1]);
		return 1;
	}

	printf("Color 1:\n");
	gbp_get_color(palette, 0);

	printf("Color 2:\n");
	gbp_get_color(palette, 3);

	printf("Color 3:\n");
	gbp_get_color(palette, 6);

	printf("Color 4:\n");
	gbp_get_color(palette, 9);

	fwrite(palette, 1, 16, f);

	fclose(f);

	return 0;
}