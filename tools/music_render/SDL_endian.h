#include "SDL_types.h"
#define SDL_SwapLE16(x) (x)
#define SDL_SwapLE32(x) (x)
#define SDL_SwapBE16(x) __builtin_bswap16(x)
