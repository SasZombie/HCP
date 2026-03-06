# Installation

Use venv

pip install -r requirements.txt


## What is it
Local Structural Order Parameter (LSOP) analysis. 
Instead of just counting how many neighbors an atom has, the program calculates the geometric quality of the neighborhood. The code takes the positions of all atoms in a Armstrong difined radius box and calculates:
1. Bond Angles: The precise angle between every neighbor-center-neighbor trio.
2. Symmetry Matching: How closely those angles match ideal mathematical shapes (like a perfect tetrahedron or octahedron).
3. Numerical Scores: A vector of values (0.0 to 1.0) representing the "shape profile" of every single atom.
## Why calculate it  
1. Mapping Disorder and Defects
2. Identifying Phase Transitions(melting point)

# Implementation
To achive the desired outcome we must implement the following steps:
* Data Aquisition from the Material Project API. 
* Scaling up the cell. The default unit cell is to small for any meaningfull statistical analysis.  
* Neighborhood watch. Using a Voronoi tessellation to intelligently decide which atoms are actually "bonded" or coordinated.
* Geometric Fingerprinting. This recognizes the shape of the cell.
* The Bond Valence Analysis.  

The most [naive approach](naive_main.py "Implementation") is to do everything in python. This is managable for a simple structure(Silicon) and with a low number of neighbors to around 3 minutes. But scales awfully since the supercell scales cubic and the trees squares.  
 