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

#define PRINT_DATA false

using namespace std;

int main (int argc, char **argv) {
   int           s;
   int           ret;
   uint          maxSize;
   uint          *data;
   uint          lane;
   uint          vc;
   uint          eofe;
   uint          fifoErr;
   uint          lengthErr;

   if ( (s = open(DEVNAME, O_RDWR)) <= 0 ) {
      cout << "Error opening file" << endl;
      return(1);
   }   

   // Allocate a buffer
   maxSize = 1024*1024*2;
   data = (uint *)malloc(sizeof(uint)*maxSize);

   // DMA Read
   do {
      ret = pgpcard_recv(s,data,maxSize,&lane,&vc,&eofe,&fifoErr,&lengthErr);

      if ( ret != 0 ) {

         cout << "Ret=" << dec << ret;
         cout << ", Lane=" << dec << lane;
         cout << ", Vc=" << dec << vc;
         cout << ", Eofe=" << dec << eofe;
         cout << ", FifoErr=" << dec << fifoErr;
         cout << ", LengthErr=" << dec << lengthErr;
         cout << endl << "   ";
#if PRINT_DATA
         int x;
         for (x=0; x<ret; x++) {
            cout << " 0x" << setw(8) << setfill('0') << hex << data[x];
            if ( ((x+1)%10) == 0 ) cout << endl << "   ";
         }
#endif
         cout << endl;
      }
   } while ( ret > 0 );
   
   free(data);

   close(s);
}
