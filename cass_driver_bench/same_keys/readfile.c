#include <stdio.h>
#include <sys/time.h>
int main(void)
{
    char keys[4000][11];
    int i = 0;
    FILE * fp;
//time_t start;
//time_t end;
//   start = time(NULL);
//   printf("Hours since January 1, 1970 = %ld\n", seconds/3600);
 


struct timeval start,end;
gettimeofday(&start, NULL);

    if (fp = fopen("output.csv", "r")) {
        while (fscanf(fp, "%s", &keys[i]) != EOF) {
            ++i;
        }
        fclose(fp);
    }
 
    for (--i; i >= 0; --i)
        printf("num[%d] = %s\n", i, keys[i]);

//sleep(5); 
//end= time(NULL);
gettimeofday(&end, NULL);

long seconds = (end.tv_sec - start.tv_sec);
long micros = ((seconds * 1000000) + end.tv_usec) - (start.tv_usec);

printf("time = %d   %d\n", seconds, micros);
    return 0;
}
