/*
 * FS test (fio-thread.c)
 * File writer threads
 *
 * (C) Copyright 2010-2012 TOSHIBA CORPORATION
 * 
 * This source code is licensed under the GNU General Public License,
 * Version 2.  See the file COPYING for more details.
 */
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sched.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "config.h"
#include "common.h"

static void path_create(char *path, char *str, int id, int n)
{
        int dname = n / 100;
        int fname = n;
        sprintf(str, "%s/%04d/%04d/%04d.txt", path, id, dname, fname);
}

/*
 * Logging
 */
int connect_logserver(struct f_thr_args *fa)
{
        struct sockaddr_in *serv_addr;
        char *serv_ip = fa->serv_ip;

        serv_addr = (struct sockaddr_in *)malloc(sizeof(struct sockaddr_in));
        memset(serv_addr, 0, sizeof(struct sockaddr_in));
        fprintf(stderr, "IP ADDR:%s\n", serv_ip);
        if (inet_aton(serv_ip, &serv_addr->sin_addr) == 0){
                fprintf(stderr, "Server IP ADDR??\n");
                exit(EXIT_FAILURE);
        };
        serv_addr->sin_port   = htons(fa->port);
        serv_addr->sin_family = AF_INET;
        fa->serv_addr         = serv_addr;
        
        return (socket(AF_INET, SOCK_DGRAM, 0));
}

void send_log(int soc, char *str, int len, struct sockaddr_in *serv_addr)
{
        sendto(soc, str, len, 0, serv_addr, sizeof(struct sockaddr_in));
}

/*
 * File I/O 
 */
void file_create(struct f_thr_args *fa, char *buf, int b_size, int n)
{
        int    i, j;
        int    fd;
        int    id = fa->id;
        int    type = fa->type;
        size_t w_size;
        char   fname[1024];
        char   str[1024];

        path_create(fa->path, fname, id, n);
        fd = open(fname, 
                  O_CREAT|O_RDWR|O_SYNC|O_TRUNC, S_IRWXU | S_IRWXG | S_IRWXO);
        if (fd < 0){
                fprintf(stderr, "[id:%02d]: fd(%d)\n", fa->id, fd);
                perror(fname);
                exit(EXIT_FAILURE);
        }

        j = 0;
        for(i = 0; i < fa->fsize; ){
                j++;
                w_size = write(fd, buf, b_size);
                if (w_size < 0){
                        fprintf(stderr, "[id:%02d]: wsize(%d)\n",
                                fa->id, w_size);
                        perror(fname);
                        exit(EXIT_FAILURE);
                }
                /* 
                 * Send log data (depends on option)
                 */
                if (fa->serv_addr != NULL && fa->type == 0){
                        sprintf(str, "%d\t%d\t%d\t%d\t%d\n", type, id, n, j, b_size);
                        send_log(fa->socket, str, strlen(str), fa->serv_addr);
                }
                i = i + (int)w_size;
        }
  
        close(fd);
}

void file_overwrite(struct f_thr_args *fa, char *buf, int b_size, int n)
{
        int    i, j;
        int    flag = 0;
        int    fd;
        int    id = fa->id;
        int    type = fa->type;
        size_t w_size;
        char   fname[1024];
        char   str[1024];

        path_create(fa->path, fname, id, n);
        fd = open(fname, O_RDWR|O_SYNC, S_IRWXU | S_IRWXG | S_IRWXO);
        if (fd < 0){
                fprintf(stderr, "[id:%02d]: fd(%d)\n", fa->id, fd);
                perror(fname);
                exit(EXIT_FAILURE);
        }
        
        j = 1;
        for(i = 0; i < fa->fsize; ){
                if (flag == 1){
                        w_size = write(fd, buf, b_size);
                        if (w_size < 0){
                                fprintf(stderr, 
                                        "[id:%02d]: wsize(%d)\n",
                                        fa->id, w_size);
                                perror(fname);
                                exit(EXIT_FAILURE);
                        }
                        /* 
                         * Send log data (depends on option)
                         */
                        if (fa->serv_addr != NULL){
                                sprintf(str, "%d\t%d\t%d\t%d\t%d\n", 
                                        type, id, n, j, b_size);
                                send_log(fa->socket, str, strlen(str), 
                                         fa->serv_addr);
                        }
                        j++;
                        flag = 0;
                }else{
                        w_size = lseek(fd, b_size, SEEK_CUR);
                        if (w_size < 0){
                                fprintf(stderr, 
                                        "[id:%02d]: LSEEK(%d)\n",
                                        fa->id, w_size);
                                perror(fname);
                                exit(EXIT_FAILURE);
                        }
                        w_size = b_size;
                        flag = 1;
                }
                i = i + (int)w_size;
        }
  
        close(fd);
}

