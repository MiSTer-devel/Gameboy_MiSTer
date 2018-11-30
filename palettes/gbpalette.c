#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

// GBP file format is simple. There are 4 palette colors using 6 bit
// rgb, starting from lightest ending in darkest for a total of 9 bytes.
// The last several bytes are 0, reserved for future use.

void gbp_bitcopy(__uint128_t *dest, uint32_t dest_from, uint32_t source,
	uint32_t source_from, uint32_t len)
{
	for (uint32_t x = 0; x < len; x++) {
		uint8_t bit = (uint8_t) ((source & (1 << (source_from - x))) ? 1 : 0);
		*dest |= (__uint128_t) bit << (dest_from - x);
	}
}

uint32_t gbp_get_color(void)
{
	char buffer[100];

	printf ("Red   (0-255): ");
	fgets(buffer, sizeof(buffer), stdin);
	uint8_t red = (uint8_t) strtol(buffer, NULL, 10);

	printf ("Green (0-255): ");
	fgets(buffer, sizeof(buffer), stdin);
	uint8_t green = (uint8_t) strtol(buffer, NULL, 10);

	printf ("Blue  (0-255): ");
	fgets(buffer, sizeof(buffer), stdin);
	uint8_t blue = (uint8_t) strtol(buffer, NULL, 10);

	return (uint32_t) (((red >> 2) << 12) | ((green >> 2) << 6) | (blue >> 2));
}

int main (int argc, char **argv)
{
	__uint128_t palette = 0;

	if (argc < 1) {
		printf("Usage: %s <filename>\n", argv[0]);
		return 1;
	}

	FILE *f = fopen(argv[1], "w");
	if (!f) {
		printf("Unable to open %s for writing.\n", argv[1]);
		return 1;
	}

	printf("Color 1:\n");
	uint32_t color1 = gbp_get_color();

	printf("Color 2:\n");
	uint32_t color2 = gbp_get_color();

	printf("Color 3:\n");
	uint32_t color3 = gbp_get_color();

	printf("Color 4:\n");
	uint32_t color4 = gbp_get_color();

	gbp_bitcopy(&palette, 127, color1, 17, 18);
	gbp_bitcopy(&palette, 109, color2, 17, 18);
	gbp_bitcopy(&palette, 91, color3, 17, 18);
	gbp_bitcopy(&palette, 73, color4, 17, 18);

	uint8_t *pal = (uint8_t *) &palette;
	for (uint32_t x = 0; x < 16; x++) {
		fwrite(&pal[15 - x], 1, 1, f);
	}

	fclose(f);

	return 0;
}