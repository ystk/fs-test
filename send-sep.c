/*
 * FS-test (send-sep.c)
 * Send a separator string to log server
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
int                 progress;
char                s_char;

/*
 * main thread -> 
 *   (thread1 for file creation * N)
 */
int main(int argc, char *argv[])
{
        int                 opt;
        long                fsize;
        long                wsize;
        int                 gran;
        char               *serv_ipstr;
        char               *io_name;
        int                 soc;
        int                 len;
        char                str[256];
        struct sockaddr_in *serv_addr;

        // set default val
        gran        = GRAN_DEFAULT;
        fsize       = FSIZE_DEFAULT;
        wsize       = FSIZE_DEFAULT;
        serv_ipstr  = NULL;
        io_name     = NULL;
  
        while ((opt = getopt(argc, argv, "s:i:g:z:")) != -1) {
                switch (opt) {
                case 'g': // granularity
                        gran = atoi(optarg);
                        if (gran < 0){
                                fprintf(stderr, "WARNING: GRANULARITY too small (g<0)\n");
                                gran = GRAN_DEFAULT;
                        }
                        break;
                case 'i': // net log
                        serv_ipstr = optarg;
			printf("fsk %s\n",serv_ipstr);
                        if (serv_ipstr == NULL){
                                fprintf(stderr, "Server IP ADDR??\n");
                                exit(EXIT_FAILURE);
                        }
                        break;
                case 'z': // iosched
                        io_name = optarg;
			//io_name = "noop";
			printf("fsk %s\n",io_name);
                        if (io_name == NULL){
                                fprintf(stderr, "IOsched??\n");
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
        fprintf(stderr, "FILE SIZE       : %ld\n", fsize);
        fprintf(stderr, "GRANULARITY     : %d\n", gran);
        fprintf(stderr, "IO SHCED        : %s\n", io_name);

        /* prepare socket */
        serv_addr = (struct sockaddr_in *)malloc(sizeof(struct sockaddr_in));
        memset(serv_addr, 0, sizeof(struct sockaddr_in));
        fprintf(stderr, "IP ADDR:%s\n", serv_ipstr);
        if (inet_aton(serv_ipstr, &serv_addr->sin_addr) == 0){
                fprintf(stderr, "Server IP ADDR??\n");
                exit(EXIT_FAILURE);
        };
        serv_addr->sin_port   = htons(COMM_PORT);
        serv_addr->sin_family = AF_INET;
        soc = socket(AF_INET, SOCK_DGRAM, 0);

        // prepare data
        gran = 1 << gran;
        len  = fsize / gran;
        fprintf(stderr, "WRITE SIZE     : %d\n", len);
        sprintf((char *)&str, "8888\t%d\t%lu\t%s\n", len, fsize, io_name);
        len  = strlen(str);
        sendto(soc, &str, len, 0, serv_addr, sizeof(struct sockaddr_in));
        
        return 0;
}
