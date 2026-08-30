// Dumps the original LCS RNG stream so the GDScript port can be proven bit-exact.
// The algorithm itself is extracted verbatim from src/compat.cpp at build time.
//
// Usage: rng_dump <seed> <count>
//   Emits <count> lines of: r_num  LCSrandom(2) LCSrandom(3) ... for a fixed ladder
//   of moduli, one draw each, so both the raw stream and the modulo reduction are
//   compared. Deterministic: no clock, no entropy.
#include <cstdio>
#include <cstdlib>

#define RNG_SIZE 4
unsigned long seed[RNG_SIZE];
void initMainRNG();

#include "rng_extracted.inc"

// Deterministic replacement for the entropy-based seeding in compat.cpp: the
// caller supplies the LCG seed, everything after it is the original code path.
static unsigned long g_lcg_seed = 0;
void initMainRNG()
{
   seed[0] = g_lcg_seed;
   for (int i = RNG_SIZE - 1; i >= 0; i--) seed[i] = r_num2();
}

// The moduli the game actually uses most; covers small switches and large rolls.
static const long MODULI[] = {2, 3, 4, 5, 6, 10, 20, 35, 100, 1000, 65536, 1000000};
static const int NMOD = sizeof(MODULI) / sizeof(MODULI[0]);

int main(int argc, char *argv[])
{
   if (argc < 3) { fprintf(stderr, "usage: rng_dump <seed> <count>\n"); return 2; }
   g_lcg_seed = strtoul(argv[1], NULL, 10);
   long count = strtol(argv[2], NULL, 10);
   initMainRNG();
   for (long i = 0; i < count; i++)
   {
      printf("%lu", r_num());
      for (int m = 0; m < NMOD; m++) printf(" %ld", LCSrandom(MODULI[m]));
      printf("\n");
   }
   return 0;
}
