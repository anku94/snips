#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <thread>

void fserver() {
  fprintf(stderr, "Running server thread\n");

  int res = shm_open("myshm", O_RDWR | O_CREAT, S_IRWXU);
  if (res < 0) {
    perror("Server error: ");
    return;
  }

  res = write(res, "hello", 5);
  fprintf(stderr, "Written %d bytes\n", res);

  fprintf(stderr, "Server sleeping...\n");
  sleep(5);

  shm_unlink("myshm");
  if (res < 0) {
    perror("Server error: ");
    return;
  }
}
void fclient() {
  fprintf(stderr, "Running client thread\n");

  sleep(1);

  int res = shm_open("myshm", O_RDWR, S_IRWXU);

  if (res < 0) {
    perror("Client error: ");
    return;
  }

  char buf[1024];
  res = read(res, buf, 1024);
  if (res < 0) {
    perror("Client error: ");
    return;
  }

  buf[res] = '\0';
  printf("Read %d bytes: %s\n", res, buf);

  res = shm_unlink("myshm");
  if (res < 0) {
    perror("Client error: ");
    return;
  }
}

void mserver() {
  fprintf(stderr, "Running server thread\n");

  int res = shm_open("myshm", O_RDWR | O_CREAT, S_IRWXU);
  if (res < 0) {
    perror("Server error: ");
    return;
  }

  ftruncate(res, 1024);
  char *shmaddr =
      (char *)mmap(NULL, 1024, PROT_READ | PROT_WRITE, MAP_SHARED, res, 0);

  strncpy(shmaddr, "hello", 5);
  while (shmaddr[5] != 'w')
    ;

  fprintf(stderr, "Server shmcontent: %s\n", &shmaddr[5]);

  shm_unlink("myshm");
  if (res < 0) {
    perror("Server error: ");
    return;
  }
}
void mclient() {
  fprintf(stderr, "Running client thread\n");

  sleep(1);

  int res = shm_open("myshm", O_RDWR, S_IRWXU);

  if (res < 0) {
    perror("Client error: ");
    return;
  }

  char *shmaddr =
      (char *)mmap(NULL, 1024, PROT_READ | PROT_WRITE, MAP_SHARED, res, 0);

  while (shmaddr[0] != 'h')
    ;

  fprintf(stderr, "Client shmcontent: %s\n", shmaddr);

  strncpy(&shmaddr[5], "world", 5);

  res = shm_unlink("myshm");
  if (res < 0) {
    perror("Client error: ");
    return;
  }

  munmap(shmaddr, 1024);
}

int main(int argc, char *argv[]) {
  if (argc > 1 && argv[1][0] == 's') {
    std::thread server_t(mserver);
    server_t.join();
  } else if (argc > 1 && argv[1][0] == 'c') {
    std::thread client_t(mclient);
    client_t.join();
  } else {
    std::thread server_t(fserver);
    std::thread client_t(fclient);
    server_t.join();
    client_t.join();
  }
  return 0;
}
