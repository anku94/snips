#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef PRELOAD_HAS_BLKID
#include <blkid/blkid.h>
#endif

int main(int argc, char *argv[]) {
  if (argc < 2) {
    printf("Usage: %s <path>\n", argv[0]);
    return 0;
  }

  const char *path = argv[1];
  struct stat s;

  printf("Matching path %s to a device\n", path);

  if (lstat(path, &s)) {
    printf("Unable to stat\n");
    return EXIT_FAILURE;
  }

#ifdef PRELOAD_HAS_BLKID

  dev_t dev_id = s.st_dev;

  char *name = blkid_devno_to_devname(dev_id);
  printf("Device ID: %zu, device name: %s\n", dev_id, name);

#endif

  return 0;
}
