#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifdef PRELOAD_HAS_BLKID
#include <blkid/blkid.h>
#endif

typedef struct bd_stats {
  long unsigned rd_ios;
  long unsigned rd_merges;
  long unsigned rd_secs;
  long unsigned rd_ticks;

  long unsigned wr_ios;
  long unsigned wr_merges;
  long unsigned wr_secs;
  long unsigned wr_ticks;

  unsigned in_flight;
  unsigned io_ticks;
  unsigned time_queue;
} bd_stats_t;

int get_sysfs_path_for_bd(const char *dev_name, char *sys_path_buf,
                          int sys_path_buf_len) {
  // printf("Device: %s\n", dev_name);

  int devname_len = strlen(dev_name);
  const int devname_len_max = 64;

  if (devname_len >= devname_len_max) {
    return -1;
  }

  char part_name[devname_len_max];
  sscanf(dev_name, "/dev/%s", part_name);

  snprintf(sys_path_buf, sys_path_buf_len, "/sys/class/block/%s/stat",
           part_name);

  return 0;
}

int get_stats(const char *dev_name, bd_stats_t &bds) {
  if (dev_name == NULL) {
    return -1;
  }

  char sys_path_buf[1024];
  int rv = get_sysfs_path_for_bd(dev_name, sys_path_buf, 1024);

  if (rv < 0) {
    return -1;
  }

  FILE *sys_fp;
  if ((sys_fp = fopen(sys_path_buf, "r")) == NULL) {
    return -1;
  }

  int num_scanned = fscanf(sys_fp, "%lu %lu %lu %lu %lu %lu %lu %lu %u %u %u",
      &bds.rd_ios, &bds.rd_merges, &bds.rd_secs, &bds.rd_ticks,
      &bds.wr_ios, &bds.wr_merges, &bds.wr_secs, &bds.wr_ticks,
      &bds.in_flight, &bds.io_ticks, &bds.time_queue);

  fclose(sys_fp);

  if (num_scanned != 11) {
    /* Extended statistics not supported */
    return -1;
  }

  return 0;
}

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

  bd_stats_t cur_stats, prev_stats;
  get_stats(name, prev_stats);

  while (true) {
    get_stats(name, cur_stats);

    long unsigned sec_wr = cur_stats.wr_secs - prev_stats.wr_secs;

#define TO_MB(bytes) bytes / (1024.0 * 1024.0)

    printf("\rWrite Sectors: %lusec/s, %.1f MB/s, in-flight: %u\n", sec_wr, TO_MB(sec_wr * 512));

    prev_stats = cur_stats;
    sleep(1);
  }

#endif

  return 0;
}
