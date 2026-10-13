#include <stdio.h>
#include <stdlib.h>
#include "opentyr.h"
#include "lds_play.h"
#include "opl.h"
int audioSampleRate = 44100;
int main(int argc, char **argv) {
  FILE *f = fopen(argv[1], "rb"); fseek(f, 0, SEEK_END); long len = ftell(f); fseek(f, 0, SEEK_SET);
  unsigned char *buf = malloc(len); fread(buf, 1, len, f); fclose(f);
  int count = buf[0] | buf[1] << 8;
  const char *outdir = argv[2];
  int maxsec = argc > 3 ? atoi(argv[3]) : 240;
  for (int s = 0; s < count; ++s) {
    long pos = buf[2+s*4] | buf[3+s*4]<<8 | buf[4+s*4]<<16 | (long)buf[5+s*4]<<24;
    long end = (s+1 < count) ? (buf[2+(s+1)*4] | buf[3+(s+1)*4]<<8 | buf[4+(s+1)*4]<<16 | (long)buf[5+(s+1)*4]<<24) : len;
    opl_init();
    if (!lds_load(buf + pos, end - pos)) { fprintf(stderr, "song %d failed\n", s); continue; }
    char name[512]; snprintf(name, sizeof name, "%s/song%02d.raw", outdir, s);
    FILE *o = fopen(name, "wb");
    const int rate2 = 139; int per = 2 * (audioSampleRate / rate2), perf = 2 * (audioSampleRate % rate2);
    int frac = 0; long total = 0; Sint16 tmp[2048];
    int looped = 0;
    while (total < (long)maxsec * audioSampleRate) {
      if (!lds_update() && (!playing || songlooped)) { looped = songlooped; break; }
      int n = per; frac += perf; if (frac >= rate2) { n++; frac -= rate2; }
      while (n > 0) { int c = n > 2048 ? 2048 : n; opl_update(tmp, c);
        for (int i = 0; i < c; ++i) { int v = tmp[i]; tmp[i] = v > 32767 ? 32767 : v < -32768 ? -32768 : v; }
        fwrite(tmp, 2, c, o); n -= c; total += c; }
    }
    fclose(o);
    printf("song %d: %.1fs looped=%d playing=%d\n", s, total / (double)audioSampleRate, looped, playing);
  }
  return 0;
}
