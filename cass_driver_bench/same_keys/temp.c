#include <stdio.h>
int main (){

int keysize=10;
    char keys[keysize][11];
    int i = 0;
    FILE * fp;

    if (fp = fopen("output.csv", "r")) {
        while (fscanf(fp, "%s", &keys[i]) != EOF) {
            printf("\ninserted key= %s", keys[i]);
                ++i;

        }
        fclose(fp);
    }
}
