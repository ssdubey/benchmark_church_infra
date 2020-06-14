#include <stdio.h>
#include <sys/time.h>

int main(int argc, char* argv[]){
printf("argc = %d", argc);
printf("\nargv[0] = %s \nargv[1] = %s \nargv[2] = %s \nargv[3] = %s", argv[0], argv[1], argv[2], argv[3]);

/*struct timeval start,end;
gettimeofday(&start, NULL);
usleep(1000000);
gettimeofday(&end, NULL);

long seconds = (end.tv_sec - start.tv_sec);
long micros = ((seconds * 1000000) + end.tv_usec) - (start.tv_usec);
printf("time = %d   %d\n", seconds, micros);
*/
}
