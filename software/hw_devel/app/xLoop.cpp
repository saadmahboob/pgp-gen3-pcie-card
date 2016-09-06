//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC PGP Gen3 Card'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC PGP Gen3 Card', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

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

#include "../include/PgpCardG3Mod.h"
#include "../include/PgpCardG3Wrap.h"

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
