/*
 * common.h
 */
#ifndef __COMMON_H

#include <pthread.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
/*
 * Process/ Thread States
 */
#define STATE_INIT            0
#define STATE_RUNNING         1
#define STATE_WAIT_BARRIER    2
#define STATE_FINISHED        3

#define TEST_TYPE_CREATE      0
#define TEST_TYPE_APPEND      1
#define TEST_TYPE_OVERWRITE   2
#define TEST_TYPE_APPENDCLOSE 3

struct f_thr_args {
        int    id;
        int    id_max;
        int    type;  // test type
        int    count; // test count
        long   fsize; // File size
        long   wsize; // Write size
        int    gran;  // Granularity
        long   fnum;  // Number of files
        char  *path;
        char  *serv_ip;
        int    port;
        int    socket;
        struct sockaddr_in *serv_addr;
};

u_int64_t  rdtsc(void);
void       bar_init(int num);
void       bar_wait(int id);
void      *fio_thread(void *fio_args);

/*
 * Shared objects
 */
extern int         *ft_state;
extern int          progress;
extern char         s_char;

extern int          use_net;
struct sockaddr_in  serv_addr;

#endif  /* __COMMON_H */
