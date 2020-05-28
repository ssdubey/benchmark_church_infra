#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/*int main (int argc, char* argv[])
{
	int seed = atoi(argv[2]);
	srand(getpid());
	for(int i=0;i<10;i++){
		printf("%d", rand()%10);
	}
}
*/
int main (){
//int entrycount = entrcnt;
int entrycount = 2;
                  int keysize = 10;
                    int valuesize = 128;
//srand(time(0));
//printf("seed= %d", seed);
                srand(getpid());
                    char keys[entrycount][11];
                char values[entrycount][129];

                char *string = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
                char tempchar[keysize+1];

                int n = 0;
                int i =0;

                for (n=0;n<entrycount;n++){
                        for (i =0; i<10;i++)
                        {
                                int key = rand() % 62; //printf("\nkey seed = %d", key);
                                tempchar[i]=string[key];
                        }
                tempchar[i]='\0';
                strcpy(keys[n], tempchar);
                printf("\nkey %d = %s", n, keys[n]);
                }

                char tempcharval[valuesize+1];
                for (n=0;n<entrycount;n++){
                        for (i =0; i<128;i++){
                                int key = rand() % 62;
                                tempcharval[i]=string[key];
                        }
                        tempcharval[i]='\0';
                        strcpy(values[n], tempcharval);
                        printf("\nvalue %d = %s", n, values[n]);
                }

printf("\n\n");
                for (n=0;n<entrycount;n++){

                              printf("\n\nn= %d key = %s value = %s", n, keys[n], values[n]);
}
}