void file_append(struct f_thr_args *fa, char *buf, int b_size, int n)
{
        int    i,j;
        int    fd;
        int    id = fa->id;
        int    type = fa->type;
        size_t w_size;
        char   fname[1024];
        char   str[1024];

        path_create(fa->path, fname, id, n);
        fd = open(fname, O_RDWR|O_SYNC|O_APPEND, S_IRWXU | S_IRWXG | S_IRWXO);
        if (fd < 0){
                fprintf(stderr, "[id:%02d]: fd(%d)\n", fa->id, fd);
                perror(fname);
                exit(EXIT_FAILURE);
        }

        j=1;
        for(i = 0; i < fa->fsize; ){
                w_size = write(fd, buf, b_size);
                if (w_size < 0){
                        fprintf(stderr,
                                "[id:%02d]: wsize(%d)\n", fa->id, w_size);
                        perror(fname);
                        exit(EXIT_FAILURE);
                }
                /* 
                 * Send log data (depends on option)
                 */
                if (fa->serv_addr != NULL){
                        sprintf(str, "%d\t%d\t%d\t%d\t%d\n", type, id, n, j, b_size);
                        send_log(fa->socket, str, strlen(str), fa->serv_addr);
                }
                i = i + (int)w_size;
                j++;
        }
  
        close(fd);
}

void file_append_close(struct f_thr_args *fa, char *buf, int b_size, int n)
{
        int    i,j;
        int    fd;
        int    id = fa->id;
        int    type = fa->type;
        size_t w_size;
        char   fname[1024];
        char   str[1024];

        path_create(fa->path, fname, id, n);
        j=1;
        for(i = 0; i < fa->fsize; ){
                fd = open(fname, O_RDWR|O_SYNC|O_CREAT|O_APPEND, S_IRWXU | S_IRWXG | S_IRWXO);
                if (fd < 0){
                        fprintf(stderr, "[id:%02d]: fd(%d)\n", fa->id, fd);
                        perror(fname);
                        exit(EXIT_FAILURE);
                }

                w_size = write(fd, buf, b_size);
                if (w_size < 0){
                        fprintf(stderr,
                                "[id:%02d]: wsize(%d)\n", fa->id, w_size);
                        perror(fname);
                        exit(EXIT_FAILURE);
                }

                close(fd);
                /* 
                 * Send log data (depends on option)
                 */
                if (fa->serv_addr != NULL){
                        sprintf(str, "%d\t%d\t%d\t%d\t%d\n", type, id, n, j, b_size);
                        send_log(fa->socket, str, strlen(str), fa->serv_addr);
                }
                i = i + (int)w_size;
                j++;
        }
  
}

void prepare_dirs(char *path, int id, int fnum)
{
        int  i;
        int  mkstat;
        int  dname;
        char str[1024];

        sprintf(str, "%s/%04d", path, id);
        mkstat = mkdir(str, S_IRWXU | S_IRWXG | S_IRWXO);
        if (mkstat < 0){
                perror(str);
                exit(EXIT_FAILURE);
        }
  
        /*
         * 100 files will be stored in each directory
         */
        for(i=0; i<fnum; i=i+100){
                dname = i / 100;
                sprintf(str, "%s/%04d/%04d", path, id, dname);
                mkstat = mkdir(str, S_IRWXU | S_IRWXG | S_IRWXO);
                if (mkstat < 0){
                        perror(str);
                        exit(EXIT_FAILURE);
                }
        }
}

