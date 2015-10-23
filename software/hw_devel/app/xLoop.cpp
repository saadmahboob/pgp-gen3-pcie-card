
#include <sys/types.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <string>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>

#include "../include_old/PgpCardG3Mod.h"
#include "../include_old/PgpCardG3Wrap.h"

#define DEVNAME "/dev/PgpCardG3_0"

using namespace std;

int main (int argc, char **argv) {
   int  s;
   uint i;
   bool value;
   uint port;
   uint loop;
   
   // Check for set/clear
   if ( argc == 2 ) {
      if( strcmp(argv[1],"set") == 0 ) {
         value = true;
      } else if( strcmp(argv[1],"clear") == 0 ) { 
         value = false;
      } else {
         cout << "Usage: xloop port 1/0" << endl;
         return(0);      
      }
      if ( (s = open(DEVNAME, O_RDWR)) <= 0 ) {
         cout << "Error opening file" << endl;
         return(1);
      }      
      for(i=0;i<8;i++){
         port = i;
         if(value) {
            pgpcard_setLoop(s,i);
         } else {
            pgpcard_clrLoop(s,i);
         }
      }
      close(s);   
   } else if ( argc != 3 ) {
      cout << "Usage: xloop port 1/0" << endl;
      return(0);
   } else {
      port = atoi(argv[1]);
      loop = atoi(argv[2]);

      if ( (s = open(DEVNAME, O_RDWR)) <= 0 ) {
         cout << "Error opening file" << endl;
         return(1);
      }

      if ( loop == 0 ) pgpcard_clrLoop(s,port);
      else pgpcard_setLoop(s,port);

      close(s);   
   }
}