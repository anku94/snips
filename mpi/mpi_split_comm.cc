#include <mpi.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
  MPI_Init(&argc, &argv);
  int rank, shmrank;

  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  MPI_Comm shmcomm;
  MPI_Comm_split_type(MPI_COMM_WORLD, MPI_COMM_TYPE_SHARED, 0, MPI_INFO_NULL, &shmcomm);
  MPI_Comm_rank(shmcomm, &shmrank);

  printf("%d,%d\n", rank, shmrank);

  MPI_Finalize();
  return 0;
}