void fill_buf(char *buf, int size, char a)
{
        int i, r;

        for(i=0; i<size; i++){
                r = i % 128;
                if(r != 127){
                        buf[i] = a;
                }else{
                        buf[i] = '\n';
                }
        }
        // Just in case
        buf[i] = '\0';
}

/*
 * File I/O threads
 */
void fio_main(struct f_thr_args *fa)
{
        int   i;
        int   buf_size;
        char *buf;
        int   gran;
        char  str[256];

        gran = 1 << fa->gran;
        if(gran > fa->fsize){
                gran = fa->fsize;
        }

        /*
         * Main
         */
        ft_state[fa->id - 1] = STATE_RUNNING;

        /*
         * 9999 means "start test" and send it to log host
         */
        if (fa->serv_ip != NULL){
                fa->socket = connect_logserver(fa);
                sprintf(str, "9999\t%d\t%d\t%d\t0\n", fa->type, fa->count, fa->id);
                send_log(fa->socket, str, strlen(str), fa->serv_addr);
        }

        buf = (char *)malloc(fa->fsize + 1);
        if (fa->type == TEST_TYPE_OVERWRITE || fa->type == TEST_TYPE_APPEND){
                fill_buf(buf, fa->fsize, s_char);
        }else{
                fill_buf(buf, fa->fsize / gran, s_char);
        }
        buf_size = strlen(buf);
  
        prepare_dirs(fa->path, fa->id, fa->fnum);
        
        bar_wait(fa->id);
  
        /*
         * All test cases need to create test files (flaments)
         */
        if (fa->type != TEST_TYPE_APPENDCLOSE){
                fprintf(stderr, "C[%d]", fa->id);
                for(i=0; i<fa->fnum; i++){
                        file_create(fa, buf, buf_size, i);
                }
        }else{
                fprintf(stderr, "OAC[%d]", fa->id);
                progress = 1;
                for(i=0; i<fa->fnum; i++){
                        file_append_close(fa, buf, buf_size, i);
                }
        }

        bar_wait(fa->id);
        progress = 1;
  
        if (fa->type == TEST_TYPE_APPEND){
                fill_buf(buf, fa->fsize / gran, s_char + 1);
                buf_size = strlen(buf);
                fprintf(stderr, "A[%d]", fa->id);
                bar_wait(fa->id);
                for(i=0; i<fa->fnum; i++){
                        file_append(fa, buf, buf_size, i);
                }
                bar_wait(fa->id);
        }
        
        /* overwrite */
        if (fa->type == TEST_TYPE_OVERWRITE){
                // fill_buf(buf, fa->fsize / (gran * 2), s_char + 2);
                fill_buf(buf, fa->fsize / gran, s_char + 2);
                buf_size = strlen(buf);
                //fprintf(stderr, "File OVERWRITE: [%d]\n", fa->id);
                fprintf(stderr, "O[%d]", fa->id);
                bar_wait(fa->id);
                for(i=0; i<fa->fnum; i++){
                        file_overwrite(fa, buf, buf_size, i);
                }
                bar_wait(fa->id);
        }
  
        /*
         * Finish
         */
        progress = 2;
        ft_state[fa->id - 1] = STATE_FINISHED;
}

/*----------------------------------------------------------------------
 * Entry point for each thread
 *----------------------------------------------------------------------*/
void *fio_thread(void *fio_args)
{
        struct f_thr_args *fa = (struct f_thr_args *)fio_args;

        /*
         * Call main
         */
        fio_main(fa);

        /*
         * Finish
         */
        return NULL;
}
