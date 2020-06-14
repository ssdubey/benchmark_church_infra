#include<stdio.h>
#include<stdlib.h>
#include <string.h>

int main(){
    int no_of_inputs = 12;
    int keylength = 5;

    char key[keylength + 1];
    char **temp_key_store;
    
    char * string = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    FILE *fptr;

    fptr = fopen("keylist","w");
    temp_key_store = malloc(no_of_inputs * sizeof(char*));

    for(int loop_count=0; loop_count<no_of_inputs; loop_count++){

        int i = 0;
        for(i = 0; i < keylength; i++){
            int index = rand() % 62; 
            key[i] = string[index];
        }
        key[i] = '\0';

        temp_key_store[loop_count] = malloc((keylength + 1) * sizeof(char));
        strcpy(temp_key_store[loop_count], key);
        
    }

    if(fptr == NULL)
    {
        printf("Error!");   
        exit(1);             
    }
    for(int loop_count=0; loop_count<no_of_inputs; loop_count++){
        fprintf(fptr,"%s\n",temp_key_store[loop_count]);
    }
   
   fclose(fptr);


    free(temp_key_store);

///////////////////////////////////////////////////////////////////////

    FILE * fp;
    char * line = NULL;
    size_t len = 0;
    int read;

    char **read_store = (char**)malloc(no_of_inputs * sizeof(char*));

    fp = fopen("keylist", "r");
    if (fp == NULL)
        exit(EXIT_FAILURE);

    for(int loop_count=0; loop_count<no_of_inputs; loop_count++){
        read_store[loop_count] = malloc((keylength + 1) * sizeof(char));
        if(getline(&line, &len, fp)){
            strcpy(read_store[loop_count], line);
        }
        else{
            printf("error while reading file for readstore");
        }
        
    }

    // int w=0;
    // int index=0;
    
    // while (w<13) {
    //     printf("w=%d",w);
    //     printf("from array = %s\n", read_store[w]);  
    //     w++; index=index+5;
    // }
    //strcpy(temp_key_store[0], "line");
    fclose(fp);

}