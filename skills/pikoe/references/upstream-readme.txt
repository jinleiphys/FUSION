This package contains the source file of "pikoe", its inputs and outputs
for some cases. The structure of the directories is as follows.

------------------------------------------------------------------------------------------
./readme.txt                       this file
./pikoe1.f90                       source code of "pikoe"
./input_man.txt                    input manual for "pikoe"

./pot                              potentials obtained with Dirac phenomenology (EDAD1)
     /EDAD1p12C_e.dat              p-12C potential at 392 MeV
     /EDAD1p11B_e.dat              p-11B potential for several energies
     /EDAD1p12C@100_e.dat          p-12C potential at 100 MeV

./elem                             Franey-Love's parametrization for elementary process
      /nnampFL.dat                 NN transition amplitudes
      /FLtbl_rede.dat              NN elastic cross sections

./sample1
         /12Cp2pTDXnorm.cnt        input file for 12C(p,2p)11Bg.s. at 392 MeV;
                                   TDX calculation in normal kinematics
         /tbl_12Cp2pTDXnorm.dat    output of the TDX
         /12Cp2pTDXnorm.outlist    calculation record

./sample2
         /12Cp2pMD.cnt             input file for 12C(p,2p)11Bg.s. at 392 MeV;
                                   MD calculation
         /tbl_12Cp2pMD.dat         output of the MD of Eq. (25)
         /LG_12Cp2pMD.dat                    the LG MD of Eq. (33)
         /PX_12Cp2pMD.dat                    the PX MD of Eq. (35)
         /TR_12Cp2pMD.dat                    the TR MD of Eq. (34)
         /TL_12Cp2pMD.dat                    the TL MD of Eq. (36)
         /12Cp2pMD.outlist         calculation record

./sample3
         /12Cp2pMD100.cnt          input file for 12C(p,2p)11Bg.s. at 100 MeV;
                                   MD calculation
         /tbl_12Cp2pMD100.dat      output of the MD of Eq. (25)
         /LG_12Cp2pMD100.dat                 the LG MD of Eq. (33)
         /PX_12Cp2pMD100.dat                 the PX MD of Eq. (35)
         /TR_12Cp2pMD100.dat                 the TR MD of Eq. (34)
         /TL_12Cp2pMD100.dat                 the TL MD of Eq. (36)
         /12Cp2pMD100.outlist      calculation record

./sample4
         /12Cp2pTDXinv.cnt         input file for 12C(p,2p)11Bg.s. at 392 MeV;
                                   TDX calculation in inverse kinematics
         /tbl_12Cp2pTDXinv.dat     output of the TDX
         /12Cp2pTDXinv.outlist     calculation record

./sample5
         /12Cp2pQDXinv.cnt         input file for 12C(p,2p)11Bg.s. at 392 MeV;
                                   QDX calculation in inverse kinematics
         /tbl_12Cp2pQDXinv.dat     output of the QDX
         /12Cp2pQDXinv.outlist     calculation record
------------------------------------------------------------------------------------------
In the compilation of pikoe.f90, it is recommended that stacksize is set
unlimited.

The executable file is assumed to be put on each of the sample directories.
After setting the current directory to sampleX (X=1--5), run "pikoe" with
redirecting the cnt file in that directory.
