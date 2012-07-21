/*
 * sync
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <pthread.h>
#include <limits.h>
#include <unistd.h>
#include <semaphore.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/types.h>

#include "config.h"
#include "common.h"

pthread_barrier_t barrier;

void bar_init(int num) /* barrier initialize */
{
  fprintf(stderr, "BAR_INIT(%d) ", num);
  pthread_barrier_init(&barrier, NULL, num);
}

void bar_wait(int id)
{
  pthread_barrier_wait(&barrier);
}
