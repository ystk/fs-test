/*
 * FS test (log-server.c)
 * Receive the progress of writer threads and record it to file
 *
 * (C) Copyright 2010-2012 TOSHIBA CORPORATION
 * 
 * This source code is licensed under the GNU General Public License,
 * Version 2.  See the file COPYING for more details.
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "config.h"

#define NUM_RING_BUF  3
#define NUM_BUF       2048
#define BUF_LEN       1024
#define FILE_PATH     "./log/log.txt"

static int  net_ready  = 0;
static int  w_progress = -1;
static char rbuf[NUM_RING_BUF][NUM_BUF][BUF_LEN];

static pthread_mutex_t *log_mutex;      /* mutex for log buffer            */

struct net_arg_struct {
        int id;
};

struct io_arg_struct {
        int id;
};

struct net_arg_struct net_args;
struct io_arg_struct  io_args;

void net_recv_write(int soc, struct sockaddr_in *sockaddr)
{
        ssize_t  num_recv;
        FILE    *fd;
        char     rbufp[BUF_LEN];
        char     newfile[256];
	char	*tok;
	char	*ios;

        fd = fopen(FILE_PATH, "w");

        while(1){
                num_recv = recvfrom(soc, rbufp, BUF_LEN, 0, NULL, NULL);
                if(num_recv == -1) {
                        perror("recv");
                        close(soc);
                        exit(EXIT_FAILURE);
                }
                fprintf(fd, "%s", rbufp);
		if (!strncmp(rbufp, "88", 2)){
			fflush(fd);
			fclose(fd);
			tok = strtok(rbufp, "\t"); // 8888
			tok = strtok(NULL, "\t"); // len
			ios = strtok(NULL, "\t\n"); // fsize
			ios = strtok(NULL, "\t\n"); // iosched
			strcpy(newfile, "log-");
			strcat(newfile, ios);
			strcat(newfile, "-");
			strcat(newfile, tok);
			strcat(newfile, ".txt");
			rename(FILE_PATH, newfile);
			
        		fd = fopen(FILE_PATH, "w");
		}
        }

        /* NEVER REACHD */
        fclose(fd);
}

void *net_thread(void *net_args)
{
        int                    recv_soc;
        int                    recv_port = COMM_PORT;
        int                    stat;
        struct sockaddr_in     recv_socaddr;
        // struct net_arg_struct *na = (struct net_arg_struct *)net_args;

        fprintf(stderr,"Starting NET thread: %d\n", __LINE__);
        
        /* 
         * Initialize socket
         */
        memset(&recv_socaddr, 0, sizeof(struct sockaddr_in));
        recv_socaddr.sin_port        = htons(recv_port);
        recv_socaddr.sin_family      = AF_INET;
        recv_socaddr.sin_addr.s_addr = htonl(INADDR_ANY);
        
        recv_soc = socket(AF_INET, SOCK_DGRAM, 0);
        stat     = bind(recv_soc, (struct sockaddr_in *) &recv_socaddr,
                        sizeof(struct sockaddr_in));
        
        net_recv_write(recv_soc, &recv_socaddr);
        /* NEVER REACHD */
        return 0;
}

void net_recv(int soc, struct sockaddr_in *sockaddr, struct net_arg_struct *na)
{
        int      i, j;
        ssize_t  num_recv;
        char    *rbufp;
        
        for (i = 0; i< NUM_RING_BUF; i++){
                if (w_progress == i){
                        fprintf(stderr,"Buffer overflow: %d\n", __LINE__);
                }
                
                pthread_mutex_lock(&log_mutex[i]);
                net_ready = 1;
                
                for(j = 0; j<NUM_BUF; j++){
                        rbufp = rbuf[i][j];
                        num_recv = recvfrom(soc, rbufp, BUF_LEN, 0, NULL, NULL);
                        if(num_recv == -1) {
                                perror("recv");
                                close(soc);
                                exit(EXIT_FAILURE);
                        }
                        fprintf(stderr,"RECV: %s", rbufp);
                }
                pthread_mutex_unlock(&log_mutex[i]);
        }
        if (w_progress == -1){
                fprintf(stderr,"File I/O too slow\n");
                exit(EXIT_FAILURE);
        }
}


void *fio_thread(void *io_args)
{
        int i, j;
        char *rbufp;
        FILE *fd;
        // struct io_arg_struct *ia = (struct io_arg_struct *)io_args;
  
        fprintf(stderr,"Starting LOG thread: %d\n", __LINE__);

        fd = fopen(FILE_PATH, "w");

        /* 
         * wait for net thread
         */
        while(net_ready != 1){
                sched_yield();
        }
        
        fprintf(stderr,"Starting logging: %d\n", __LINE__);
        while(1){
                // log_out(fd, ia);
                for (i = 0; i<NUM_RING_BUF; i++){
                        pthread_mutex_lock(&log_mutex[i]);
                        w_progress = i;
                        for (j = 0; j<NUM_BUF; j++){
                                rbufp = rbuf[i][j];
                                // fprintf(stderr, "%s", rbufp);
                                fprintf(fd, "%s", rbufp);
                        }
                        pthread_mutex_unlock(&log_mutex[i]);
                }
        }
        /* NEVER REACHD */
}

int main()
{
        int i;
        char com;
        // pthread_t         iothr;
        pthread_t         netthr;

        /*
         * Initialize
         */
        log_mutex = (pthread_mutex_t *)malloc(sizeof(pthread_mutex_t) * NUM_RING_BUF);

        for(i=0; i<NUM_RING_BUF; i++){
                pthread_mutex_init(&log_mutex[i], NULL);
        }
  

        if(pthread_create(&netthr, NULL, net_thread, &net_args)){
                // fprintf(stderr,"File I/O thread create: %d\n", __LINE__);
                exit(EXIT_FAILURE);
        }
  
        while(1){
                printf("COMMAND(q): ");
                scanf("%c", &com);
                if (com == 'q'){
                        // flush_buffer();
                        fflush(NULL);
                        exit(0);
                }else{
                        fflush(NULL);
                }
        }
        /* NEVER REACHD */
        pthread_join(netthr, NULL);
}
