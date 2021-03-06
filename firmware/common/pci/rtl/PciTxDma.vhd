-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTxDma.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-03
-- Last update: 2016-08-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'SLAC PGP Gen3 Card'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC PGP Gen3 Card', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;

entity PciTxDma is
   generic (
      TPD_G : time := 1 ns); 
   port (
      -- 128-bit Streaming RX Interface
      pciClk         : in  sl;
      pciRst         : in  sl;
      dmaIbMaster    : out AxiStreamMasterType;
      dmaIbSlave     : in  AxiStreamSlaveType;
      dmaObMaster    : in  AxiStreamMasterType;
      dmaObSlave     : out AxiStreamSlaveType;
      dmaDescFromPci : in  DescFromPciType;
      dmaDescToPci   : out DescToPciType;
      dmaTranFromPci : in  TranFromPciType;
      -- 32-bit Streaming TX Interface
      mAxisClk       : in  sl;
      mAxisRst       : in  sl;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType);     
end PciTxDma;

architecture rtl of PciTxDma is

   type StateType is (
      IDLE_S,
      COLLECT_S);    

   type RegType is record
      sof       : sl;
      contEn    : sl;
      done      : sl;
      remLength : slv(23 downto 0);
      idx       : natural range 0 to 3;
      rxSlave   : AxiStreamSlaveType;
      txMaster  : AxiStreamMasterType;
      state     : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      sof       => '1',
      contEn    => '0',
      done      => '0',
      remLength => (others => '0'),
      idx       => 0,
      rxSlave   => AXI_STREAM_SLAVE_INIT_C,
      txMaster  => AXI_STREAM_MASTER_INIT_C,
      state     => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal start  : sl;
   signal dmaSof : sl;

   signal newControl : slv(7 downto 0);
   signal newLength  : slv(23 downto 0);

   signal axisMaster : AxiStreamMasterType;
   signal rxMaster   : AxiStreamMasterType;
   signal rxSlave    : AxiStreamSlaveType;
   signal txCtrl     : AxiStreamCtrlType;
   signal dmaCtrl    : AxiStreamCtrlType;

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "true";
   -- attribute dont_touch of start      : signal is "true";
   -- attribute dont_touch of dmaSof     : signal is "true";
   -- attribute dont_touch of newControl : signal is "true";
   -- attribute dont_touch of newLength  : signal is "true";
   
begin

   PciTxDmaMemReq_Inst : entity work.PciTxDmaMemReq
      generic map (
         TPD_G => TPD_G)
      port map (
         -- DMA Interface
         dmaIbMaster    => dmaIbMaster,
         dmaIbSlave     => dmaIbSlave,
         dmaDescFromPci => dmaDescFromPci,
         dmaDescToPci   => dmaDescToPci,
         dmaTranFromPci => dmaTranFromPci,
         -- Transaction Interface
         start          => start,
         done           => r.done,
         pause          => dmaCtrl.pause,
         remLength      => r.remLength,
         newControl     => newControl,
         newLength      => newLength,
         -- Clock and reset     
         pciClk         => pciClk,
         pciRst         => pciRst);   

   FIFO_RX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 2,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 256,
         CASCADE_PAUSE_SEL_G => 0,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PCI_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => PCI_AXIS_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => pciClk,
         sAxisRst    => pciRst,
         sAxisMaster => dmaObMaster,
         sAxisSlave  => dmaObSlave,
         sAxisCtrl   => dmaCtrl,
         -- Master Port
         mAxisClk    => pciClk,
         mAxisRst    => pciRst,
         mAxisMaster => axisMaster,
         mAxisSlave  => rxSlave);                   

   -- Reverse the data order
   rxMaster <= reverseOrderPcie(axisMaster);

   dmaSof <= '1' when(r.remLength = newLength) else '0';

   comb : process (dmaSof, newControl, newLength, pciRst, r, rxMaster, start, txCtrl) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.done           := '0';
      v.rxSlave.tReady := '0';

      -- Update tValid register
      v.txMaster.tValid := '0';
      v.txMaster.tLast  := '0';
      v.txMaster.tUser  := (others => '0');

      -- Only 32-bit transfers
      v.txMaster.tKeep := x"000F";

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Wait for start signal
            if start = '1' then
               -- Latch the length of the transaction
               v.remLength                  := newLength;
               -- Set the continuous mode flag
               v.contEn                     := newControl(2);
               -- Set the destination
               v.txMaster.tDest(7 downto 2) := (others => '0');
               v.txMaster.tDest(1 downto 0) := newControl(1 downto 0);
               -- Next state
               v.state                      := COLLECT_S;
            else
               -- Dump any data in the FIFO (first memory request TLP not sent yet)
               v.rxSlave.tReady := '1';
            end if;
         ----------------------------------------------------------------------
         when COLLECT_S =>
            -- Check if ready to move data 
            if (txCtrl.pause = '0') and (rxMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster.tValid := '1';
               -- Decrement the counter
               v.remLength       := r.remLength - 1;
               -- Check for TLP SOF
               if ssiGetUserSof(PCI_AXIS_CONFIG_C, rxMaster) = '1' then
                  -- Accept the data
                  v.rxSlave.tReady := '1';
                  -- Check local & DMA SOF variable
                  if (r.sof = '1') and (dmaSof = '1') then
                     -- Reset the flag
                     v.sof := '0';
                     -- Set the SOF bit
                     ssiSetUserSof(AXIS_32B_CONFIG_C, v.txMaster, '1');
                  end if;
                  -- Blow off the 3-DW header and grab the 4th DW
                  v.txMaster.tData(31 downto 0) := rxMaster.tData(127 downto 96);
                  -- Reset index pointer
                  v.idx                         := 0;
               else
                  -- Move the data
                  v.txMaster.tData(31 downto 0) := rxMaster.tData((32*r.idx)+31 downto (32*r.idx));
                  -- Check the index pointer
                  case r.idx is
                     when 0 =>
                        if rxMaster.tKeep(7 downto 4) = x"F" then
                           -- Preset index pointer
                           v.idx := 1;
                        end if;
                     when 1 =>
                        if rxMaster.tKeep(11 downto 8) = x"F" then
                           -- Preset index pointer
                           v.idx := 2;
                        else
                           -- Reset index pointer
                           v.idx := 0;
                        end if;
                     when 2 =>
                        if rxMaster.tKeep(15 downto 12) = x"F" then
                           -- Preset index pointer
                           v.idx := 3;
                        else
                           -- Reset index pointer
                           v.idx := 0;
                        end if;
                     when others =>
                        -- Reset index pointer
                        v.idx := 0;
                  end case;
                  -- Check the state of the pointer
                  if v.idx = 0 then
                     -- Accept the data
                     v.rxSlave.tReady := '1';
                  end if;
               end if;
               -- Check if this is the last DMA word to transfer
               if r.remLength = 1 then
                  -- Handshake with Memory Requester  
                  v.done := '1';
                  -- Check for not continuous mode
                  if r.contEn = '0' then
                     -- Reset the flag
                     v.sof            := '1';
                     -- Set the EOF bit
                     v.txMaster.tLast := '1';
                  end if;
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      rxSlave <= v.rxSlave;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   FIFO_TX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 256,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_32B_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_32B_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => pciClk,
         sAxisRst    => pciRst,
         sAxisMaster => r.txMaster,
         sAxisCtrl   => txCtrl,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);            

end rtl;
