#include <fcntl.h>
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CTRL_PATH_TEMPLATE "/tmp/perf.ctrlfd.%d"

// Function to enable performance monitoring
int perf_enable(int rank) {
  char path[256];
  snprintf(path, sizeof(path), CTRL_PATH_TEMPLATE, rank);

  fprintf(stderr, "Opening: %s\n", path);

  int fd = creat(path, 0666);
  if (fd == -1) {
    perror("open");
    return -1;
  }

  char enable_cmd[] = "enable";
  if (write(fd, enable_cmd, strlen(enable_cmd)) == -1) {
    perror("write");
    close(fd);
    return -1;
  }

  close(fd);
  return 0;
}

// Function to disable performance monitoring
int perf_disable(int rank) {
  char path[256];
  snprintf(path, sizeof(path), CTRL_PATH_TEMPLATE, rank);


  int fd = open(path, O_WRONLY);
  if (fd == -1) {
    perror("open");
    return -1;
  }

  char disable_cmd[] = "disable";
  if (write(fd, disable_cmd, strlen(disable_cmd)) == -1) {
    perror("write");
    close(fd);
    return -1;
  }

  close(fd);
  return 0;
}

// Function to simulate a small sleep (50 microseconds)
void small_sleep() { usleep(50); }

// Function to simulate a big sleep (200 microseconds)
void big_sleep() { usleep(200); }

int main(int argc, char **argv) {
  MPI_Init(&argc, &argv);

  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  for (int i = 0; i < 10; i++) {
    // Enable performance monitoring before small_sleep
    if (perf_enable(rank) == -1) {
      fprintf(stderr, "Failed to enable performance monitoring for rank %d\n",
              rank);
      MPI_Abort(MPI_COMM_WORLD, 1);
    }

    // Perform small sleep
    small_sleep();

    // Disable performance monitoring after small_sleep
    if (perf_disable(rank) == -1) {
      fprintf(stderr, "Failed to disable performance monitoring for rank %d\n",
              rank);
      MPI_Abort(MPI_COMM_WORLD, 1);
    }

    // Perform big sleep
    big_sleep();
  }

  MPI_Finalize();
  return 0;
}
