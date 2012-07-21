/*
 * FS-test (writer)
 *
 * (C) Copyright 2010-2012 TOSHIBA CORPORATION
 * 
 * This source code is licensed under the GNU General Public License,
 * Version 2.  See the file COPYING for more details.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <fcntl.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/syscall.h>
#include <linux/reboot.h>

#include "config.h"
#include "common.h"

/*
 * Shared objects
 */
int                *ft_state;
int                 progress;
char                s_char;
static char        *default_path = DEFAULT_PATH;

/*
 * main thread -> 
 *   (thread1 for file creation * N)
 */
int main(int argc, char *argv[])
{
        int                i,opt;
        int                fd;
        int                numproc;
        int                rb_ms;
        int                type;
        int                count;
        long               fsize;
        long               wsize;
        int                gran;
        long               fnum;
        pid_t             *pid;
        pthread_t         *fthr;
        char               pfname[1024];
        char               parms[1024];
        char              *serv_ipstr;
        struct f_thr_args *ft_args;

        // set default val
        type        = TEST_TYPE_CREATE;
        count       = 0;
        numproc     = NUM_PROC;
        fnum        = NUM_FILE;
        gran        = GRAN_DEFAULT;
        fsize       = FSIZE_DEFAULT;
        wsize       = FSIZE_DEFAULT;
        s_char      = 'A';
        rb_ms       = 0;
        progress    = 0;
        serv_ipstr  = NULL;
  
        while ((opt = getopt(argc, argv, "n:c:t:f:s:r:i:w:g:a:")) != -1) {
                switch (opt) {
                case 'a': // TEST count (for info)
                        count = atoi(optarg);
                        if (count < 0){
                                fprintf(stderr, "WARNING: COUNT < 0\n");
                                count = 0;
                        }
                        break;
                case 't': // TEST type
                        type = atoi(optarg);
                        if (type < 0 || type > 3){
                                fprintf(stderr, "WARNING: TEST TYPE (0-3)\n");
                                type = TEST_TYPE_CREATE;
                        }
                        break;
                case 'g': // granularity
                        gran = atoi(optarg);
                        if (gran < 0){
                                fprintf(stderr, "WARNING: GRANULARITY too small (g<0)\n");
                                gran = GRAN_DEFAULT;
                        }
                        break;
                case 'c': // start char
                        s_char = optarg[0];
                        if (s_char < 'A' || s_char > 'X'){
                                s_char = 'A';
                        }
                        break;
                case 'n': // number of proc or thread
                        numproc = atoi(optarg);
                        if (numproc <= 0){
                                fprintf(stderr, 
                                        "WARNING: Num of proc/thread: %d\n", 
                                        numproc);
                                numproc = 1;
                                fprintf(stderr, "CHANGED: numproc -> %d\n",
                                        numproc);
                        }
                        break;
                case 'i': // net log
                        serv_ipstr = optarg;
                        if (serv_ipstr == NULL){
                                fprintf(stderr, "Server IP ADDR??\n");
                                exit(EXIT_FAILURE);
                        }
                        break;
                case 's': // FILE size
                        fsize = atoi(optarg);
                        fsize = fsize * 1024; // change to KB
                        if (fsize < 8192){
                                fprintf(stderr, 
                                        "BUF size too small! < 8K: %ld\n",
                                        fsize);
                                fsize = FSIZE_DEFAULT;
                        }
                        break;
                case 'f': // Number of FILEs
                        fnum = atoi(optarg);
                        if (fnum < 1){
                                fprintf(stderr, "Fnum  too small! < 8K: %ld\n",
                                        fnum);
                                fnum = FSIZE_DEFAULT;
                        }
                        break;
                case 'r': // seconds to reboot
                        rb_ms = atoi(optarg);
                        if (rb_ms < 0){
                                fprintf(stderr, "RBMS too small! < 8K: %d\n",
                                        rb_ms);
                                rb_ms = 0;
                        }
                        break;
                case 'w': // write size
                        break;
                default:
                        fprintf(stderr, 
                                "Usage: %s [-n num_thr] [-f num_file]\n", 
                                argv[0]);
                        fprintf(stderr, 
                                "          [-s file_size] [-t test_type]\n");
                        exit(EXIT_SUCCESS);
                }
        }
        
        /* save parameters */
        sprintf(pfname, "%s/params.txt", default_path);
        sprintf(parms, "%d\t%d\t%ld\t%ld\t%d\t%c\n", 
                type, numproc, fsize, fnum, gran, s_char);
        fd = open(pfname, 
                  O_CREAT|O_RDWR|O_SYNC|O_TRUNC, S_IRWXU | S_IRWXG | S_IRWXO);
        if (fd == -1){
                perror(pfname);
                exit(EXIT_FAILURE);
        }
        write(fd, parms, strlen(parms));
        close(fd);

        fprintf(stderr, "NUM thread      : %d\n", numproc);
        fprintf(stderr, "Number of Files : %ld\n", fnum);
        fprintf(stderr, "FILE SIZE       : %ld\n", fsize);
        fprintf(stderr, "GRANULARITY     : %d\n", gran);
        
        bar_init(numproc);
        
        ft_args    = (struct f_thr_args *)malloc(sizeof(struct f_thr_args) 
                                                 * numproc);
        pid        = (pid_t *)malloc(sizeof(pid_t) * numproc);
        // File I/O threads
        fthr       = (pthread_t *)malloc(sizeof(pthread_t) * numproc);
        // state of threads
        ft_state   = (int *)malloc(sizeof(int) * numproc);
        
        for(i=0; i<numproc; i++){
                /* set args */
                ft_args[i].id      = i + 1;
                ft_args[i].id_max  = numproc;
                ft_args[i].type    = type;
                ft_args[i].count   = count;
                ft_args[i].fsize   = fsize;
                ft_args[i].wsize   = wsize;
                ft_args[i].gran    = gran;
                ft_args[i].fnum    = fnum;
                ft_args[i].path    = default_path;
                ft_args[i].serv_ip = serv_ipstr;
                ft_args[i].port    = COMM_PORT;
                ft_state[i]        = STATE_INIT;
                
                /* 
                 * Create File I/O threads
                 */
                if(pthread_create(&fthr[i], NULL, fio_thread, &ft_args[i])){
                        fprintf(stderr,"File I/O thread create: %d\n", __LINE__);
                        exit(EXIT_FAILURE);
                }
        }
        
        /*
         * Check if the program needs to reboot
         */
        if(rb_ms != 0){
                if (type != 0){
                        while(!progress){
                                sleep(1);
                        }
                }
                usleep(rb_ms);
                // 0x01010101 is only available for modified kernel
                syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2, 
                        0x01010101, NULL);
        }
        
        // Only Master thread can be reached here
        for(i=0; i<numproc; i++){
                pthread_join(fthr[i], NULL);
        }
        
        return 0;
}
