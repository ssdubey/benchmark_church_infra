#include <assert.h>

#include <stdio.h>

#include <stdlib.h>

#include <string.h>

#include <time.h>

#include <cassandra.h>

void print_error(CassFuture * future) {
  const char * message;
  size_t message_length;
  cass_future_error_message(future, & message, & message_length);
  fprintf(stderr, "Error: %.*s\n", (int) message_length, message);
}

CassCluster * create_cluster(const char * hosts) {
  CassCluster * cluster = cass_cluster_new();
  cass_cluster_set_contact_points(cluster, hosts);
  return cluster;
}

CassError connect_session(CassSession * session,
  const CassCluster * cluster) {
  CassError rc = CASS_OK;
  CassFuture * future = cass_session_connect(session, cluster);

  cass_future_wait(future);
  rc = cass_future_error_code(future);
  if (rc != CASS_OK) {
    print_error(future);
  }
  cass_future_free(future);

  return rc;
}

CassError execute_query(CassSession * session,
  const char * query) {
  CassError rc = CASS_OK;
  CassFuture * future = NULL;
  CassStatement * statement = cass_statement_new(query, 0);

  future = cass_session_execute(session, statement);
  cass_future_wait(future);

  rc = cass_future_error_code(future);
  if (rc != CASS_OK) {
    print_error(future);
  }

  cass_future_free(future);
  cass_statement_free(statement);

  return rc;
}

CassError prepare_query(CassSession * session,
  const char * query,
    const CassPrepared ** prepared) {
  CassError rc = CASS_OK;
  CassFuture * future = NULL;

  future = cass_session_prepare(session, query);
  cass_future_wait(future);

  rc = cass_future_error_code(future);
  if (rc != CASS_OK) {
    print_error(future);
  } else {
    * prepared = cass_future_get_prepared(future);
  }

  cass_future_free(future);

  return rc;
}

/**
 * generate and insert key value pair into db. return the array of keys inserted to be written in file for reading later.
 */
CassError insert_into_tuple(CassSession * session, int no_of_inputs, int keylength, int valuelength) {
    CassError rc = CASS_OK;
    CassStatement * statement = NULL;
    CassFuture * future = NULL;
    
    const char * query = "INSERT INTO irmin_scylla.atomic_write (key, value) VALUES (?, ?)";

    statement = cass_statement_new(query, 2);

    ////////////////////////////////////////////

    srand(getpid());
    
    char * string = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    char key[keylength + 1];    
    char value[valuelength + 1];

    for(int loop_count=0; loop_count < no_of_inputs; loop_count++){

      //generating a key 

        int i = 0;
        for(i = 0; i < keylength; i++){
            int index = rand() % 62; 
            key[i] = string[index];
        }
        key[i] = '\0';

        // temp_key_store[loop_count] = malloc((keylength + 1) * sizeof(char));
        // strcpy(temp_key_store[loop_count], key);
        
       //generating a value
      
        int j = 0;

        for(j = 0; j < valuelength; j++){
          int index = rand() % 62; 
          value[j] = string[index];
        }
        value[j] = '\0';
        
        //inserting a key-value pair to db

        cass_statement_bind_string(statement, 0, key);
        cass_statement_bind_string(statement, 1, value);

        future = cass_session_execute(session, statement);
        cass_future_wait(future);

        rc = cass_future_error_code(future);
        if (rc != CASS_OK) {
          print_error(future);
          }
        
        cass_future_free(future);

      }

}
/**
 * Read the value for given keys from db
 */
CassError readkey(CassSession* session, char** read_store, int no_of_inputs_to_read) {
  CassError rc = CASS_OK;
  CassStatement* statement = NULL;
  CassFuture* future = NULL;
  CassTuple* item = NULL;

// for(int loop_count=0; loop_count < no_of_inputs_to_read; loop_count++){
//     printf("in readkey = '%.*s'\n", 8, read_store[loop_count]);
//   }

  const char* query = "SELECT * FROM irmin_scylla.atomic_write where key = ?";

  statement = cass_statement_new(query, 1);

for(int t=0; t< no_of_inputs_to_read; t++){
  //printf("\nt=%d  key='%s'",t, read_store[t]);
	cass_statement_bind_string(statement, 0, read_store[t]);

  future = cass_session_execute(session, statement);
  cass_future_wait(future);

  rc = cass_future_error_code(future);
  if (rc != CASS_OK) {
    print_error(future);
  } else {
    const CassResult* result = NULL;
    CassIterator* rows = NULL;

    result = cass_future_get_result(future);
    rows = cass_iterator_from_result(result);

    while (cass_iterator_next(rows)) { 
      const CassRow* row = cass_iterator_get_row(rows);

      const CassValue* item_value = cass_row_get_column_by_name(row, "value");

      const char* text;
      size_t text_length;
      cass_value_get_string(item_value, &text, &text_length);
    //  printf("\"%.*s\" ", (int)text_length, text);
    //  printf("\n");
    }

    cass_result_free(result);
    cass_iterator_free(rows);
  }

  cass_future_free(future);
}
  cass_statement_free(statement);

  return rc;
}

int main(int argc, char * argv[]) { //args: hosts, no_of_inputs to write, no. of inputs to read
  CassCluster * cluster = NULL;
  CassSession * session = cass_session_new();
  
  char* hosts = argv[1];
  int no_of_inputs_to_write = atoi(argv[2]);
  int no_of_inputs_to_read = atoi(argv[3]);

  printf("host= %s, #input_write= %d, #input_read = %d", hosts, no_of_inputs_to_write, no_of_inputs_to_read);

  int keylength = 8;
  int valuelength = 128;

  cluster = create_cluster(hosts);

  if (connect_session(session, cluster) != CASS_OK) {
    cass_cluster_free(cluster);
    cass_session_free(session);
    return -1;
  }
  
  //reading keys from file into a dynamic array

  FILE * fp;
  char * line = NULL;
  size_t len = 0;
  int read;

  char **read_store = (char**)malloc(no_of_inputs_to_read * sizeof(char*));

  fp = fopen("keylist", "r");
  if (fp == NULL)
      exit(EXIT_FAILURE);

  for(int loop_count=0; loop_count < no_of_inputs_to_read; loop_count++){
      read_store[loop_count] = malloc(keylength * sizeof(char));
      
      if(getline(&line, &len, fp)){
        //printf("\nline= '%s'", line);
        char temp[9];
        strncpy(temp, line, 8);
        //printf("\ntemp= '%s'", temp);
        strcpy(read_store[loop_count], temp);
      }
      else{
          printf("error while reading file for readstore");
      }
      
  }
  fclose(fp);

  // for(int loop_count=0; loop_count < no_of_inputs_to_read; loop_count++){
  //   printf("\n%s", read_store[loop_count]);
  // }
  
  //performing mix operations

  struct timeval start,end;
  gettimeofday(&start, NULL);

  insert_into_tuple(session, no_of_inputs_to_write, keylength, valuelength);
  readkey(session, read_store, no_of_inputs_to_read);
  

  gettimeofday(&end, NULL);


  free(read_store);

  long seconds = (end.tv_sec - start.tv_sec);
  long micros = ((seconds * 1000000) + end.tv_usec) - (start.tv_usec);
  printf("time = %d   %d\n", seconds, micros);
  
  cass_cluster_free(cluster);
  cass_session_free(session);

  return 0;
    }