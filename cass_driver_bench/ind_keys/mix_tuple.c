#include <assert.h>

#include <stdio.h>

#include <stdlib.h>

#include <string.h>

#include <time.h>

#include <cassandra.h>

int keysize;

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

CassError insert_into_tuple(CassSession * session, int entrcnt) {
    CassError rc = CASS_OK;
    CassStatement * statement = NULL;
    CassFuture * future = NULL;
    printf("inside insert into tuple");
    const char * query = "INSERT INTO irmin_scylla.atomic_write (key, value) VALUES (?, ?)";

    statement = cass_statement_new(query, 2);

    ////////////////////////////////////////////

    int entrycount = entrcnt;
    //int keysize = 10;
    int valuesize = 128;
    //srand(time(0));
    //printf("seed= %d", seed);
    srand(getpid());
    char keys[entrycount][11];
    char values[entrycount][129];

    char * string = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    char tempchar[keysize + 1];

    int n = 0;
    int i = 0;

    for (n = 0; n < entrycount; n++) {
      for (i = 0; i < 10; i++) {
        int key = rand() % 62; //printf("\nkey seed = %d", key);
        tempchar[i] = string[key];
      }
      tempchar[i] = '\0';
      strcpy(keys[n], tempchar);
      //printf("\nkey %d = %s", n, keys[n]);
    }

    char tempcharval[valuesize + 1];
    for (n = 0; n < entrycount; n++) {
      for (i = 0; i < 128; i++) {
        int key = rand() % 62;
        tempcharval[i] = string[key];
      }
      tempcharval[i] = '\0';
      strcpy(values[n], tempcharval);
      //printf("\nvalue %d = %s", n, values[n]);
    }

    /*printf("\n\n");
    for (n = 0; n < entrycount; n++) {

      printf("\n\nn= %d key = %s value = %s", n, keys[n], values[n]);
    }*/

    printf("done1");
    ////////////////////////////////////////

    clock_t t;
    t = clock();
    printf("\n\n\n");
    for (int i = 0; i < entrycount; i++) {
      //printf("\nkey %d = %s\nvalue %d = %s", i, keys[i], i, values[i]);
      cass_statement_bind_string(statement, 1, values[i]);
      cass_statement_bind_string(statement, 0, keys[i]);

      future = cass_session_execute(session, statement);
      cass_future_wait(future);

      rc = cass_future_error_code(future);
      if (rc != CASS_OK) {
        print_error(future);
        }
      }
      t = clock() - t;
      double time_taken = ((double) t) / CLOCKS_PER_SEC; // in seconds

     // printf("fun() took %f seconds to execute \n", time_taken); //this is cpu execution time

      cass_future_free(future);

      cass_statement_free(statement);

      return rc;
    }

/*    void readdb (CassSession * session){
	CassError rc = CASS_OK;
    	CassStatement * statement = NULL;
        CassFuture * future = NULL;
	printf("inside insert into tuple");
	const char * query = "select * from irmin_scylla.atomic_write";

	statement = cass_statement_new(query, 0);

	future = cass_session_execute(session, statement);
      	cass_future_wait(future);

      	rc = cass_future_error_code(future);
      	if (rc != CASS_OK) {
        	print_error(future);
        }else {
	    const CassResult* result = NULL;
    		CassIterator* rows = NULL;

	    result = cass_future_get_result(future);
    	    rows = cass_iterator_from_result(result);
	
	while (cass_iterator_next(rows)) {
		const CassRow* row = cass_iterator_get_row(rows);
      		const CassValue* item_value = cass_row_get_column_by_name(row, "key");      
		CassIterator* item = cass_iterator_from_tuple(item_value);
		
		while (cass_iterator_next(item)) {
		        const CassValue* value = cass_iterator_get_value(item);
			if (!cass_value_is_null(value)) {
	                if (cass_value_type(value) == CASS_VALUE_TYPE_VARCHAR) {
            		const char* text;
            		size_t text_length;
            		cass_value_get_string(value, &text, &text_length);
            		printf("\"%.*s\" ", (int)text_length, text);
}//if varchar
}//if  value null
}//while iter next item
}//while iter next rows
	cass_result_free(result);
    	cass_iterator_free(rows);
}//else
q	cass_future_free(future);
  	cass_statement_free(statement);
    }//function
*/

CassError readkey(CassSession* session, char keys[10][11]) {
  CassError rc = CASS_OK;
  CassStatement* statement = NULL;
  CassFuture* future = NULL;
  CassTuple* item = NULL;

  const char* query = "SELECT * FROM irmin_scylla.atomic_write where key = ?";

  statement = cass_statement_new(query, 1);
//int keysize=10;
//  printf("keysize in read=%d",keysize);

for(int t=0; t< keysize; t++){
  //printf("\nlooking for key = %s", keys[t]);
	cass_statement_bind_string(statement, 0, keys[t]);

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
     // printf("\"%.*s\" ", (int)text_length, text);
     // printf("\n");
    }

    cass_result_free(result);
    cass_iterator_free(rows);
  }

  cass_future_free(future);
}
  cass_statement_free(statement);

  return rc;
}

CassError readdb(CassSession* session) {
  CassError rc = CASS_OK;
  CassStatement* statement = NULL;
  CassFuture* future = NULL;
  CassTuple* item = NULL;

  const char* query = "SELECT key FROM irmin_scylla.atomic_write";

  statement = cass_statement_new(query, 0);

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

      const CassValue* item_value = cass_row_get_column_by_name(row, "key");

      const char* text;
      size_t text_length;
      cass_value_get_string(item_value, &text, &text_length);
      printf("\"%.*s\" ", (int)text_length, text);

      printf("\n");
    }

    cass_result_free(result);
    cass_iterator_free(rows);
  }

  cass_future_free(future);
  cass_statement_free(statement);

  return rc;
}

    int main(int argc, char * argv[]) {
      CassCluster * cluster = NULL;
      CassSession * session = cass_session_new();
       char* hosts = argv[3];
       cluster = create_cluster(hosts);

      if (connect_session(session, cluster) != CASS_OK) {
        cass_cluster_free(cluster);
        cass_session_free(session);
        return -1;
      }
      int entrycount = atoi(argv[1]);
      printf("\npost entrycount = %d", entrycount);
    
      keysize=atoi(argv[2]);  
      printf("\npre keysize = %d", keysize);

      char keys[keysize][11];

      int i = 0;
    FILE * fp;

    if (fp = fopen("output.csv", "r")) {
        while ((fscanf(fp, "%s", &keys[i]) != EOF)&&(i<keysize)) {
     //       printf("\nscanning key= %d %s", i, keys[i]);
		++i;

        }
        fclose(fp);
    }
    
    /*printf("keysize = %d, now printing keys", keysize);
    for(int i =0; i<keysize; i++){
	    printf("\n");
	    printf("\ninserted key= %s", keys[i]);
    }*/

struct timeval start,end;
gettimeofday(&start, NULL);

	insert_into_tuple(session, entrycount);
//      readdb(session);
	readkey(session, keys);
gettimeofday(&end, NULL);

long seconds = (end.tv_sec - start.tv_sec);
long micros = ((seconds * 1000000) + end.tv_usec) - (start.tv_usec);
printf("\nstart sec = %ld \n end sec = %ld \n start usec = %ld \n end usec = %ld\n", start.tv_sec, end.tv_sec, start.tv_usec, end.tv_usec);
printf("time = %ld   %ld\n", seconds, micros);
      cass_cluster_free(cluster);
      cass_session_free(session);

      return 0;
    }
