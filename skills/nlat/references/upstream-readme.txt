Compiling and running

The code package contains 26 subroutines written in Fortran 90. After downloadin
g
the source code NLAT.tar.gz, one should unzip the tar ^Lle:

gunzip NLAT.tar.gz
tar -xvf NLAT.tar

This will create the directory NLAT, which is organized as follows:

  LOCAL_SAMPLE contains the input and expected output for a LOCAL run
  NONLOCAL_SAMPLE contains the input and expected output for a NONLOCAL run.
  SOURCE/ contains all the source code files
  makefile ifort make file for the ifort compiler
  makefile gfortran make file for the gfortran compiler
  make input.f90 code to make an input file

copy the necessary makefile into the SOURCE directory, renaming it to make-file.
 
Move to the SOURCE directory, and type:

       make install clean

This will make the executable NLAT, which will be placed in the directory ~/bin,
as well as the SOURCE directory. For the input file generator, compile using
the ifort compiler by typing

      ifort -o make-input make_input.f90

or with gfortran compiler

      gfortran -o make-input make_input.f90

to generate the executable for the input file maker.

In order to run the code, one first runs make-input and is guided through
a set of questions to create the input file that is stored in inputfile.in. Subs
equently,
one runs the code:

NLAT < inputfile.in > output

to produce the desired outputs.

To test the installation one can use the sample input provided in the LOCAL_SAMPLE and NONLOCAL_SAMPLE directories. The output will be directed to the directory name specified at the end of the input file.

